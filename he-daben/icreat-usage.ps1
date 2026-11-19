param(
  [switch]$NoToast,
  [switch]$ReportOnly
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
. (Join-Path $root 'ui-theme.ps1')
$base = 'https://icreat.ai/hub/third/api/nexus'
$homeDir = Join-Path $env:USERPROFILE '.icreat'
$tokenFile = Join-Path $homeDir 'token.txt'
$reportDir = Join-Path $PSScriptRoot 'reports'
New-Item -ItemType Directory -Force $reportDir | Out-Null

function Show-Toast([string]$title, [string]$text) {
  if ($NoToast) { Write-Host "$title`n$text"; return }
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $form = New-Object System.Windows.Forms.Form
  $form.Text = $title
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
  $form.TopMost = $true
  $form.ShowInTaskbar = $false
  $form.Width = 560
  $form.Height = 340
  Set-DshCardStyle $form ([System.Drawing.Color]::FromArgb(80, 170, 140))
  $form.BackColor = [System.Drawing.Color]::FromArgb(22, 26, 30)
  $screen = [System.Windows.Forms.Screen]::PrimaryScreen
  $wa = $screen.WorkingArea
  $form.Left = $wa.Right - $form.Width - 24
  $form.Top = $wa.Bottom - $form.Height - 24

  $accent = New-Object System.Windows.Forms.Panel
  $accent.Dock = [System.Windows.Forms.DockStyle]::Top
  $accent.Height = 5
  $accent.BackColor = [System.Drawing.Color]::FromArgb(80, 170, 140)
  $form.Controls.Add($accent)

  $label = New-Object System.Windows.Forms.Label
  $label.Text = $title
  $label.Font = New-Object System.Drawing.Font('Microsoft YaHei', 14, [System.Drawing.FontStyle]::Bold)
  $label.ForeColor = [System.Drawing.Color]::FromArgb(200, 240, 225)
  $label.Left = 22; $label.Top = 18; $label.Width = 470; $label.Height = 30
  $form.Controls.Add($label)

  $close = New-Object System.Windows.Forms.Button
  $close.Text = '×'
  $close.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $close.FlatAppearance.BorderSize = 0
  $close.ForeColor = [System.Drawing.Color]::FromArgb(180, 200, 195)
  $close.BackColor = $form.BackColor
  $close.Font = New-Object System.Drawing.Font('Microsoft YaHei', 15)
  $close.Left = 520; $close.Top = 10; $close.Width = 30; $close.Height = 30
  $close.Add_Click({ $form.Close() })
  $form.Controls.Add($close)

  $box = New-Object System.Windows.Forms.RichTextBox
  $box.Text = $text
  $box.ReadOnly = $true
  $box.BorderStyle = [System.Windows.Forms.BorderStyle]::None
  $box.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
  $box.BackColor = $form.BackColor
  $box.ForeColor = [System.Drawing.Color]::FromArgb(220, 235, 230)
  $box.Font = New-Object System.Drawing.Font('Microsoft YaHei', 11)
  $box.Left = 20; $box.Top = 58; $box.Width = 520; $box.Height = 260
  $form.Controls.Add($box)
  $form.Add_Shown({
    $box.SelectionStart = 0
    $box.SelectionLength = 0
    $box.ScrollToCaret()
  })

  [System.Windows.Forms.Application]::Run($form)
  $form.Dispose()
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

  # 30 天 iCreat 用量（用于周报/月报）
  $monthStart = $now.Date.AddDays(-29)
  $map30 = @{}
  foreach ($it in $items) {
    $ts = [DateTimeOffset]::FromUnixTimeSeconds([long]$it.created_at).LocalDateTime
    if ($ts.Date -lt $monthStart) { continue }
    $key = $ts.ToString('yyyy-MM-dd')
    if (-not $map30.ContainsKey($key)) { $map30[$key] = @{ fee = 0.0; count = 0 } }
    $fee = if ($null -ne $it.cashFee) { [double]$it.cashFee } else { [double]$it.quota }
    $map30[$key].fee += $fee
    $map30[$key].count += 1
  }
  $weekStart = $now.Date.AddDays(-6)
  $weekFee = 0.0; $weekCount = 0; $monthFee = 0.0; $monthCount = 0
  foreach ($k in $map30.Keys) {
    $d = [datetime]::ParseExact($k, 'yyyy-MM-dd', $null)
    if ($d -ge $weekStart) { $weekFee += $map30[$k].fee; $weekCount += $map30[$k].count }
    if ($d -ge $monthStart) { $monthFee += $map30[$k].fee; $monthCount += $map30[$k].count }
  }

  # DeepSeek Harness token 用量
  $dshUsageFile = Join-Path $reportDir 'dsh-usage.json'
  $node = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\DeepSeek Harness.exe'
  $dsh = $null
  $env:ELECTRON_RUN_AS_NODE = '1'
  try {
    $null = Start-Process -FilePath $node -ArgumentList @((Join-Path $root '..\tools\dsh-usage.mjs'), "--out=$dshUsageFile") -Wait -PassThru -NoNewWindow
  } catch {}
  try { if (Test-Path $dshUsageFile) { $dsh = Get-Content $dshUsageFile -Raw -Encoding utf8 | ConvertFrom-Json } } catch {}
  Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue

  $usageLines = @(
    '# 何大奔 · 用量报表',
    '',
    ('- 时间：' + $now.ToString('yyyy-MM-dd HH:mm:ss')),
    '',
    '## iCreat',
    '',
    ('- 本周：USD {0:N3} / {1} 次' -f ($weekFee / 500000.0), $weekCount),
    ('- 本月：USD {0:N3} / {1} 次' -f ($monthFee / 500000.0), $monthCount),
    ('- 余额：USD {0:N3}（{1:N0} 点）' -f $balanceUsd, [double]$u.quota),
    '',
    '## DeepSeek Harness',
    ''
  )
  if ($dsh) {
    $usageLines += ('- 今日：{0:N0} tokens / {1} 条消息' -f [double]$dsh.today.tokens, [double]$dsh.today.messages)
    $usageLines += ('- 本周：{0:N0} tokens / 会话 {1}' -f [double]$dsh.week.tokens, [double]$dsh.week.sessions)
    $usageLines += ('- 本月：{0:N0} tokens / 会话 {1}' -f [double]$dsh.month.tokens, [double]$dsh.month.sessions)
    $usageLines += ('- 累计：{0:N0} tokens / 会话 {1}' -f [double]$dsh.total.tokens, [double]$dsh.total.sessions)
  } else {
    $usageLines += '- DSH 用量读取失败；检查 ~/.dsh/sessions。'
  }
  $usageLines += @('', '## 结论', '', '- iCreat 按现金消耗统计；DSH 按会话 token 统计，两者口径不同，不直接相加。')
  $usageText = $usageLines -join "`n"
  Set-Content (Join-Path $reportDir 'usage-latest.md') $usageText -Encoding utf8
  $siteContent = Join-Path $root '..\site\content'
  New-Item -ItemType Directory -Force $siteContent | Out-Null
  Set-Content (Join-Path $siteContent '92-usage-report.md') $usageText -Encoding utf8
  if ($now.DayOfWeek -eq 'Monday') { Set-Content (Join-Path $siteContent '92-usage-weekly.md') $usageText -Encoding utf8 }
  if ($now.Day -eq 1) { Set-Content (Join-Path $siteContent '92-usage-monthly.md') $usageText -Encoding utf8 }
  if ($ReportOnly) { Write-Host $usageText; exit 0 }

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
  if ($dsh) {
    $lines += ''
    $lines += ("DSH 今日 {0:N0} tokens / {1} 条" -f [double]$dsh.today.tokens, [double]$dsh.today.messages)
    $lines += ("DSH 本周 {0:N0} tokens" -f [double]$dsh.week.tokens)
    $lines += ("DSH 本月 {0:N0} tokens" -f [double]$dsh.month.tokens)
  } else {
    $lines += ''
    $lines += 'DSH 用量读取失败'
  }

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

  Show-Toast '何大奔 · iCreat + DSH 用量' $text
  Write-Host $text
  exit 0
} catch {
  $msg = "iCreat 查询失败：$($_.Exception.Message)`n请更新 ~/.icreat/token.txt"
  Show-Toast '何大奔 · iCreat 登录失效' $msg
  Write-Host $msg
  exit 1
}
