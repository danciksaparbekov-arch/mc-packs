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
  # Откуда берём эмоции (по порядку): параметр -ZipPath; файлы emotes-SPE*.zip в папке Загрузки (если Данис прислал
  # их в Discord частями из-за лимита 8 МБ); иначе скачиваем целиком из релиза emotes-v1 на GitHub и сверяем сумму.
  # Если и скачать не вышло - просим перетащить zip-файлы в окно.
  $EmotesUrl = "https://github.com/danciksaparbekov-arch/mc-packs/releases/download/emotes-v1/emotes-SPE.zip"
  $EmotesSha256 = "9921340f56c70079efbd5972d7cdb757e4a6ecdd8446b99513074152927c862c"
  $zips = @()
  if ($ZipPath) { $zips = @($ZipPath) }
  else {
    $downloads = Join-Path ([Environment]::GetFolderPath("UserProfile")) "Downloads"
    $local = @(Get-ChildItem -LiteralPath $downloads -Filter "emotes-SPE*.zip" -File -ErrorAction SilentlyContinue)
    if ($local.Count -gt 0) { $zips = @($local | ForEach-Object { $_.FullName }) }
    else {
      Write-Host "Скачиваю эмоции (около 55 МБ)..."
      $tmpZip = Join-Path $env:TEMP "emotes-SPE.zip"
      try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $old = $ProgressPreference; $ProgressPreference = "SilentlyContinue"
        try { Invoke-WebRequest -Uri $EmotesUrl -OutFile $tmpZip -UseBasicParsing } finally { $ProgressPreference = $old }
        if ((Get-FileHash -LiteralPath $tmpZip -Algorithm SHA256).Hash -ine $EmotesSha256) { throw "контрольная сумма не совпала" }
        $zips = @($tmpZip)
      } catch {
        Write-Host "Не удалось скачать эмоции ($($_.Exception.Message))." -ForegroundColor Yellow
        Write-Host "Перетащи сюда ВСЕ zip-файлы с эмоциями (выдели их разом и перетащи мышкой в это окно) и нажми Enter:"
        $line = (Read-Host).Trim()
        foreach ($m in [regex]::Matches($line, '"([^"]+)"|(\S+)')) {
          $zips += $(if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value })
        }
      }
    }
  }
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
