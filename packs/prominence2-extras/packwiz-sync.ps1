Set-Location $PSScriptRoot
$roots = @((Split-Path (Split-Path $PSScriptRoot)), "$env:APPDATA\AstralRinthApp", "$env:APPDATA\ModrinthApp", "$env:LOCALAPPDATA\AstralRinthApp", "$env:LOCALAPPDATA\ModrinthApp")
$j = $null
foreach ($r in $roots) {
  $c = @(Get-ChildItem "$r\meta\java_versions\*\bin\java.exe" -ErrorAction SilentlyContinue)
  if ($c.Count) { $j = (@($c | Where-Object { $_.FullName -match '17|21' }) + $c)[0].FullName; break }
}
if (-not $j) { $j = (Get-Command java -ErrorAction SilentlyContinue).Source }
if ($j) { & $j -jar packwiz-installer-bootstrap.jar -g -s client "https://raw.githubusercontent.com/danciksaparbekov-arch/mc-packs/main/packs/prominence2-extras/pack.toml" } else { Write-Host "Java 17 not found" }
$inst = $PSScriptRoot
try {
  $cfg = Join-Path $inst "config\figura.json"
  New-Item -ItemType Directory -Force (Split-Path $cfg) | Out-Null
  $o = $null
  if (Test-Path $cfg) { $o = Get-Content $cfg -Raw | ConvertFrom-Json }
  if ($null -eq $o) { $o = [pscustomobject]@{ CONFIG_VERSION = 1 } }
  # Актуальный адрес нашего Figura-бэкенда (меняется при перезапуске туннеля на pc2); если не ответил - остаётся прежний/общий
  $host2 = $null
  # Сначала бот (workers.dev), затем запасной адрес на ретрансляторе AWS - workers.dev заблокирован у части друзей в РФ
  foreach ($u in @("https://mc-server-bot.danislam2003.workers.dev/figura", "http://51.20.22.205:8080/figura")) {
    try { $host2 = (Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 6).Content.Trim() } catch { $host2 = $null }
    if ($host2 -match '^[a-z0-9.-]+$') { break } else { $host2 = $null }
  }
  if (-not $o.PSObject.Properties["server_ip"]) {
    $o | Add-Member -NotePropertyName server_ip -NotePropertyValue $(if ($host2) { $host2 } else { "figura.shsr.ru" })
    [System.IO.File]::WriteAllText($cfg, ($o | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))
  } elseif ($host2 -and $o.server_ip -ne $host2) {
    $o.server_ip = $host2
    [System.IO.File]::WriteAllText($cfg, ($o | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))
  }
} catch { }
try {
  # Добавляем сервер в список мультиплеера (servers.dat) один раз. Файл не трогаем, если структура незнакома.
  $marker = Join-Path $inst ".sb-server-added"
  if (-not (Test-Path $marker)) {
    $ip = "sladkiybaklazhanchik.exaroton.me:45698"
    $nm = "Сладкий Баклажанчик"
    $enc = New-Object System.Text.UTF8Encoding $false
    $be16 = { param($n) [byte[]]@([byte](($n -shr 8) -band 255), [byte]($n -band 255)) }
    $str = { param($k, $v) $kb = $enc.GetBytes($k); $vb = $enc.GetBytes($v); [byte[]](@(8) + (& $be16 $kb.Length) + $kb + (& $be16 $vb.Length) + $vb) }
    $entry = [byte[]]((& $str "ip" $ip) + (& $str "name" $nm) + @(0))
    $i32 = { param($b, $p) ([int]$b[$p] -shl 24) + ([int]$b[$p + 1] -shl 16) + ([int]$b[$p + 2] -shl 8) + [int]$b[$p + 3] }
    $skip = $null
    $skip = {
      param($b, $p, $t)
      switch ($t) {
        1 { $p + 1 } 2 { $p + 2 } 3 { $p + 4 } 4 { $p + 8 } 5 { $p + 4 } 6 { $p + 8 }
        7 { $p + 4 + (& $i32 $b $p) }
        8 { $p + 2 + (([int]$b[$p] -shl 8) + [int]$b[$p + 1]) }
        9 { $et = $b[$p]; $n = & $i32 $b ($p + 1); $q = $p + 5; for ($k = 0; $k -lt $n; $k++) { $q = & $skip $b $q $et }; $q }
        10 { $q = $p; while ($b[$q] -ne 0) { $tt = $b[$q]; $nl = ([int]$b[$q + 1] -shl 8) + [int]$b[$q + 2]; $q = & $skip $b ($q + 3 + $nl) $tt }; $q + 1 }
        11 { $p + 4 + 4 * (& $i32 $b $p) }
        12 { $p + 4 + 8 * (& $i32 $b $p) }
      }
    }
    $sd = Join-Path $inst "servers.dat"
    $hdr = [byte[]](@(10, 0, 0, 9, 0, 7) + $enc.GetBytes("servers") + @(10))
    if (-not (Test-Path $sd)) {
      [IO.File]::WriteAllBytes($sd, [byte[]]($hdr + @(0, 0, 0, 1) + $entry + @(0)))
      Set-Content -Path $marker -Value "created"
    } else {
      $b = [IO.File]::ReadAllBytes($sd)
      if ([Text.Encoding]::GetEncoding(28591).GetString($b).Contains("sladkiybaklazhanchik.exaroton.me")) {
        Set-Content -Path $marker -Value "already-present"
      } else {
        $okHdr = ($b.Length -ge ($hdr.Length + 5))
        if ($okHdr) { for ($k = 0; $k -lt $hdr.Length; $k++) { if ($b[$k] -ne $hdr[$k]) { $okHdr = $false } } }
        if ($okHdr) {
          $n = & $i32 $b $hdr.Length
          $start = $hdr.Length + 4
          $q = $start
          for ($k = 0; $k -lt $n; $k++) { $q = & $skip $b $q 10 }
          if ($q -eq ($b.Length - 1) -and $b[$q] -eq 0) {
            Copy-Item $sd "$sd.bak-sb" -Force
            $n1 = $n + 1
            $cnt = [byte[]]@([byte](($n1 -shr 24) -band 255), [byte](($n1 -shr 16) -band 255), [byte](($n1 -shr 8) -band 255), [byte]($n1 -band 255))
            $old = if ($q -gt $start) { $b[$start..($q - 1)] } else { [byte[]]@() }
            [IO.File]::WriteAllBytes($sd, [byte[]]($hdr + $cnt + $old + $entry + @(0)))
            Set-Content -Path $marker -Value "added"
          }
        }
      }
    }
  }
} catch { }
exit 0
