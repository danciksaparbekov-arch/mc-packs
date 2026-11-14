# setup-extras.ps1 - установка автообновления модов для сборки Prominence II (AstralRinth / Modrinth App).
# Запускается через install.bat (двойной клик). Параметры нужны только для тестов:
#   -InstanceDir "<папка сборки>"  - не искать сборку автоматически
#   -NoPause                       - не ждать Enter в конце
param(
  [string]$InstanceDir,
  [switch]$NoPause,
  [string]$SearchDir,
  [string]$PackUrl = "https://raw.githubusercontent.com/danciksaparbekov-arch/mc-packs/main/packs/prominence2-extras/pack.toml"
)
$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$BootstrapUrl = "https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/v0.0.3/packwiz-installer-bootstrap.jar"

function Finish($code) { if (-not $NoPause) { Write-Host ""; Read-Host "Нажми Enter, чтобы закрыть окно" | Out-Null }; exit $code }
function Fail($msg) { Write-Host ""; Write-Host "ОШИБКА: $msg" -ForegroundColor Red; Finish 1 }

try {
  Write-Host "=== Сладкий Баклажанчик: настройка модов ===" -ForegroundColor Cyan

  # 1. Находим сборку Prominence II
  if (-not $InstanceDir) {
    $roots = @("$env:APPDATA\AstralRinthApp\profiles", "$env:APPDATA\ModrinthApp\profiles") | Where-Object { Test-Path $_ }
    if (-not $roots) { Fail "Не нашёл лаунчер (AstralRinth или Modrinth App). Установи лаунчер и сборку Prominence II v4.1.8, потом запусти снова." }
    $all = @($roots | ForEach-Object { Get-ChildItem $_ -Directory })
    $found = @($all | Where-Object { Get-ChildItem (Join-Path $_.FullName "mods") -Filter "Prominent-GLOBAL*" -ErrorAction SilentlyContinue })
    if ($found.Count -eq 1) { $InstanceDir = $found[0].FullName }
    else {
      if ($found.Count -eq 0) { Write-Host "Не нашёл сборку Prominence II автоматически. Выбери её из списка:" -ForegroundColor Yellow; $list = $all }
      else { Write-Host "Нашлось несколько сборок Prominence II. Выбери нужную:" -ForegroundColor Yellow; $list = $found }
      for ($i = 0; $i -lt $list.Count; $i++) { Write-Host ("  [{0}] {1}" -f $i, $list[$i].Name) }
      $n = Read-Host "Номер сборки"
      if ($n -notmatch '^\d+$' -or [int]$n -ge $list.Count) { Fail "Неверный номер." }
      $InstanceDir = $list[[int]$n].FullName
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
`$j = Get-ChildItem "`$env:APPDATA\AstralRinthApp\meta\java_versions\*17*\bin\java.exe","`$env:APPDATA\ModrinthApp\meta\java_versions\*17*\bin\java.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
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
