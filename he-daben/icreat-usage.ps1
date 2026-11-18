param(
  [switch]$NoToast
)

$ErrorActionPreference = 'Stop'
$base = 'https://icreat.ai/hub/third/api/nexus'
$homeDir = Join-Path $env:USERPROFILE '.icreat'
$tokenFile = Join-Path $homeDir 'token.txt'
$reportDir = Join-Path $PSScriptRoot 'reports'
New-Item -ItemType Directory -Force $reportDir | Out-Null

function Show-Toast([string]$title, [string]$text) {
  if ($NoToast) { Write-Host "$title`n$text"; return }
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $n = New-Object System.Windows.Forms.NotifyIcon
  $n.Icon = [System.Drawing.SystemIcons]::Information
  $n.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
  $n.BalloonTipTitle = $title
  $n.BalloonTipText = $text
  $n.Visible = $true
  $n.ShowBalloonTip(15000)
  Start-Sleep -Seconds 15
  $n.Dispose()
}

function Get-Headers([string]$token) {
  return @{
    'access-token-api' = $token
    'Accept' = 'application/json'
    'Referer' = 'https://icreat.ai/hub/dashboard'
    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36'
  }
}

try {
  if (-not (Test-Path $tokenFile)) { throw '缺少 ~/.icreat/token.txt' }
  $token = (Get-Content $tokenFile -Raw).Trim()
  if (-not $token) { throw 'token.txt 为空' }
  $h = Get-Headers $token

  $user = Invoke-RestMethod -Uri "$base/user/self" -Headers $h -TimeoutSec 30
  if (-not $user.success) { throw "iCreat: $($user.message)" }
  $u = $user.data
  $balanceUsd = if ($u.availableBalanceUsd) { [double]$u.availableBalanceUsd } else { [double]$u.quota / 500000.0 }

  $now = Get-Date
  $today = $now.Date
  $dates = @($today, $today.AddDays(-1), $today.AddDays(-2))
  $sum = @{}
  foreach ($d in $dates) { $sum[$d.ToString('yyyy-MM-dd')] = @{ fee = 0; count = 0 } }

  $items = @()
  $total = 0
  for ($p = 0; $p -lt 40; $p++) {
    $page = Invoke-RestMethod -Uri "$base/log/self?p=$p&page_size=100&type=0" -Headers $h -TimeoutSec 30
    if (-not $page.success) { throw "iCreat log: $($page.message)" }
    $batch = @($page.data.items)
    $total = [int]$page.data.total
    $items += $batch
    if ($batch.Count -eq 0 -or $items.Count -ge $total) { break }
  }

  foreach ($it in $items) {
    $ts = [DateTimeOffset]::FromUnixTimeSeconds([long]$it.created_at).LocalDateTime
    $key = $ts.ToString('yyyy-MM-dd')
    if ($sum.ContainsKey($key)) {
      $fee = if ($null -ne $it.cashFee) { [double]$it.cashFee } else { [double]$it.quota }
      $sum[$key].fee += $fee
      $sum[$key].count += 1
    }
  }

  $lines = @()
  $lines += ("余额 USD {0:N3}（{1:N0} 点）" -f $balanceUsd, [double]$u.quota)
  $labels = @('今日', '昨日', '前日')
  $total3 = 0.0
  $count3 = 0
  for ($i = 0; $i -lt 3; $i++) {
    $d = $dates[$i]
    $rec = $sum[$d.ToString('yyyy-MM-dd')]
    $usd = [double]$rec.fee / 500000.0
    $total3 += $usd
    $count3 += $rec.count
    $lines += ("{0} USD {1:N3} / {2} 次" -f $labels[$i], $usd, $rec.count)
  }
  $lines += ("3日合计 USD {0:N3} / {1} 次" -f $total3, $count3)

  $text = $lines -join "`n"
  $report = [pscustomobject]@{
    updated = $now.ToString('o')
    balanceUsd = $balanceUsd
    quota = [double]$u.quota
    usedQuota = [double]$u.usedQuota
    requestCount = [double]$u.requestCount
    days = @($dates | ForEach-Object {
      $d = $_
      $rec = $sum[$d.ToString('yyyy-MM-dd')]
      [pscustomobject]@{ date = $d.ToString('yyyy-MM-dd'); fee = [double]$rec.fee; usd = [double]$rec.fee / 500000.0; count = $rec.count }
    })
    total3Usd = $total3
    total3Count = $count3
    totalLogs = $total
  }
  $report | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $reportDir 'icreat-latest.json') -Encoding utf8
  $text | Set-Content (Join-Path $reportDir 'icreat-latest.txt') -Encoding utf8

  Show-Toast '何大奔 · iCreat 用量' $text
  Write-Host $text
  exit 0
} catch {
  $msg = "iCreat 查询失败：$($_.Exception.Message)`n请更新 ~/.icreat/token.txt"
  Show-Toast '何大奔 · iCreat 登录失效' $msg
  Write-Host $msg
  exit 1
}
