param(
  [switch]$NoToast,
  [switch]$RepeatAudit
)

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
. (Join-Path $root 'ui-theme.ps1')
$reportDir = Join-Path $root 'reports'
$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force $reportDir, $logDir | Out-Null
$zhouJson = Join-Path $reportDir 'zhou-ge-latest.json'
$auditJson = Join-Path $reportDir 'liu-ge-latest.json'
$logFile = Join-Path $logDir 'liu-ge.log'
$stateFile = Join-Path $logDir 'liu-ge-state.json'
$memoryDir = Join-Path $root '..\memory'
if (-not (Test-Path $memoryDir)) { $memoryDir = Join-Path $root 'memory' }
$memoryFile = Join-Path $memoryDir 'zhou-memory.json'
New-Item -ItemType Directory -Force $memoryDir | Out-Null
$node = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\DeepSeek Harness.exe'
$zhouAnalyzer = Join-Path $root '..\tools\zhou-ge-analyze.mjs'
$auditor = Join-Path $root '..\tools\liu-ge-audit.mjs'

function Log([string]$msg) {
  Add-Content -Path $logFile -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding utf8
}

function Get-IssueKey([string]$key) {
  if (-not $key) { return '' }
  $parts = @($key -split ':' | Where-Object { $_ -ne '' -and $_ -notlike 'session-*' })
  return ($parts -join ':')
}

function Save-ZhouMemory($finding, [bool]$agree) {
  $mem = @{ owner = '周哥'; updated = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); entries = @{} }
  if (Test-Path $memoryFile) {
    try {
      $old = Get-Content $memoryFile -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($old.entries) { $old.entries.PSObject.Properties | ForEach-Object { $mem.entries[$_.Name] = $_.Value } }
    } catch {}
  }
  $zhouKey = [string]$finding.zhouKey
  $pattern = [string]$finding.pattern
  if (-not $pattern) { $pattern = ($zhouKey -split ':')[0] }
  # 记忆按「同一个问题」记：用去掉会话 id 的 key（repeat:wait_agent / token），
  # 周哥下次遇到同一个问题就直接命中、不再提示，跨会话同样生效。
  $issueKey = Get-IssueKey $zhouKey
  $entryKey = if ($issueKey) { $issueKey } elseif ($zhouKey) { $zhouKey } else { $pattern }
  $entry = $mem.entries[$entryKey]
  if (-not $entry) {
    $entry = [pscustomobject]@{ count = 0; agreed = $false; last = ''; session = ''; zhouMessage = ''; judgment = '' }
  }
  $entry.count = [int]$entry.count + 1
  $entry.agreed = $agree
  $entry.last = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $entry.session = [string]$finding.sessionId
  $entry.zhouMessage = [string]$finding.zhouMessage
  $entry.judgment = if ($agree) { '刘哥判断正确：周哥本次为误报' } else { '用户不同意刘哥判断' }
  $mem.entries[$entryKey] = $entry
  $mem | ConvertTo-Json -Depth 6 | Set-Content $memoryFile -Encoding utf8

  $rows = @('# 周哥的小脑袋瓜', '', '> 周哥（刘哥下属）记录刘哥复核结论；同意后才用于抑制同类误报。', '', '| 模式 | 次数 | 结论 | 最近 |', '|---|---:|---|---|')
  foreach ($k in $mem.entries.Keys) {
    $e = $mem.entries[$k]
    $rows += ("| {0} | {1} | {2} | {3} |" -f $k, $e.count, $e.judgment, $e.last)
  }
  Set-Content (Join-Path $memoryDir '周哥的小脑袋瓜.md') ($rows -join "`n") -Encoding utf8
  Log ("memory key={0} agree={1} count={2}" -f $entryKey, $agree, $entry.count)
}

function Run-Node([string]$script, [string[]]$arguments) {
  $old = $env:ELECTRON_RUN_AS_NODE
  $env:ELECTRON_RUN_AS_NODE = '1'
  try {
    $p = Start-Process -FilePath $node -ArgumentList (@($script) + $arguments) -Wait -PassThru -NoNewWindow
    # Electron 以 node 方式跑时 ExitCode 常常读不到，返回 $null 交给调用方按产物判断
    try { return $p.ExitCode } catch { return $null }
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
  if ($null -ne $code -and $code -ne 0) { Log "zhou analyzer failed $code"; exit 1 }
  $code = Run-Node $auditor @("--report=$zhouJson", "--out=$auditJson", "--memory=$memoryFile")
  if ($null -ne $code -and $code -ne 0) { Log "audit failed $code"; exit 1 }

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
    # 重复误报的严厉纠偏不受 30 分钟降噪限制
    if ($a.severe) {
      $state[$key] = $now
      $show += $a
      continue
    }
    if ($now - $last -lt 1800) { continue }
    $state[$key] = $now
    $show += $a
  }
  if ($show.Count -eq 0) { Log 'all rate-limited'; exit 0 }
  $state | ConvertTo-Json | Set-Content $stateFile -Encoding utf8

  $text = @()
  $severeCount = @($show | Where-Object { $_.severe }).Count
  if ($severeCount -gt 0) {
    $text += '【重复误报 · 严厉纠偏】'
    $text += ('周哥，同一个判断你已经犯过 ' + $severeCount + ' 次。刘哥提醒不是建议，是纠偏；下次先查记忆再弹窗。')
    $text += ''
  }
  foreach ($a in $show | Select-Object -First 5) {
    $tag = if ($a.severe) { '【再次误报】' } else { '【误报】' }
    $text += ($tag + $a.title)
    if ($a.repeatCount -gt 0) { $text += ('记忆：同类已被纠正 ' + $a.repeatCount + ' 次，仍再次出现。') }
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

  $script:liuShow = $show
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $form = New-Object System.Windows.Forms.Form
  $form.Text = '刘哥 · 周哥提醒复核'
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
  $form.TopMost = $true
  $form.ShowInTaskbar = $false
  $form.Width = 640
  $form.Height = 500
  Set-DshCardStyle $form ([System.Drawing.Color]::FromArgb(74, 150, 210))
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
  $box.Left = 20; $box.Top = 56; $box.Width = 600; $box.Height = 300
  $form.Controls.Add($box)

  $choiceLabel = New-Object System.Windows.Forms.Label
  $choiceLabel.Text = '刘哥判断是否正确？关闭时记录到「周哥的小脑袋瓜」：'
  $choiceLabel.ForeColor = [System.Drawing.Color]::FromArgb(190, 205, 215)
  $choiceLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei', 9)
  $choiceLabel.Left = 20; $choiceLabel.Top = 362; $choiceLabel.Width = 590; $choiceLabel.Height = 22
  $form.Controls.Add($choiceLabel)

  $script:liuAgree = New-Object System.Windows.Forms.CheckBox
  $script:liuAgree.Text = '同意（刘哥判断正确，记入周哥记忆）'
  $script:liuAgree.ForeColor = [System.Drawing.Color]::FromArgb(150, 220, 190)
  $script:liuAgree.Font = New-Object System.Drawing.Font('Microsoft YaHei', 9.5)
  $script:liuAgree.Left = 20; $script:liuAgree.Top = 388; $script:liuAgree.Width = 300; $script:liuAgree.Height = 28
  $script:liuAgree.BackColor = $form.BackColor
  $form.Controls.Add($script:liuAgree)

  $script:liuDisagree = New-Object System.Windows.Forms.CheckBox
  $script:liuDisagree.Text = '不同意（周哥判断仍成立）'
  $script:liuDisagree.ForeColor = [System.Drawing.Color]::FromArgb(230, 190, 150)
  $script:liuDisagree.Font = New-Object System.Drawing.Font('Microsoft YaHei', 9.5)
  $script:liuDisagree.Left = 330; $script:liuDisagree.Top = 388; $script:liuDisagree.Width = 260; $script:liuDisagree.Height = 28
  $script:liuDisagree.BackColor = $form.BackColor
  $form.Controls.Add($script:liuDisagree)

  $script:liuAgree.Add_CheckedChanged({
    if ($script:liuAgree.Checked -and $script:liuDisagree.Checked) { $script:liuDisagree.Checked = $false }
  })
  $script:liuDisagree.Add_CheckedChanged({
    if ($script:liuDisagree.Checked -and $script:liuAgree.Checked) { $script:liuAgree.Checked = $false }
  })

  $script:liuConfirmed = $false
  $script:liuConfirming = $false
  $form.Add_FormClosing({
    param($sender, $e)
    if ($script:liuConfirmed) { return }
    if (-not $script:liuAgree.Checked -and -not $script:liuDisagree.Checked) {
      [System.Windows.Forms.MessageBox]::Show(
        '请先勾选「同意」或「不同意」，再关闭。',
        '刘哥 · 记录判断',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
      ) | Out-Null
      $e.Cancel = $true
      return
    }
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
        $agree = [bool]$script:liuAgree.Checked
        foreach ($a in $script:liuShow) { Save-ZhouMemory $a $agree }
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
