param(
  [switch]$NoToast
)

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
$reportDir = Join-Path $root 'reports'
$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force $reportDir, $logDir | Out-Null
$jsonFile = Join-Path $reportDir 'zhou-ge-latest.json'
$logFile = Join-Path $logDir 'zhou-ge.log'
$stateFile = Join-Path $logDir 'zhou-ge-state.json'
$node = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\DeepSeek Harness.exe'
$analyzer = Join-Path $root '..\tools\zhou-ge-analyze.mjs'

function Log([string]$msg) {
  Add-Content -Path $logFile -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding utf8
}

$mutex = New-Object System.Threading.Mutex($false, 'Global\ZhouGeBot')
if (-not $mutex.WaitOne(0)) { exit 0 }

try {
  if (-not (Test-Path $node)) { Log 'DSH node missing'; exit 1 }
  $old = $env:ELECTRON_RUN_AS_NODE
  $env:ELECTRON_RUN_AS_NODE = '1'
  try {
    $p = Start-Process -FilePath $node -ArgumentList @($analyzer, '--minutes=30', "--out=$jsonFile") -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -ne 0) { Log "analyzer failed $($p.ExitCode)"; exit 1 }
  } finally {
    if ($null -eq $old) { Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue }
    else { $env:ELECTRON_RUN_AS_NODE = $old }
  }

  if (-not (Test-Path $jsonFile)) { Log 'no report'; exit 1 }
  $data = Get-Content $jsonFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $alerts = @($data.alerts)
  if ($alerts.Count -eq 0) {
    Log 'no alerts'
    exit 0
  }

  $state = @{}
  if (Test-Path $stateFile) {
    try {
      $s = Get-Content $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
      $s.PSObject.Properties | ForEach-Object { $state[$_.Name] = [long]$_.Value }
    } catch {}
  }

  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $show = @()
  $high = $false
  foreach ($a in $alerts) {
    $key = [string]$a.key
    $last = if ($state.ContainsKey($key)) { [long]$state[$key] } else { 0 }
    $minGap = if ($a.level -eq 'high') { 1200 } else { 1800 }
    if ($now - $last -lt $minGap) { continue }
    if ($a.level -eq 'high') { $high = $true }
    $show += $a
    $state[$key] = $now
  }
  if ($show.Count -eq 0) { Log 'all alerts rate-limited'; exit 0 }

  $state | ConvertTo-Json | Set-Content $stateFile -Encoding utf8

  $text = @()
  foreach ($a in $show | Select-Object -First 6) {
    $tag = if ($a.level -eq 'high') { '【高优先级 · 算力/浪费】' } else { '【建议】' }
    $text += ($tag + ' ' + $a.title)
    $text += $a.message
    $text += ('建议：' + $a.advice)
    $text += ''
  }
  $body = ($text -join "`r`n").Trim()

  $md = @(
    '# 周哥 · 全栈主程巡检',
    '',
    ('- 时间：' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')),
    ('- 活跃会话：' + $data.activeSessions),
    ('- 提醒：' + $show.Count),
    ''
  )
  foreach ($a in $show) {
    $md += ('## ' + $(if ($a.level -eq 'high') { '高优先级' } else { '建议' }) + ' · ' + $a.title)
    $md += ''
    $md += $a.message
    $md += ''
    $md += ('建议：' + $a.advice)
    $md += ''
  }
  Set-Content (Join-Path $reportDir 'zhou-ge-latest.md') ($md -join "`n") -Encoding utf8

  Log ("alerts={0} high={1}" -f $show.Count, $high)
  if ($NoToast) { Write-Output $body; exit 0 }

  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $form = New-Object System.Windows.Forms.Form
  $form.Text = '周哥 · 全栈主程巡检'
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
  $form.TopMost = $true
  $form.ShowInTaskbar = $false
  $form.Width = 640
  $form.Height = 460
  $form.BackColor = [System.Drawing.Color]::FromArgb(22, 22, 26)
  $screen = [System.Windows.Forms.Screen]::PrimaryScreen
  $wa = $screen.WorkingArea
  $form.Left = $wa.Left + [int](($wa.Width - $form.Width) / 2)
  $form.Top = $wa.Top + 24
  Log ("position={0},{1} screen={2}" -f $form.Left, $form.Top, $screen.DeviceName)

  $accent = New-Object System.Windows.Forms.Panel
  $accent.Dock = [System.Windows.Forms.DockStyle]::Top
  $accent.Height = 5
  $accent.BackColor = if ($high) { [System.Drawing.Color]::FromArgb(224, 74, 64) } else { [System.Drawing.Color]::FromArgb(224, 160, 64) }
  $form.Controls.Add($accent)

  $title = New-Object System.Windows.Forms.Label
  $title.Text = if ($high) { '周哥 · 算力浪费警报' } else { '周哥 · 主程建议' }
  $title.Font = New-Object System.Drawing.Font('Microsoft YaHei', 15, [System.Drawing.FontStyle]::Bold)
  $title.ForeColor = if ($high) { [System.Drawing.Color]::FromArgb(255, 190, 180) } else { [System.Drawing.Color]::FromArgb(245, 220, 170) }
  $title.Left = 22; $title.Top = 16; $title.Width = 540; $title.Height = 30
  $form.Controls.Add($title)

  $close = New-Object System.Windows.Forms.Button
  $close.Text = '×'
  $close.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $close.FlatAppearance.BorderSize = 0
  $close.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 190)
  $close.BackColor = $form.BackColor
  $close.Font = New-Object System.Drawing.Font('Microsoft YaHei', 15)
  $close.Left = 600; $close.Top = 10; $close.Width = 30; $close.Height = 30
  $close.Add_Click({ $form.Close() })
  $form.Controls.Add($close)

  $box = New-Object System.Windows.Forms.RichTextBox
  $box.Text = $body
  $box.ReadOnly = $true
  $box.BorderStyle = [System.Windows.Forms.BorderStyle]::None
  $box.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
  $box.BackColor = $form.BackColor
  $box.ForeColor = [System.Drawing.Color]::FromArgb(225, 225, 232)
  $box.Font = New-Object System.Drawing.Font('Microsoft YaHei', 10.5)
  $box.Left = 20; $box.Top = 56; $box.Width = 600; $box.Height = 380
  $form.Controls.Add($box)

  $timer = New-Object System.Windows.Forms.Timer
  $timer.Interval = 90000
  $timer.Add_Tick({ $form.Close() })
  $form.Add_Shown({ $timer.Start() })
  $form.Add_FormClosed({ $timer.Stop(); $timer.Dispose() })
  [System.Windows.Forms.Application]::Run($form)
  $form.Dispose()
} finally {
  try { $mutex.ReleaseMutex() } catch {}
  $mutex.Dispose()
}
