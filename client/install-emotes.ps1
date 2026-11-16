# install-emotes.ps1 - ставит эмоции (zip) в сборку Prominence II. Запускается через install-emotes.bat.
param([string[]]$ZipPath, [string]$InstanceDir, [switch]$NoPause)
$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
function Finish($code) { if (-not $NoPause) { Write-Host ""; Read-Host "Нажми Enter, чтобы закрыть окно" | Out-Null }; exit $code }
function Fail($msg) { Write-Host ""; Write-Host "ОШИБКА: $msg" -ForegroundColor Red; Finish 1 }
try {
  Write-Host "=== Установка эмоций ===" -ForegroundColor Cyan
  if (-not $InstanceDir) {
    $roots = @("$env:APPDATA\AstralRinthApp\profiles", "$env:APPDATA\ModrinthApp\profiles") | Where-Object { Test-Path $_ }
    if (-not $roots) { Fail "Не нашёл лаунчер (AstralRinth или Modrinth App)." }
    $all = @($roots | ForEach-Object { Get-ChildItem $_ -Directory })
    $found = @($all | Where-Object { Get-ChildItem (Join-Path $_.FullName "mods") -Filter "Prominent-GLOBAL*" -ErrorAction SilentlyContinue })
    if ($found.Count -eq 1) { $InstanceDir = $found[0].FullName }
    else {
      $list = if ($found.Count -gt 1) { $found } else { $all }
      for ($i = 0; $i -lt $list.Count; $i++) { Write-Host ("  [{0}] {1}" -f $i, $list[$i].Name) }
      $n = Read-Host "Номер сборки Prominence II"
      if ($n -notmatch '^\d+$' -or [int]$n -ge $list.Count) { Fail "Неверный номер." }
      $InstanceDir = $list[[int]$n].FullName
    }
  }
  # Эмоции приходят несколькими zip (в Discord лимит файла 8 МБ): каждая часть - обычный zip, ставим все.
  # Источник: параметр, файлы/папка, перетащенные в окно, а при пустом вводе - папка Загрузки.
  $zips = @()
  if ($ZipPath) { $zips = @($ZipPath) }
  else {
    Write-Host "Перетащи сюда ВСЕ zip-файлы с эмоциями (выдели их разом и перетащи мышкой в это окно) и нажми Enter."
    Write-Host "Если все части лежат в папке Загрузки - просто нажми Enter."
    $line = (Read-Host).Trim()
    foreach ($m in [regex]::Matches($line, '"([^"]+)"|(\S+)')) {
      $zips += $(if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value })
    }
  }
  if ($zips.Count -eq 0) { $zips = @(Join-Path ([Environment]::GetFolderPath("UserProfile")) "Downloads") }
  $files = @()
  foreach ($p in $zips) {
    if (Test-Path -LiteralPath $p -PathType Container) {
      $files += @(Get-ChildItem -LiteralPath $p -Filter "*emote*.zip" -File | ForEach-Object { $_.FullName })
    } elseif (Test-Path -LiteralPath $p) { $files += $p }
    else { Fail "Файл не найден: $p" }
  }
  if ($files.Count -eq 0) { Fail "Не нашёл zip с эмоциями (в имени должно быть слово emote)." }
  Write-Host "Найдено частей: $($files.Count)"
  $out = Join-Path $InstanceDir "emotes"
  New-Item -ItemType Directory -Force $out | Out-Null
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $n = 0
  foreach ($file in $files) {
    $z = [IO.Compression.ZipFile]::OpenRead($file)
    foreach ($e in $z.Entries) {
      if ($e.FullName -like "__MACOSX*" -or [string]::IsNullOrEmpty($e.Name) -or $e.Name -like "._*") { continue }
      [IO.Compression.ZipFileExtensions]::ExtractToFile($e, (Join-Path $out $e.Name), $true); $n++
    }
    $z.Dispose()
  }
  Write-Host ""
  Write-Host "ГОТОВО! Установлено файлов: $n (из частей: $($files.Count)). Перезапусти игру; меню эмоций открывается клавишей B." -ForegroundColor Green
  Finish 0
} catch { Fail $_.Exception.Message }
