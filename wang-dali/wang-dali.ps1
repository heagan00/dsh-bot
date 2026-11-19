param(
  [switch]$Test,
  [int]$TestCount = 1,
  [int]$TestSeconds = 6
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
. (Join-Path $root 'ui-theme.ps1')
$tipsFile = Join-Path $root 'wang-dali-tips.json'
$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force $logDir | Out-Null
$log = Join-Path $logDir 'wang-dali.log'
$stateFile = Join-Path $logDir 'wang-dali-state.json'
$tips = (Get-Content $tipsFile -Raw -Encoding UTF8 | ConvertFrom-Json).tips
$quotesFile = Join-Path $root 'wang-dali-quotes.json'
$quotes = @()
if (Test-Path $quotesFile) { $quotes = @((Get-Content $quotesFile -Raw -Encoding UTF8 | ConvertFrom-Json).quotes) }

$reflections = @(
  '很多压力不是因为事情本身有多大，而是你把“做完”和“做好”绑得太紧。先把今天这一小段做完，允许它不完美。人是在一次次可交付里恢复信心的，不是在脑子里把自己说服的。',
  '你现在需要的不是更用力，而是更具体。把问题拆成一个可以在二十分钟内推进的动作：写一行、改一处、问一句。动作会把你从反刍里带出来。',
  '别人看到的是结果，你经历的是全过程。不要拿自己的幕后，去比别人的高光。今天只和昨天的自己比一件事：有没有多推进一点，有没有少一点内耗。',
  '休息不是奖励，是工作的一部分。你恢复得越好，判断越稳，做得越久。到点就离开屏幕十分钟，走一走，喝口水，让眼睛看看远处。',
  '你不需要对所有人的情绪和所有项目的成败负责。先把属于你的那一段做好：明确目标，说清风险，给出方案，然后允许别人做他们的部分。边界不是冷漠，是长期在场。',
  '意义常常不是想出来的，是做出来的。你把一个需求拆清楚，把一段代码写稳，把一个画面改到能交付，这些动作本身就在回答“我有什么用”。',
  '如果今天很糟，先别给整个人生下结论。糟糕的一天只是一天。洗个澡，吃点东西，睡一觉；明天再用一个新的小时重新开始。',
  '你不是机器，不需要持续燃烧才叫努力。能稳定地重复，才是更长久的力量。今天做完一件具体的事，然后承认它有意义。'
)

function Get-State {
  $s = [pscustomobject]@{ lastShown = ''; recentQuotes = @() }
  if (Test-Path $stateFile) {
    try {
      $old = Get-Content $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($old.lastShown) { $s.lastShown = $old.lastShown }
      if ($old.recentQuotes) { $s.recentQuotes = @($old.recentQuotes) }
    } catch {}
  }
  return $s
}

function Set-State($s) {
  $s | ConvertTo-Json -Depth 4 | Set-Content $stateFile -Encoding utf8
}

function Get-LastShown {
  $s = Get-State
  if ($s.lastShown) { return [DateTime]::Parse($s.lastShown) }
  return $null
}

function Log([string]$msg) {
  Add-Content -Path $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding utf8
}

function Start-Ambient {
  $music = @('music1', 'music2', 'music3')
  $nature = @('rain', 'waves', 'stream', 'birds')
  if ((Get-Random -Minimum 0 -Maximum 100) -lt 55) {
    $kind = $music | Get-Random
  } else {
    $kind = $nature | Get-Random
  }
  $path = Join-Path $root ("audio\{0}.wav" -f $kind)
  if (-not (Test-Path $path)) { return }
  Add-Type -AssemblyName PresentationCore
  Stop-Ambient
  $p = New-Object System.Windows.Media.MediaPlayer
  $p.Volume = if ($kind -like 'music*') { 0.20 } else { 0.13 }
  $p.Open([Uri]$path)
  $p.Play()
  $script:ambientPlayer = $p
  $p.Add_MediaOpened({
    try { $p.Position = [TimeSpan]::FromSeconds((Get-Random -Minimum 0 -Maximum 20)) } catch {}
  })
  $p.Add_MediaEnded({
    try {
      $script:ambientPlayer.Position = [TimeSpan]::Zero
      $script:ambientPlayer.Play()
    } catch {}
  })
  Log ("ambient {0}" -f $kind)
}

function Stop-Ambient {
  if ($script:ambientPlayer) {
    try { $script:ambientPlayer.Stop(); $script:ambientPlayer.Close() } catch {}
    $script:ambientPlayer = $null
  }
}

function Show-Tip {
  $state = Get-State
  $quote = $null
  $tip = ''
  $quoteLabel = ''

  if ($quotes.Count -gt 0) {
    $recent = @($state.recentQuotes)
    $candidates = @($quotes | Where-Object { $recent -notcontains $_.id })
    if ($candidates.Count -eq 0) { $candidates = @($quotes); $recent = @() }
    $quote = $candidates | Get-Random
    $recent = @(@($recent) + $quote.id | Select-Object -Last 12)
    $state.recentQuotes = $recent
    $quoteLabel = $quote.id
    $original = [string]$quote.original
    $zh = [string]$quote.zh
    $source = [string]$quote.source
    $tip = $original
    if ($zh -and $zh -ne $original) { $tip += "`r`n`r`n【中文】`r`n" + $zh }
    $tip += "`r`n`r`n—— " + $source
    $reflection = $reflections | Get-Random
    $tip += "`r`n`r`n" + $reflection
  } else {
    $idx = Get-Random -Minimum 0 -Maximum $tips.Count
    $quoteLabel = "tip-$($idx + 1)"
    $tip = $tips[$idx]
  }

  $shownAt = Get-Date
  $state.lastShown = $shownAt.ToString('o')
  Set-State $state
  $text = "王大力 · " + (Get-Date -Format 'HH:mm') + "`r`n`r`n" + $tip + "`r`n`r`n—— 王大力"

  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  Add-Type -AssemblyName PresentationCore
  # 提前初始化 WPF，避免点击“朗读”时才初始化导致窗口被 DPI/焦点重排
  $null = New-Object System.Windows.Media.MediaPlayer

  $form = New-Object System.Windows.Forms.Form
  $form.Text = '王大力 · 心理抚慰师'
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
  $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
  $form.TopMost = $true
  $form.ShowInTaskbar = $false
  $form.BackColor = [System.Drawing.Color]::FromArgb(28, 24, 20)
  $form.Width = 460
  $form.Height = 380
  Set-DshCardStyle $form ([System.Drawing.Color]::FromArgb(110, 160, 220))
  $screen = [System.Windows.Forms.Screen]::PrimaryScreen
  $wa = $screen.WorkingArea
  $form.Left = $wa.Left + 24
  $form.Top = $wa.Bottom - $form.Height - 24
  $script:wangFixedLeft = $form.Left
  $script:wangFixedTop = $form.Top
  $form.Add_Move({
    if ($null -ne $script:wangFixedLeft -and ($form.Left -ne $script:wangFixedLeft -or $form.Top -ne $script:wangFixedTop)) {
      $form.Left = $script:wangFixedLeft
      $form.Top = $script:wangFixedTop
    }
  })
  Log ("screen={0} bounds={1}" -f $screen.DeviceName, $screen.Bounds)

  $accent = New-Object System.Windows.Forms.Panel
  $accent.Dock = [System.Windows.Forms.DockStyle]::Left
  $accent.Width = 5
  $accent.BackColor = [System.Drawing.Color]::FromArgb(224, 138, 74)
  $form.Controls.Add($accent)

  $title = New-Object System.Windows.Forms.Label
  $title.Text = '王大力 · 心理抚慰师'
  $title.Font = New-Object System.Drawing.Font('Microsoft YaHei', 11, [System.Drawing.FontStyle]::Bold)
  $title.ForeColor = [System.Drawing.Color]::FromArgb(245, 230, 210)
  $title.Left = 22; $title.Top = 14; $title.Width = 290; $title.Height = 24
  $form.Controls.Add($title)

  $speak = New-Object System.Windows.Forms.Button
  $speak.Text = '朗读'
  $speak.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $speak.FlatAppearance.BorderSize = 1
  $speak.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(120, 90, 65)
  $speak.ForeColor = [System.Drawing.Color]::FromArgb(245, 210, 170)
  $speak.BackColor = [System.Drawing.Color]::FromArgb(52, 42, 34)
  $speak.Font = New-Object System.Drawing.Font('Microsoft YaHei', 9)
  $speak.Left = 320; $speak.Top = 10; $speak.Width = 104; $speak.Height = 26
  $form.Controls.Add($speak)

  $close = New-Object System.Windows.Forms.Button
  $close.Text = '×'
  $close.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $close.FlatAppearance.BorderSize = 0
  $close.ForeColor = [System.Drawing.Color]::FromArgb(180, 160, 140)
  $close.BackColor = $form.BackColor
  $close.Font = New-Object System.Drawing.Font('Microsoft YaHei', 14)
  $close.Left = 428; $close.Top = 8; $close.Width = 28; $close.Height = 28
  $close.Add_Click({ $form.Close() })
  $form.Controls.Add($close)

  $box = New-Object System.Windows.Forms.RichTextBox
  $box.Text = $text
  $box.ReadOnly = $true
  $box.BorderStyle = [System.Windows.Forms.BorderStyle]::None
  $box.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
  $box.BackColor = $form.BackColor
  $box.ForeColor = [System.Drawing.Color]::FromArgb(236, 224, 208)
  $box.Font = New-Object System.Drawing.Font('Microsoft YaHei', 10.5)
  $box.Left = 18; $box.Top = 52; $box.Width = 424; $box.Height = 306
  $form.Controls.Add($box)

  $timer = $null
  if ($Test) {
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = [Math]::Max(3, $TestSeconds) * 1000
    $timer.Add_Tick({ $form.Close() })
  }

  $voiceFile = ''
  if ($quote) {
    if ($quote.audio) {
      $candidate = [string]$quote.audio
      if (-not [System.IO.Path]::IsPathRooted($candidate)) { $candidate = Join-Path $root $candidate }
      if (Test-Path $candidate) { $voiceFile = $candidate }
    }
  } else {
    $voiceFile = Join-Path $root ("voice\tip-{0:D2}.mp3" -f ($idx + 1))
  }
  $script:voicePlayer = $null
  $script:voiceButton = $speak
  $script:formTimer = $timer
  $voiceTimer = New-Object System.Windows.Forms.Timer
  $voiceTimer.Interval = 500
  $script:voiceTimer = $voiceTimer
  $voiceTimer.Add_Tick({
    if ($script:voicePlayer) {
      $dur = $script:voicePlayer.NaturalDuration
      if ($dur.HasTimeSpan -and $script:voicePlayer.Position -ge $dur.TimeSpan) {
        try { $script:voicePlayer.Stop(); $script:voicePlayer.Close() } catch {}
        $script:voicePlayer = $null
        Stop-Ambient
        $script:voiceButton.Text = '朗读'
        if ($script:formTimer) {
          $script:formTimer.Interval = 30000
          $script:formTimer.Start()
        }
        $script:voiceTimer.Stop()
      }
    }
  })

  Add-Type -AssemblyName System.Speech
  $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
  try {
    $voice = $synth.GetInstalledVoices() |
      Where-Object { $_.Enabled -and $_.VoiceInfo.Gender -eq 'Female' -and $_.VoiceInfo.Culture.Name -like 'zh-*' } |
      Select-Object -First 1
    if (-not $voice) {
      $voice = $synth.GetInstalledVoices() | Where-Object { $_.Enabled -and $_.VoiceInfo.Gender -eq 'Female' } | Select-Object -First 1
    }
    if ($voice) { $synth.SelectVoice($voice.VoiceInfo.Name) }
    $synth.Rate = -2
    $synth.Volume = 90
  } catch { }

  $speak.Add_Click({
    try {
      if ($script:voicePlayer) {
        $script:voicePlayer.Stop()
        $script:voicePlayer.Close()
        $script:voicePlayer = $null
        Stop-Ambient
        $script:voiceTimer.Stop()
        $speak.Text = '朗读'
        return
      }

      if (Test-Path $voiceFile) {
        Add-Type -AssemblyName PresentationCore
        $p = New-Object System.Windows.Media.MediaPlayer
        $p.Volume = 0.9
        $p.Open([Uri]$voiceFile)
        $p.Play()
        $script:voicePlayer = $p
        Start-Ambient
        $speak.Text = '停止'
        $script:voiceTimer.Start()
        return
      }

      if ($synth.State -eq [System.Speech.Synthesis.SynthesizerState]::Speaking) {
        $synth.SpeakAsyncCancelAll()
        Stop-Ambient
        $speak.Text = '朗读'
        return
      }
      Start-Ambient
      $synth.SpeakAsync($tip)
      $speak.Text = '停止'
    } catch {
      $speak.Text = '语音不可用'
    }
  })
  $synth.Add_SpeakCompleted({
    $speak.Text = '朗读'
    Stop-Ambient
    if ($script:formTimer) {
      $script:formTimer.Interval = 30000
      $script:formTimer.Start()
    }
  })

  $form.Add_Shown({
    Log ("shown at {0} visible={1} topmost={2}" -f $form.Bounds, $form.Visible, $form.TopMost)
    if ($timer) { $timer.Start() }
  })
  $form.Add_FormClosed({
    if ($timer) { $timer.Stop() }
    $voiceTimer.Stop()
    if ($script:voicePlayer) {
      try { $script:voicePlayer.Stop(); $script:voicePlayer.Close() } catch {}
      $script:voicePlayer = $null
    }
    Stop-Ambient
    try { $synth.SpeakAsyncCancelAll() } catch {}
    try { $synth.Dispose() } catch {}
    if ($timer) { $timer.Dispose() }
    $voiceTimer.Dispose()
  })

  Log ("show quote/source #{0}" -f $quoteLabel)
  try {
    [System.Windows.Forms.Application]::Run($form)
  } catch {
    Log ("form error: {0}" -f $_.Exception.Message)
  }
  $form.Dispose()
}

$mutex = New-Object System.Threading.Mutex($false, 'Global\WangDaliBot')
if (-not $mutex.WaitOne(0)) {
  Log 'another instance is running; exit'
  exit 0
}

try {
  if ($Test) {
    for ($i = 0; $i -lt [Math]::Max(1, $TestCount); $i++) {
      Show-Tip
      Start-Sleep -Seconds 1
    }
    exit 0
  }

  $end = (Get-Date).Date.AddDays(1)
  $last = Get-LastShown
  if ($last) {
    $elapsed = ((Get-Date) - $last).TotalSeconds
    if ($elapsed -lt 1800) {
      $wait = [int](1800 - $elapsed)
      Log ("recent tip {0}s ago; wait {1}s before first" -f [int]$elapsed, $wait)
      Start-Sleep -Seconds $wait
    }
  }

  Log 'started'
  while ((Get-Date) -lt $end) {
    $now = Get-Date
    if ($now.Hour -lt 9) { Start-Sleep -Seconds 60; continue }
    $shownAt = Get-Date
    Show-Tip
    $next = $shownAt.AddSeconds((Get-Random -Minimum 1800 -Maximum 2701))
    $sleep = [int](($next - (Get-Date)).TotalSeconds)
    if ($sleep -lt 1) { $sleep = 1 }
    Log ("next in {0}s (start-to-start)" -f $sleep)
    Start-Sleep -Seconds $sleep
  }
  Log 'ended'
} finally {
  try { $mutex.ReleaseMutex() } catch {}
  $mutex.Dispose()
}
