# setup-extras.ps1 - one-time setup of auto-updating extra mods for a launcher instance.
# Works with AstralRinth App and Modrinth App. Run:
#   powershell -ExecutionPolicy Bypass -File setup-extras.ps1
# Optional: -InstanceDir "<path to instance folder>" to skip the instance picker.
param(
  [string]$InstanceDir,
  [string]$PackUrl = "https://raw.githubusercontent.com/danciksaparbekov-arch/mc-packs/main/packs/prominence2-extras/pack.toml"
)
$ErrorActionPreference = "Stop"
$BootstrapUrl = "https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/v0.0.3/packwiz-installer-bootstrap.jar"

# 1. Pick the instance folder
if (-not $InstanceDir) {
  $roots = @("$env:APPDATA\AstralRinthApp\profiles", "$env:APPDATA\ModrinthApp\profiles") | Where-Object { Test-Path $_ }
  if (-not $roots) { throw "Launcher profiles folder not found (AstralRinthApp / ModrinthApp)." }
  $list = @($roots | ForEach-Object { Get-ChildItem $_ -Directory })
  for ($i = 0; $i -lt $list.Count; $i++) { Write-Host ("[{0}] {1}  ({2})" -f $i, $list[$i].Name, $list[$i].Parent.Parent.Name) }
  $n = [int](Read-Host "Number of the Prominence II instance")
  $InstanceDir = $list[$n].FullName
}
if (-not (Test-Path $InstanceDir)) { throw "Instance folder not found: $InstanceDir" }
Write-Host "Instance: $InstanceDir"

# 2. Bootstrap jar
$jar = Join-Path $InstanceDir "packwiz-installer-bootstrap.jar"
Invoke-WebRequest -Uri $BootstrapUrl -OutFile $jar -UseBasicParsing

# 3. Sync script placed inside the instance (always exits 0 so it never blocks game launch)
$sync = @"
Set-Location `$PSScriptRoot
`$j = Get-ChildItem "`$env:APPDATA\AstralRinthApp\meta\java_versions\*17*\bin\java.exe","`$env:APPDATA\ModrinthApp\meta\java_versions\*17*\bin\java.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not `$j) { `$j = (Get-Command java -ErrorAction SilentlyContinue).Source }
if (`$j) { & `$j -jar packwiz-installer-bootstrap.jar -g -s client "$PackUrl" } else { Write-Host "Java 17 not found" }
exit 0
"@
$syncPath = Join-Path $InstanceDir "packwiz-sync.ps1"
Set-Content -Path $syncPath -Value $sync -Encoding ASCII

# 4. First run now
& powershell -NoProfile -ExecutionPolicy Bypass -File $syncPath

# 5. Hook command for the launcher
$hook = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$syncPath`""
try { Set-Clipboard -Value $hook; $c = " (copied to clipboard)" } catch { $c = "" }
Write-Host ""
Write-Host "DONE. Now in the launcher: Instance settings -> Launch hooks -> Pre-launch, paste$c :"
Write-Host $hook
