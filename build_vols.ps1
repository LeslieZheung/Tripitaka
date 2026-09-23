# 建 vols.json：經號 -> 冊號（可能是範圍如 T05..T07），並用 cbeta-org/xml-p5 的檔案樹驗證 XML 路徑存在
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = 'https://raw.githubusercontent.com/DILA-edu/Authority-Databases/master/authority_catalog/json/'
$canons = 'T','X','J','B','ZW','I','G','GA','GB','D','Y','YP','N','F','L','TX','P','C','CC','K','A','LC','M','S','U','ZS'

$vols = [ordered]@{}
$alts = [ordered]@{}
foreach ($c in $canons) {
  try {
    $j = Invoke-RestMethod -Uri ($base + "$c.json") -TimeoutSec 120
    foreach ($p in $j.PSObject.Properties) {
      if ($p.Value.vol) { $vols[$p.Name] = [string]$p.Value.vol }
      if ($p.Value.alt) { $alts[$p.Name] = [string]$p.Value.alt }
    }
  } catch { Write-Warning "$c.json failed: $($_.Exception.Message)" }
}
"works with vol: " + $vols.Count

# 檔案樹
$t = Invoke-RestMethod -Uri "https://api.github.com/repos/cbeta-org/xml-p5/git/trees/master?recursive=1" -Headers @{ "User-Agent"="sutra-index" } -TimeoutSec 180
$paths = @{}
foreach ($f in $t.tree) { if ($f.type -eq 'blob' -and $f.path -like '*.xml') { $paths[$f.path] = $f.size } }
"xml files in tree: " + $paths.Count

function Expand-Vols([string]$v) {
  $m = [regex]::Match($v, '^([A-Za-z]+)(\d+)\.\.([A-Za-z]+)?(\d+)$')
  if (-not $m.Success) { return @($v) }
  $p = $m.Groups[1].Value; $a = [int]$m.Groups[2].Value; $b = [int]$m.Groups[4].Value; $w = $m.Groups[2].Value.Length
  $out = @(); for ($i = $a; $i -le $b; $i++) { $out += ($p + $i.ToString().PadLeft($w, '0')) }; return $out
}
function Xml-Path([string]$vol, [string]$work) {
  $letters = [regex]::Match($vol, '^[A-Za-z]+').Value
  return "$letters/$vol/${vol}n" + $work.Substring($letters.Length) + ".xml"
}

$ok = 0; $missing = @(); $files = [ordered]@{}
foreach ($k in $vols.Keys) {
  $list = Expand-Vols $vols[$k]
  $found = @()
  foreach ($v in $list) { $p = Xml-Path $v $k; if ($paths.ContainsKey($p)) { $found += $p } }
  if ($found.Count -gt 0) { $ok++; $files[$k] = $found } else { $missing += $k }
}
"resolved: $ok  missing: " + $missing.Count
"missing sample: " + (($missing | Select-Object -First 25) -join ', ')

# 異本：CBETA 未重複收錄，指向正本經號（可能多個，逗號分隔；取第一個有檔的）
$altOut = [ordered]@{}; $altResolved = 0
foreach ($k in $missing) {
  if (-not $alts.Contains($k)) { continue }
  $cands = $alts[$k] -split '\s*,\s*'
  $hit = $cands | Where-Object { $files.Contains($_) } | Select-Object -First 1
  if ($hit) { $altOut[$k] = $hit; $altResolved++ }
}
"alt resolved: $altResolved  still missing: " + ($missing.Count - $altResolved)

# 輸出：{ files: 經號 -> [XML 相對路徑...], alt: 異本經號 -> 正本經號 }
$json = [ordered]@{ files = $files; alt = $altOut } | ConvertTo-Json -Depth 4 -Compress
[IO.File]::WriteAllText((Join-Path $dir 'vols.json'), $json, (New-Object System.Text.UTF8Encoding($false)))
"vols.json bytes: " + (Get-Item (Join-Path $dir 'vols.json')).Length
"X0002 alt -> " + $altOut['X0002']
"T0220 -> " + ($files['T0220'] -join ', ')
"JB277 -> " + ($files['JB277'] -join ', ')
"GA0057 -> " + ($files['GA0057'] -join ', ')
"X1565 -> " + ($files['X1565'] -join ', ')
