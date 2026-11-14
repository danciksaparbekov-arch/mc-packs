# setup-extras.ps1 - установка автообновления модов для сборки Prominence II (AstralRinth / Modrinth App).
# Запускается через install.bat (двойной клик). Параметры нужны только для тестов:
#   -InstanceDir "<папка сборки>"  - не искать сборку автоматически
#   -NoPause                       - не ждать Enter в конце
param(
  [string]$InstanceDir,
  [switch]$NoPause,
  [switch]$FindOnly,
  [string]$SearchDir,
  [string]$PackUrl = "https://raw.githubusercontent.com/danciksaparbekov-arch/mc-packs/main/packs/prominence2-extras/pack.toml"
)
$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$BootstrapUrl = "https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/v0.0.3/packwiz-installer-bootstrap.jar"

function Finish($code) { if (-not $NoPause) { Write-Host ""; Read-Host "Нажми Enter, чтобы закрыть окно" | Out-Null }; exit $code }
function Fail($msg) { Write-Host ""; Write-Host "ОШИБКА: $msg" -ForegroundColor Red; Finish 1 }

# Официальная сборка Prominence II v4.1.8 (Modrinth CDN). Не храним у себя - качаем у автора, хэш проверяем.
$ModpackUrl = "https://cdn.modrinth.com/data/EGs3lC8D/versions/WTpCW96X/Prominence%E2%84%A2%20II%20Hasturian%20Era%20v4.1.8.mrpack"
$ModpackSha512 = "24ea0bec296e3e3eb7bb3e99d75664da46c55a8a27680d23c2ee6a628f30051a32a90cc7b7391e59f69cba08e0cd5ba761042d09a6389656dc730f39bb9ec898"
function Get-PackFile {
  $dl = $null
  try { $dl = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path } catch { }
  if (-not $dl) { $dl = Join-Path $env:USERPROFILE "Downloads" }
  $f = Join-Path $dl "Prominence-II-v4.1.8.mrpack"
  $good = (Test-Path $f) -and ((Get-FileHash $f -Algorithm SHA512).Hash.ToLower() -eq $ModpackSha512)
  if (-not $good) {
    Write-Host "Скачиваю сборку Prominence II v4.1.8 (около 450 МБ) в папку Загрузки. Подожди..." -ForegroundColor Yellow
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) { & curl.exe -L --fail --progress-bar -o $f $ModpackUrl }
    else { $ProgressPreference = "SilentlyContinue"; Invoke-WebRequest -Uri $ModpackUrl -OutFile $f -UseBasicParsing }
    if (-not (Test-Path $f) -or ((Get-FileHash $f -Algorithm SHA512).Hash.ToLower() -ne $ModpackSha512)) {
      Remove-Item $f -ErrorAction SilentlyContinue
      Fail "Сборка скачалась с ошибкой. Проверь интернет и запусти INSTALL.bat ещё раз."
    }
  }
  Write-Host "Сборка лежит в папке Загрузки: $f" -ForegroundColor Green
  try { Start-Process explorer.exe "/select,`"$f`"" } catch { }
}
function Show-ImportSteps {
  Write-Host ""
  Write-Host "ЧТО ДАЛЬШЕ:" -ForegroundColor Cyan
  Write-Host "  1. Открой лаунчер (AstralRinth или Modrinth App) -> создать/добавить сборку -> 'Из файла' (Import / From file)."
  Write-Host "     Выбери файл Prominence-II-v4.1.8.mrpack из Загрузок (папка уже открыта)."
  Write-Host "  2. Дождись установки модов, запусти игру ОДИН раз до главного меню и закрой её."
  Write-Host "  3. Закрой лаунчер и снова дважды кликни INSTALL.bat."
}

# Ищем сборку Prominence II везде: стандартные папки лаунчеров + другие диски (лаунчер можно перенести на любой том).
function Find-PackInstances {
  $cands = New-Object System.Collections.Generic.List[string]
  foreach ($r in @("$env:APPDATA\AstralRinthApp\profiles", "$env:APPDATA\ModrinthApp\profiles", "$env:LOCALAPPDATA\AstralRinthApp\profiles", "$env:LOCALAPPDATA\ModrinthApp\profiles")) { if (Test-Path $r) { $cands.Add($r) } }
  foreach ($d in [System.IO.DriveInfo]::GetDrives()) {
    if ($d.DriveType -ne "Fixed" -or -not $d.IsReady) { continue }
    $top = Get-ChildItem $d.RootDirectory.FullName -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "rinth|astral|minecraft|games|launcher|mc|игр" }
    foreach ($t in $top) {
      Get-ChildItem $t.FullName -Directory -Recurse -Depth 3 -Filter "profiles" -ErrorAction SilentlyContinue | ForEach-Object { $cands.Add($_.FullName) }
    }
  }
  $found = @()
  foreach ($c in ($cands | Select-Object -Unique)) {
    foreach ($p in (Get-ChildItem $c -Directory -ErrorAction SilentlyContinue)) {
      if (Get-ChildItem (Join-Path $p.FullName "mods") -Filter "Prominent-GLOBAL*" -ErrorAction SilentlyContinue) { $found += $p }
    }
  }
  return $found
}
# Если не нашли сами - просим указать папку сборки в окне выбора.
function Select-InstanceFolder {
  Write-Host "Открою окно - выбери в нём папку сборки Prominence II." -ForegroundColor Yellow
  Write-Host "  (Узнать путь: лаунчер -> сборка -> вкладка Files -> 'Открыть папку'; нужна папка, в которой лежит папка mods.)"
  try {
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Выбери папку сборки Prominence II (внутри должна быть папка mods)"
    if ($dlg.ShowDialog() -eq "OK") { return $dlg.SelectedPath }
  } catch { }
  return (Read-Host "Или вставь путь к папке сборки сюда").Trim().Trim('"')
}

try {
  Write-Host "=== Сладкий Баклажанчик: настройка модов ===" -ForegroundColor Cyan

  # 1. Находим сборку Prominence II (где бы она ни лежала)
  if (-not $InstanceDir) {
    Write-Host "Ищу сборку Prominence II на этом компьютере..."
    $found = @(Find-PackInstances)
    if ($FindOnly) { Write-Host "FOUND: $($found.Count)"; $found | ForEach-Object { Write-Host $_.FullName }; Finish 0 }
    if ($found.Count -eq 1) { $InstanceDir = $found[0].FullName }
    elseif ($found.Count -gt 1) {
      Write-Host "Нашлось несколько сборок Prominence II. Выбери нужную:" -ForegroundColor Yellow
      for ($i = 0; $i -lt $found.Count; $i++) { Write-Host ("  [{0}] {1}" -f $i, $found[$i].FullName) }
      $n = Read-Host "Номер сборки"
      if ($n -notmatch '^\d+$' -or [int]$n -ge $found.Count) { Fail "Неверный номер." }
      $InstanceDir = $found[[int]$n].FullName
    }
    else {
      $ans = Read-Host "Сборка Prominence II уже добавлена в лаунчер? (д/н)"
      if ($ans -match '^(д|y|да|yes)') {
        $InstanceDir = Select-InstanceFolder
        if (-not $InstanceDir -or -not (Test-Path (Join-Path $InstanceDir "mods"))) { Fail "В выбранной папке нет папки mods. Выбери папку самой сборки." }
      } else {
        Write-Host "Сначала нужно добавить сборку в лаунчер - скачаю её файл." -ForegroundColor Yellow
        Get-PackFile; Show-ImportSteps; Finish 0
      }
    }
  }
  if (-not (Test-Path $InstanceDir)) { Fail "Папка сборки не найдена: $InstanceDir" }
  Write-Host "Сборка: $InstanceDir"

  # 2. Установщик модов
  Write-Host "Скачиваю установщик..."
  Invoke-WebRequest -Uri $BootstrapUrl -OutFile (Join-Path $InstanceDir "packwiz-installer-bootstrap.jar") -UseBasicParsing

  # 3. Figura: облако по умолчанию - Sculptor (принимает аккаунты Ely.by). Добавляется, только если ничего не выбрано.
  $figuraPatch = @'
try {
  $cfg = Join-Path $inst "config\figura.json"
  New-Item -ItemType Directory -Force (Split-Path $cfg) | Out-Null
  $o = $null
  if (Test-Path $cfg) { $o = Get-Content $cfg -Raw | ConvertFrom-Json }
  if ($null -eq $o) { $o = [pscustomobject]@{ CONFIG_VERSION = 1 } }
  if (-not $o.PSObject.Properties["server_ip"]) {
    $o | Add-Member -NotePropertyName server_ip -NotePropertyValue "figura.shsr.ru"
    [System.IO.File]::WriteAllText($cfg, ($o | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))
  }
} catch { }
'@

  # 4. Скрипт синхронизации внутри сборки (всегда завершается кодом 0 - не мешает запуску игры)
  $sync = @"
Set-Location `$PSScriptRoot
`$roots = @((Split-Path (Split-Path `$PSScriptRoot)), "`$env:APPDATA\AstralRinthApp", "`$env:APPDATA\ModrinthApp", "`$env:LOCALAPPDATA\AstralRinthApp", "`$env:LOCALAPPDATA\ModrinthApp")
`$j = `$null
foreach (`$r in `$roots) {
  `$c = @(Get-ChildItem "`$r\meta\java_versions\*\bin\java.exe" -ErrorAction SilentlyContinue)
  if (`$c.Count) { `$j = (@(`$c | Where-Object { `$_.FullName -match '17|21' }) + `$c)[0].FullName; break }
}
if (-not `$j) { `$j = (Get-Command java -ErrorAction SilentlyContinue).Source }
if (`$j) { & `$j -jar packwiz-installer-bootstrap.jar -g -s client "$PackUrl" } else { Write-Host "Java 17 not found" }
`$inst = `$PSScriptRoot
$figuraPatch
exit 0
"@
  $syncPath = Join-Path $InstanceDir "packwiz-sync.ps1"
  Set-Content -Path $syncPath -Value $sync -Encoding ASCII

  # 5. Первая синхронизация сейчас
  Write-Host "Скачиваю моды (это может занять пару минут)..."
  & powershell -NoProfile -ExecutionPolicy Bypass -File $syncPath

  $ok = @(Get-ChildItem (Join-Path $InstanceDir "mods") -Filter "emotecraft*" -ErrorAction SilentlyContinue).Count -gt 0
  if (-not $ok) {
    Write-Host ""
    Write-Host "Моды не скачались. Если ты ещё ни разу не запускал игру - запусти её один раз до главного меню, закрой и запусти установку снова." -ForegroundColor Yellow
    Finish 1
  }

  # 5b. Эмоции: если рядом с install.bat лежит zip с эмоциями - ставим их
  if ($SearchDir -and (Test-Path $SearchDir)) {
    $ez = @(Get-ChildItem $SearchDir -Filter "*.zip" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*emote*" })
    if ($ez.Count -ge 1) {
      Write-Host "Ставлю эмоции из $($ez[0].Name)..."
      $eout = Join-Path $InstanceDir "emotes"
      New-Item -ItemType Directory -Force $eout | Out-Null
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      $zf = [IO.Compression.ZipFile]::OpenRead($ez[0].FullName); $en = 0
      foreach ($e in $zf.Entries) {
        if ($e.FullName -like "__MACOSX*" -or [string]::IsNullOrEmpty($e.Name) -or $e.Name -like "._*") { continue }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($e, (Join-Path $eout $e.Name), $true); $en++
      }
      $zf.Dispose()
      Write-Host "Эмоции установлены: $en файлов (в игре меню эмоций - клавиша B)."
    }
  }

  # 6. Команда для лаунчера
  $hookPath = $syncPath -replace '\\', '/'   # прямые слэши: лаунчеры могут считать обратные экранированием
  $hook = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$hookPath`""
  $copied = $false
  try { Set-Clipboard -Value $hook; $copied = $true } catch { }

  Write-Host ""
  Write-Host "ГОТОВО! Моды установлены. Остался ОДИН шаг в лаунчере (делается один раз):" -ForegroundColor Green
  Write-Host "  1. Открой лаунчер и нажми на сборку Prominence II."
  Write-Host "  2. Нажми значок шестерёнки (Settings) -> раздел Launch hooks."
  Write-Host "  3. В поле Pre-launch вставь команду (Ctrl+V)."
  if ($copied) { Write-Host "     Команда уже скопирована в буфер обмена." } else { Write-Host "     Скопируй эту команду:"; Write-Host "     $hook" }
  Write-Host "  4. Закрой окно настроек. Всё - дальше моды обновляются сами при каждом запуске."
  Finish 0
} catch { Fail $_.Exception.Message }
