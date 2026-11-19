param(
  [switch]$Test
)

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
$node = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\DeepSeek Harness.exe'
$watchScript = Join-Path $root '..\tools\prompt-watch.mjs'
$reportDir = Join-Path $root 'reports'
$logDir = Join-Path $root 'logs'
$watchJson = Join-Path $reportDir 'pieter-watch.json'
$logFile = Join-Path $logDir 'pieter-huang.log'
$stateFile = Join-Path $logDir 'pieter-huang-state.json'
$wildRoot = Join-Path $root '..\prompt-library\wildcards'
New-Item -ItemType Directory -Force $reportDir, $logDir | Out-Null

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
    if ($null -eq $old) { Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue } else { $env:ELECTRON_RUN_AS_NODE = $old }
  }
}

function Clean-Prompt([string]$text) {
  $t = $text -replace '@阿皮', '' -replace '\s+', ' '
  if ($t.Length -gt 1200) { $t = $t.Substring(0, 1200) + '…' }
  return $t.Trim()
}

function Expand-Wildcards([string]$text) {
  for ($i = 0; $i -lt 8; $i++) {
    $before = $text
    $text = [regex]::Replace($text, '__([A-Za-z0-9_\-/]+)__', {
      param($m)
      $name = $m.Groups[1].Value
      $file = Join-Path $wildRoot ($name + '.txt')
      if (-not (Test-Path $file)) { return $m.Value }
      $lines = @(Get-Content $file -Encoding utf8 | Where-Object { $_.Trim() })
      if ($lines.Count -eq 0) { return $m.Value }
      return ($lines | Get-Random)
    })
    $text = [regex]::Replace($text, '\{([^{}]+)\}', {
      param($m)
      $opts = @($m.Groups[1].Value -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
      if ($opts.Count -eq 0) { return $m.Value }
      return ($opts | Get-Random)
    })
    if ($text -eq $before) { break }
  }
  return $text
}

function Show-Card([string]$title, [string]$body, [string[]]$buttons) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $form = New-Object System.Windows.Forms.Form
  $form.Text = $title
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
  $form.TopMost = $true
  $form.ShowInTaskbar = $false
  $form.Width = 640
  $form.Height = 470
  $form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 28)
  $screen = [System.Windows.Forms.Screen]::PrimaryScreen
  $wa = $screen.WorkingArea
  $form.Left = $wa.Left + 24
  $form.Top = $wa.Bottom - $form.Height - 24
  $script:pieterForm = $form

  $accent = New-Object System.Windows.Forms.Panel
  $accent.Dock = [System.Windows.Forms.DockStyle]::Top
  $accent.Height = 5
  $accent.BackColor = [System.Drawing.Color]::FromArgb(190, 150, 90)
  $form.Controls.Add($accent)

  $label = New-Object System.Windows.Forms.Label
  $label.Text = $title
  $label.Font = New-Object System.Drawing.Font('Microsoft YaHei', 13, [System.Drawing.FontStyle]::Bold)
  $label.ForeColor = [System.Drawing.Color]::FromArgb(245, 225, 190)
  $label.Left = 20; $label.Top = 16; $label.Width = 560; $label.Height = 28
  $form.Controls.Add($label)

  $close = New-Object System.Windows.Forms.Button
  $close.Text = '×'
  $close.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $close.FlatAppearance.BorderSize = 0
  $close.ForeColor = [System.Drawing.Color]::FromArgb(185, 170, 150)
  $close.BackColor = $form.BackColor
  $close.Font = New-Object System.Drawing.Font('Microsoft YaHei', 14)
  $close.Left = 600; $close.Top = 10; $close.Width = 30; $close.Height = 30
  $close.Add_Click({ $script:pieterChoice = '关闭'; $script:pieterForm.Close() })
  $form.Controls.Add($close)

  $box = New-Object System.Windows.Forms.RichTextBox
  $box.Text = $body
  $box.ReadOnly = $true
  $box.BorderStyle = [System.Windows.Forms.BorderStyle]::None
  $box.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
  $box.BackColor = $form.BackColor
  $box.ForeColor = [System.Drawing.Color]::FromArgb(225, 225, 230)
  $box.Font = New-Object System.Drawing.Font('Microsoft YaHei', 10.5)
  $box.Left = 20; $box.Top = 54; $box.Width = 600; $box.Height = 320
  $form.Controls.Add($box)

  $x = 20
  foreach ($b in $buttons) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $b
    $btnWidth = [Math]::Max(100, 28 + ([int]$b.Length * 16))
    $btn.Left = $x; $btn.Top = 390; $btn.Width = $btnWidth; $btn.Height = 34
    $btn.UseVisualStyleBackColor = $false
    $btn.BackColor = if ($b -in @('要', '优化提示词', '换一组')) { [System.Drawing.Color]::FromArgb(190, 150, 90) } else { [System.Drawing.Color]::FromArgb(58, 58, 66) }
    $btn.ForeColor = if ($b -in @('要', '优化提示词', '换一组')) { [System.Drawing.Color]::FromArgb(30, 22, 12) } else { [System.Drawing.Color]::FromArgb(235, 235, 240) }
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $btn.Font = New-Object System.Drawing.Font('Microsoft YaHei', 9.5)
    $btn.Tag = $b
    $btn.Add_Click({ $script:pieterChoice = $this.Tag; $script:pieterForm.Close() })
    $form.Controls.Add($btn)
    $x += $btnWidth + 8
  }

  $script:pieterChoice = '关闭'
  [System.Windows.Forms.Application]::Run($form)
  $form.Dispose()
  return $script:pieterChoice
}

function Show-Optimize([string]$prompt) {
  $clean = Clean-Prompt $prompt
  $body = @(
    '【目标】把原始需求收敛成可执行、可验收的提示词。',
    '',
    '【主体】' + $clean,
    '',
    '【风格】明确写实/卡通/二次元/风格化，不要混用。',
    '【构图】景别、视角、主体位置、留白。',
    '【光线】主光方向、色温、对比。',
    '【质量】分辨率、细节、材质、边缘。',
    '【负面】文字、水印、畸形、低对比、错误结构。',
    '',
    '—— 皮特·黄：先删冗余，再补结构；一句只做一件事。'
  ) -join "`r`n"
  Show-Card '皮特·黄 · 优化提示词' $body @('复制', '关闭') | Out-Null
}

function Show-Amei([string]$prompt) {
  $template = @(
    '主体：' + (Clean-Prompt $prompt),
    '风格：__style__',
    '气质：__mood__',
    '光线：__lighting__',
    '色板：__palette__',
    '镜头：__camera__',
    '材质：__material__',
    '笔触：__artist__'
  ) -join "`r`n"
  $v1 = Expand-Wildcards $template
  $v2 = Expand-Wildcards $template
  $v3 = Expand-Wildcards $template
  $body = "阿美 · 美术提示词（每次换一组都会重新随机）`r`n`r`n【方案 A】`r`n$v1`r`n`r`n【方案 B】`r`n$v2`r`n`r`n【方案 C】`r`n$v3"
  $r = Show-Card '阿美 · 美术提示词' $body @('换一组', '复制', '关闭')
  if ($r -eq '换一组') { Show-Amei $prompt }
}

function Show-Awei([string]$prompt) {
  $body = @(
    '【镜头】' + (Clean-Prompt $prompt),
    '【主体动作】谁，做什么，动作起点/终点。',
    '【运镜】推/拉/摇/移/跟，速度。',
    '【光线】时间、色温、气氛。',
    '【时长】5s/10s，24fps。',
    '【音频】对白/SFX/音乐，是否原生。',
    '【负面】闪烁、变形、文字、跳帧。',
    '',
    '—— 阿威：先写镜头，再写动作，最后写声音。'
  ) -join "`r`n"
  $r = Show-Card '阿威 · 视频提示词' $body @('复制', '关闭')
}

function Show-Atu([string]$prompt) {
  $body = @(
    '【目标】' + (Clean-Prompt $prompt),
    '【技术栈】语言/框架/版本。',
    '【输入】文件、接口、数据结构。',
    '【约束】不能改什么，性能/兼容要求。',
    '【验收】可运行的命令 + 预期输出。',
    '【测试】最小复现/单测。',
    '',
    '—— 阿秃：先定验收，再写代码；不要先写一堆抽象。'
  ) -join "`r`n"
  $r = Show-Card '阿秃 · 代码提示词' $body @('复制', '关闭')
}

if ($Test) {
  Show-Card '皮特·黄 · 测试' '官家，需要秉笔太监皮特·黄为您整理提示词吗？' @('要', '否', '30分钟内不再出现') | Out-Null
  exit 0
}

# 读取最近的长提示词
$code = Run-Node $watchScript @("--out=$watchJson")
if ($code -ne 0 -or -not (Test-Path $watchJson)) { Log 'watch failed'; exit 1 }
$data = Get-Content $watchJson -Raw -Encoding UTF8 | ConvertFrom-Json
$alerts = @($data.alerts)
if ($alerts.Count -eq 0) { exit 0 }

# 状态：已处理 / 30 分钟静音
$state = @{ processed = @{}; mute = @{} }
if (Test-Path $stateFile) {
  try {
    $s = Get-Content $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($s.processed) { $s.processed.PSObject.Properties | ForEach-Object { $state.processed[$_.Name] = $true } }
    if ($s.mute) { $s.mute.PSObject.Properties | ForEach-Object { $state.mute[$_.Name] = [long]$_.Value } }
  } catch {}
}
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

$alert = $null
foreach ($a in $alerts) {
  if ($state.processed.ContainsKey($a.id)) { continue }
  if ($state.mute.ContainsKey($a.sessionId) -and $state.mute[$a.sessionId] -gt $now) { continue }
  $alert = $a; break
}
if (-not $alert) { exit 0 }
$state.processed[$alert.id] = $true
$state | ConvertTo-Json -Depth 5 | Set-Content $stateFile -Encoding utf8

if ($alert.mention) {
  $choice = Show-Card '皮特·黄 · 传唤' ('官家，@阿皮 已候旨。要传哪位？' + "`r`n`r`n原文：" + (Clean-Prompt $alert.text)) @('优化提示词', '阿美', '阿威', '阿秃', '取消')
  switch ($choice) {
    '优化提示词' { Show-Optimize $alert.text }
    '阿美' { Show-Amei $alert.text }
    '阿威' { Show-Awei $alert.text }
    '阿秃' { Show-Atu $alert.text }
  }
} else {
  $choice = Show-Card '皮特·黄 · 秉笔太监' ('官家，需要秉笔太监皮特·黄为您整理提示词吗？' + "`r`n`r`n原文：" + (Clean-Prompt $alert.text)) @('要', '否', '30分钟内不再出现')
  if ($choice -eq '要') { Show-Optimize $alert.text }
  if ($choice -eq '30分钟内不再出现') {
    $state.mute[$alert.sessionId] = $now + 1800
    $state | ConvertTo-Json -Depth 5 | Set-Content $stateFile -Encoding utf8
  }
}
