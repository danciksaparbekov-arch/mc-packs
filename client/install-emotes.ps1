# install-emotes.ps1 - ставит эмоции (zip) в сборку Prominence II. Запускается через install-emotes.bat.
param([string]$ZipPath, [string]$InstanceDir, [switch]$NoPause)
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
  if (-not $ZipPath) {
    Write-Host "Перетащи сюда zip-файл с эмоциями (мышкой в это окно) и нажми Enter:"
    $ZipPath = (Read-Host).Trim().Trim('"')
  }
  if (-not (Test-Path $ZipPath)) { Fail "Файл не найден: $ZipPath" }
  $out = Join-Path $InstanceDir "emotes"
  New-Item -ItemType Directory -Force $out | Out-Null
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $z = [IO.Compression.ZipFile]::OpenRead($ZipPath)
  $n = 0
  foreach ($e in $z.Entries) {
    if ($e.FullName -like "__MACOSX*" -or [string]::IsNullOrEmpty($e.Name) -or $e.Name -like "._*") { continue }
    [IO.Compression.ZipFileExtensions]::ExtractToFile($e, (Join-Path $out $e.Name), $true); $n++
  }
  $z.Dispose()
  Write-Host ""
  Write-Host "ГОТОВО! Установлено файлов: $n. Перезапусти игру; меню эмоций открывается клавишей B." -ForegroundColor Green
  Finish 0
} catch { Fail $_.Exception.Message }
