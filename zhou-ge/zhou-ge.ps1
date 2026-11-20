param(
  [switch]$NoToast,
  [switch]$Force,
  [int]$IdleAfter = 30,
  [string]$SessionsRoot = ''
)

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
. (Join-Path $root 'ui-theme.ps1')
$reportDir = Join-Path $root 'reports'
$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force $reportDir, $logDir | Out-Null
$jsonFile = Join-Path $reportDir 'zhou-ge-latest.json'
$logFile = Join-Path $logDir 'zhou-ge.log'
$stateFile = Join-Path $logDir 'zhou-ge-state.json'
$node = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\DeepSeek Harness.exe'
$analyzer = Join-Path $root '..\tools\zhou-ge-analyze.mjs'
if (-not $SessionsRoot) { $SessionsRoot = Join-Path $env:USERPROFILE '.dsh\sessions' }

function Log([string]$msg) {
  Add-Content -Path $logFile -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding utf8
}

# 记忆键归一：「同一个问题」= 去掉会话 id 之后的 key。
# 分析器的 key 形如 repeat:<sessionId>:wait_agent、token:<sessionId>、dupe:<目标>，
# 去掉 session-* 段后就是跨会话稳定的问题标识（repeat:wait_agent / token）。
function Get-IssueKey([string]$key) {
  if (-not $key) { return '' }
  $parts = @($key -split ':' | Where-Object { $_ -ne '' -and $_ -notlike 'session-*' })
  return ($parts -join ':')
}

# 刘哥脚本的落点：部署时可能拷平到本目录，仓库里在 ..\liu-ge\ 下。
# 以前写死 $root\liu-ge.ps1，仓库布局下 Test-Path 为假就静默不断言，周哥→刘哥这条链路是断的。
function Find-LiuGe {
  $candidates = @(
    (Join-Path $root 'liu-ge.ps1'),
    (Join-Path $root '..\liu-ge\liu-ge.ps1'),
    (Join-Path $root '..\..\liu-ge\liu-ge.ps1')
  )
  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { return (Resolve-Path -LiteralPath $c).Path }
  }
  return $null
}

$mutex = New-Object System.Threading.Mutex($false, 'Global\ZhouGeBot')
if (-not $mutex.WaitOne(0)) { exit 0 }

try {
  if (-not (Test-Path $node)) { Log 'DSH node missing'; exit 1 }

  # 没有正在进行的对话 → 周哥不启动。
  # 第一道：这个窗口内没有任何会话文件被写过，连分析器都不用起。
  # 窗口取 30 分钟：一次工具调用可能 20 分钟不写盘，窗口太短会把「正在回答」误判成「没人」。
  if (-not $Force) {
    $freshCut = (Get-Date).AddMinutes(-$IdleAfter)
    $fresh = @(Get-ChildItem -Path $SessionsRoot -Recurse -File -Filter 'session.*.jsonl.zstd' -ErrorAction SilentlyContinue |
               Where-Object { $_.LastWriteTime -gt $freshCut })
    if ($fresh.Count -eq 0) {
      Log ("skip: no session write in {0} min" -f $IdleAfter)
      exit 0
    }
  }

  $old = $env:ELECTRON_RUN_AS_NODE
  $env:ELECTRON_RUN_AS_NODE = '1'
  try {
    $startedAt = Get-Date
    $p = Start-Process -FilePath $node -ArgumentList @($analyzer, '--minutes=30', "--root=$SessionsRoot", "--out=$jsonFile") -Wait -PassThru -NoNewWindow
    $code = $null
    try { $code = $p.ExitCode } catch { $code = $null }
    # Electron 以 node 方式跑时 ExitCode 经常读不到（$null），这时只认产物：
    # 报错判定改成「拿到明确非 0 才算失败」+「报告必须是本次新写的」。
    if ($null -ne $code -and $code -ne 0) { Log "analyzer failed code=$code"; exit 1 }
    if (-not (Test-Path $jsonFile) -or (Get-Item $jsonFile).LastWriteTime -lt $startedAt.AddSeconds(-2)) {
      Log 'analyzer produced no fresh report'
      exit 1
    }
  } finally {
    if ($null -eq $old) { Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue }
    else { $env:ELECTRON_RUN_AS_NODE = $old }
  }

  if (-not (Test-Path $jsonFile)) { Log 'no report'; exit 1 }
  $data = Get-Content $jsonFile -Raw -Encoding UTF8 | ConvertFrom-Json

  # 第二道：有会话在动，但没有任何一个 turn 处于「开问了还没答完」的状态 → 同样不启动。
  # 分析器本来就只读 30 分钟窗口内的文件，所以这里不必再套一层时间窗。
  $inflight = @($data.sessions | Where-Object { $_.activeTurn })
  if (-not $Force -and $inflight.Count -eq 0) {
    Log ("skip: no conversation answering (sessions={0})" -f $data.activeSessions)
    exit 0
  }

  $alerts = @($data.alerts)
  if ($alerts.Count -eq 0) {
    Log 'no alerts'
    exit 0
  }

  # ── 记忆是「弹不弹」的第一道判断 ────────────────────────────────
  # 刘哥复核否定 + 用户手动确认（勾“同意”并点“确认关闭”）过的同类问题，
  # 下次再出现直接不提示；与是不是同一个会话无关，只认“同一个问题”。
  $memoryDir = Join-Path $root '..\memory'
  if (-not (Test-Path $memoryDir)) { $memoryDir = Join-Path $root 'memory' }
  $memoryFile = Join-Path $memoryDir 'zhou-memory.json'
  $memory = @{}
  if (Test-Path $memoryFile) {
    try {
      $m = Get-Content $memoryFile -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($m.entries) { $m.entries.PSObject.Properties | ForEach-Object { $memory[$_.Name] = $_.Value } }
    } catch { Log 'memory parse failed, ignore memory this round' }
  }
  $kept = @()
  $suppressed = @()
  foreach ($a in $alerts) {
    $key = [string]$a.key
    $pattern = ($key -split ':')[0]
    $issueKey = Get-IssueKey $key
    $mem = $memory[$issueKey]
    $hitBy = $issueKey
    if (-not $mem -and $key -ne $issueKey) { $mem = $memory[$key]; $hitBy = $key }
    if (-not $mem) { $mem = $memory[$pattern]; $hitBy = $pattern }
    if ($mem -and ($mem.agreed -eq $true) -and [int]$mem.count -gt 0) {
      Log ("memory suppress key={0} issue={1} hit={2} count={3} last={4}" -f $key, $issueKey, $hitBy, $mem.count, $mem.last)
      $suppressed += $a
      continue
    }
    $kept += $a
  }
  $alerts = $kept
  if ($suppressed.Count -gt 0) {
    # 周哥不再重复误报，但仍让刘哥做一次重复误报纠偏
    $liuScript = Find-LiuGe
    if ($liuScript) {
      Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', $liuScript, '-RepeatAudit') -WindowStyle Minimized
      Log ("trigger liu repeat audit suppressed={0} path={1}" -f $suppressed.Count, $liuScript)
    } else {
      Log 'liu-ge.ps1 not found (expected .\liu-ge.ps1 or ..\liu-ge\liu-ge.ps1): repeat audit skipped'
    }
  }
  if ($alerts.Count -eq 0) { Log 'all suppressed by memory'; exit 0 }

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

  # 刘哥只在周哥真正要弹窗时启动复核，不单独定时巡检
  $liuScript = Find-LiuGe
  if ($liuScript) {
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', $liuScript) -WindowStyle Minimized
    Log ("trigger liu-ge (zhou popup) path={0}" -f $liuScript)
  } else {
    Log 'liu-ge.ps1 not found (expected .\liu-ge.ps1 or ..\liu-ge\liu-ge.ps1): liu-ge review skipped'
  }

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
  Set-DshCardStyle $form ([System.Drawing.Color]::FromArgb(224, 74, 64))
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

  $script:zhouForm = $form
  [System.Windows.Forms.Application]::Run($form)
  $form.Dispose()
} finally {
  try { $mutex.ReleaseMutex() } catch {}
  $mutex.Dispose()
}
