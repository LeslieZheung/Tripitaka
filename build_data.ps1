# 從 Google 試算表公開 CSV 匯出靜態快照 data.json（前端的備援來源）
# 用法：在 PowerShell 執行 .\build_data.ps1，會在同目錄產生 data.json，再上傳到 GitHub repo 根目錄。
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sheetId = '1kb4sh6Ct2PVFIBTf33VzkbUFBAjcCZV_lhUXbTVwuxA'
$sheetName = '目錄'
$url = "https://docs.google.com/spreadsheets/d/$sheetId/gviz/tq?tqx=out:csv&sheet=" + [uri]::EscapeDataString($sheetName)

$r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 180 -MaximumRedirection 5
$csvPath = Join-Path $dir 'sheet_main.csv'
[IO.File]::WriteAllBytes($csvPath, $r.RawContentStream.ToArray())

$map = @{ '經號'='work'; '經名(CBETA)'='title'; '譯者/作者'='creator'; '朝代'='dynasty'; '部類'='category'; '卷數'='juan'; '藏經'='canon';
          '介紹(簡)'='desc_s'; '介紹(繁)'='desc_t'; '我的註釋'='note'; '如是我聞連結'='rw_url'; 'CBETA連結'='cbeta_url'; '狀態'='status' }
$rows = Import-Csv -Path $csvPath -Encoding UTF8
$out = New-Object System.Collections.Generic.List[object]
foreach ($row in $rows) {
  if (-not $row.'經號') { continue }
  $o = [ordered]@{}
  foreach ($k in $map.Keys) { $v = $row.$k; if ($null -eq $v) { $v = '' }; $o[$map[$k]] = [string]$v }
  $n = 0; if ([int]::TryParse($o['juan'], [ref]$n)) { $o['juan'] = $n }
  if (-not $o['canon'] -and $o['work'] -match '^[A-Za-z]+') { $o['canon'] = $Matches[0] }
  if (-not $o['cbeta_url']) { $o['cbeta_url'] = 'https://cbetaonline.dila.edu.tw/zh-tw/' + $o['work'] }
  $out.Add([pscustomobject]$o)
}
$json = $out | ConvertTo-Json -Depth 3 -Compress
[IO.File]::WriteAllText((Join-Path $dir 'data.json'), $json, (New-Object System.Text.UTF8Encoding($false)))
"data.json: " + $out.Count + " records, " + (Get-Item (Join-Path $dir 'data.json')).Length + " bytes, withIntro=" + ($out | Where-Object { $_.desc_s -or $_.desc_t }).Count
