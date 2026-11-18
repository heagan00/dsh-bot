param(
  [switch]$NoToast
)

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
$reportDir = Join-Path $root 'reports'
$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force $reportDir, $logDir | Out-Null
$zhouJson = Join-Path $reportDir 'zhou-ge-latest.json'
$auditJson = Join-Path $reportDir 'liu-ge-latest.json'
$logFile = Join-Path $logDir 'liu-ge.log'
$stateFile = Join-Path $logDir 'liu-ge-state.json'
$node = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\DeepSeek Harness.exe'
$zhouAnalyzer = Join-Path $root '..\tools\zhou-ge-analyze.mjs'
$auditor = Join-Path $root '..\tools\liu-ge-audit.mjs'

function Log([string]$msg) {
  Add-Content -Path $logFile -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding utf8
}

function Run-Node([string]$script, [string[]]$arguments) {
  $old = $env:ELECTRON_RUN_AS_NODE
  $env:ELECTRON_RUN_AS_NODE = '1'
  try {
    $p = Start-Process -FilePath $node -ArgumentList (@($script) + $arguments) -Wait -PassThru -NoNewWindow
    return $p.ExitCode
  } finally {
    if ($null -eq $old) { Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue }
    else { $env:ELECTRON_RUN_AS_NODE = $old }
  }
}

$mutex = New-Object System.Threading.Mutex($false, 'Global\LiuGeBot')
if (-not $mutex.WaitOne(0)) { exit 0 }

try {
  if (-not (Test-Path $node)) { Log 'node missing'; exit 1 }
  $code = Run-Node $zhouAnalyzer @('--minutes=30', "--out=$zhouJson")
  if ($code -ne 0) { Log "zhou analyzer failed $code"; exit 1 }
  $code = Run-Node $auditor @("--report=$zhouJson", "--out=$auditJson")
  if ($code -ne 0) { Log "audit failed $code"; exit 1 }

  if (-not (Test-Path $auditJson)) { Log 'no audit'; exit 1 }
  $audit = Get-Content $auditJson -Raw -Encoding UTF8 | ConvertFrom-Json
  $items = @($audit.falsePositives)
  if ($items.Count -eq 0) { Log 'no false positives'; exit 0 }

  $state = @{}
  if (Test-Path $stateFile) {
    try {
      $s = Get-Content $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
      $s.PSObject.Properties | ForEach-Object { $state[$_.Name] = [long]$_.Value }
    } catch {}
  }
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $show = @()
  foreach ($a in $items) {
    $key = [string]$a.zhouKey
    $last = if ($state.ContainsKey($key)) { [long]$state[$key] } else { 0 }
    if ($now - $last -lt 1800) { continue }
    $state[$key] = $now
    $show += $a
  }
  if ($show.Count -eq 0) { Log 'all rate-limited'; exit 0 }
  $state | ConvertTo-Json | Set-Content $stateFile -Encoding utf8

  $text = @()
  foreach ($a in $show | Select-Object -First 5) {
    $text += ('【误报】' + $a.title)
    $text += ('周哥说：' + $a.zhouMessage)
    $text += ('周哥的问题：' + $a.problem)
    $text += ('会话为什么没问题：' + $a.whyFine)
    $text += ('刘哥建议：' + $a.advice)
    $text += ''
  }
  $body = ($text -join "`r`n").Trim()

  $md = @('# 刘哥 · 周哥提醒复核', '', ('- 时间：' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')), ('- 误报：' + $show.Count), '')
  foreach ($a in $show) {
    $md += ('## ' + $a.title); $md += ''
    $md += ('周哥说：' + $a.zhouMessage); $md += ''
    $md += ('问题：' + $a.problem); $md += ''
    $md += ('为什么没问题：' + $a.whyFine); $md += ''
    $md += ('建议：' + $a.advice); $md += ''
  }
  Set-Content (Join-Path $reportDir 'liu-ge-latest.md') ($md -join "`n") -Encoding utf8
  Log ("false positives shown={0}" -f $show.Count)

  if ($NoToast) { Write-Output $body; exit 0 }

  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $form = New-Object System.Windows.Forms.Form
  $form.Text = '刘哥 · 周哥提醒复核'
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
  $form.TopMost = $true
  $form.ShowInTaskbar = $false
  $form.Width = 640
  $form.Height = 460
  $form.BackColor = [System.Drawing.Color]::FromArgb(20, 24, 28)
  $screen = [System.Windows.Forms.Screen]::PrimaryScreen
  $wa = $screen.WorkingArea
  $form.Left = $wa.Left + [int](($wa.Width - $form.Width) / 2)
  $form.Top = $wa.Bottom - $form.Height - 24
  Log ("position={0},{1} screen={2}" -f $form.Left, $form.Top, $screen.DeviceName)

  $accent = New-Object System.Windows.Forms.Panel
  $accent.Dock = [System.Windows.Forms.DockStyle]::Top
  $accent.Height = 5
  $accent.BackColor = [System.Drawing.Color]::FromArgb(74, 150, 210)
  $form.Controls.Add($accent)

  $title = New-Object System.Windows.Forms.Label
  $title.Text = '刘哥 · 周哥提醒复核'
  $title.Font = New-Object System.Drawing.Font('Microsoft YaHei', 15, [System.Drawing.FontStyle]::Bold)
  $title.ForeColor = [System.Drawing.Color]::FromArgb(190, 225, 250)
  $title.Left = 22; $title.Top = 16; $title.Width = 540; $title.Height = 30
  $form.Controls.Add($title)

  $close = New-Object System.Windows.Forms.Button
  $close.Text = '×'
  $close.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $close.FlatAppearance.BorderSize = 0
  $close.ForeColor = [System.Drawing.Color]::FromArgb(180, 190, 200)
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
  $box.ForeColor = [System.Drawing.Color]::FromArgb(220, 230, 238)
  $box.Font = New-Object System.Drawing.Font('Microsoft YaHei', 10.5)
  $box.Left = 20; $box.Top = 56; $box.Width = 600; $box.Height = 380
  $form.Controls.Add($box)

  $script:liuConfirmed = $false
  $script:liuConfirming = $false
  $form.Add_FormClosing({
    param($sender, $e)
    if ($script:liuConfirmed) { return }
    $e.Cancel = $true
    if ($script:liuConfirming) { return }
    $script:liuConfirming = $true
    try {
      $dlg = New-Object System.Windows.Forms.Form
      $dlg.Text = '刘哥 · 二次确认'
      $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
      $dlg.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
      $dlg.TopMost = $true
      $dlg.ShowInTaskbar = $false
      $dlg.Width = 380
      $dlg.Height = 180
      $dlg.BackColor = [System.Drawing.Color]::FromArgb(24, 28, 32)

      $label = New-Object System.Windows.Forms.Label
      $label.Text = "确认关闭刘哥提醒？`r`n必须手动点击「确认关闭」才会消失。"
      $label.ForeColor = [System.Drawing.Color]::FromArgb(225, 235, 245)
      $label.Font = New-Object System.Drawing.Font('Microsoft YaHei', 10.5)
      $label.Left = 20; $label.Top = 18; $label.Width = 340; $label.Height = 60
      $dlg.Controls.Add($label)

      $keep = New-Object System.Windows.Forms.Button
      $keep.Text = '保留'
      $keep.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
      $keep.Left = 170; $keep.Top = 100; $keep.Width = 80; $keep.Height = 32
      $keep.UseVisualStyleBackColor = $false
      $keep.BackColor = [System.Drawing.Color]::FromArgb(58, 64, 72)
      $keep.ForeColor = [System.Drawing.Color]::FromArgb(240, 242, 245)
      $keep.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
      $keep.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(100, 110, 122)
      $keep.Font = New-Object System.Drawing.Font('Microsoft YaHei', 9.5)
      $dlg.Controls.Add($keep)

      $ok = New-Object System.Windows.Forms.Button
      $ok.Text = '确认关闭'
      $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
      $ok.Left = 262; $ok.Top = 100; $ok.Width = 90; $ok.Height = 32
      $ok.UseVisualStyleBackColor = $false
      $ok.BackColor = [System.Drawing.Color]::FromArgb(74, 150, 210)
      $ok.ForeColor = [System.Drawing.Color]::White
      $ok.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
      $ok.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(110, 180, 235)
      $ok.Font = New-Object System.Drawing.Font('Microsoft YaHei', 9.5, [System.Drawing.FontStyle]::Bold)
      $dlg.Controls.Add($ok)

      # 回车/ESC 都默认「保留」，必须鼠标点「确认关闭」
      $dlg.AcceptButton = $keep
      $dlg.CancelButton = $keep

      $res = $dlg.ShowDialog($form)
      $dlg.Dispose()
      if ($res -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:liuConfirmed = $true
        $form.Close()
      }
    } finally {
      $script:liuConfirming = $false
    }
  })

  [System.Windows.Forms.Application]::Run($form)
  $form.Dispose()
} finally {
  try { $mutex.ReleaseMutex() } catch {}
  $mutex.Dispose()
}
