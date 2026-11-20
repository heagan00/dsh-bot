param(
  [int]$IntervalMs = 400,
  [int]$MinLongChars = 100,
  [int]$StablePolls = 3
)

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force $logDir | Out-Null
$logFile = Join-Path $logDir 'pieter-input.log'
$promptFile = Join-Path $logDir 'pieter-input-last.txt'
$pieter = Join-Path $root 'pieter-huang.ps1'

function Log([string]$msg) {
  Add-Content -Path $logFile -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding utf8
}

# 与 pieter-huang.ps1 / prompt-watch.mjs 同口径：'h' + sha1(text)[0:12]
function Get-TextId([string]$text) {
  $sha = [System.Security.Cryptography.SHA1]::Create()
  try {
    $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(([string]$text).Trim()))
    $hex = -join @($hash | ForEach-Object { $_.ToString('x2') })
    return 'h' + $hex.Substring(0, 12)
  } finally {
    $sha.Dispose()
  }
}

$mutex = New-Object System.Threading.Mutex($false, 'Global\PieterInputWatch')
if (-not $mutex.WaitOne(0)) { exit 0 }

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$script:window = $null
$script:composer = $null

function Find-DshWindow {
  $rootEl = [System.Windows.Automation.AutomationElement]::RootElement
  $cond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window
  )
  $wins = $rootEl.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
  foreach ($w in $wins) {
    if ($w.Current.Name -like '*DeepSeek Harness*') { return $w }
  }
  return $null
}

function Find-Composer {
  if (-not $script:window) { $script:window = Find-DshWindow }
  if (-not $script:window) { return $null }
  try {
    $editCond = New-Object System.Windows.Automation.PropertyCondition(
      [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
      [System.Windows.Automation.ControlType]::Edit
    )
    $nameCond = New-Object System.Windows.Automation.PropertyCondition(
      [System.Windows.Automation.AutomationElement]::NameProperty,
      '发消息或创建任务, / 调用指令, @ 文件或对话'
    )
    $and = New-Object System.Windows.Automation.AndCondition($editCond, $nameCond)
    $e = $script:window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $and)
    if ($e) { return $e }
    $edits = $script:window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)
    foreach ($x in $edits) { if ($x.Current.Name -like '*发消息*') { return $x } }
  } catch {
    $script:window = $null
  }
  return $null
}

function Get-ComposerText {
  $script:composer = Find-Composer
  if (-not $script:composer) { return '' }
  try {
    $vp = $null
    if ($script:composer.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$vp)) {
      return [string]$vp.Current.Value
    }
  } catch {
    $script:composer = $null
  }
  return ''
}

# 文本走临时文件传给 pieter-huang.ps1，避免命令行引号/换行把长提示词截断
function Invoke-Pieter([string]$mode, [string]$text) {
  try {
    [System.IO.File]::WriteAllText($promptFile, $text, (New-Object System.Text.UTF8Encoding($false)))
  } catch {
    Log ("write prompt file failed: {0}" -f $_.Exception.Message)
  }
  Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass',
    '-File', $pieter, $mode, '-PromptFile', $promptFile
  ) -WindowStyle Minimized
}

Log ("input watcher started interval=$IntervalMs minLong=$MinLongChars stable=$StablePolls")
$armed = $true          # @阿皮 边沿触发
$pendingText = ''       # 正在观察的超长输入
$pendingTicks = 0       # 连续未变化的轮数（停顿判定）
$firedId = ''           # 已经为哪段超长输入弹过卡
$lastLogged = ''
$poll = 0

while ($true) {
  try {
    $text = Get-ComposerText
    $poll++
    if ($poll -le 5 -or $text -ne $lastLogged) {
      Log ("poll text len={0} preview={1}" -f $text.Length, ($text.Substring(0, [Math]::Min(40, $text.Length))))
      $lastLogged = $text
    }

    $clean = ($text -replace '@阿皮', '').Trim()

    if ($text -match '@阿皮') {
      # ① 点名 @阿皮：立即弹协同菜单，不等消息发出去
      if ($armed) {
        Invoke-Pieter '-ForceMention' $text
        Log 'input mention @阿皮 -> menu'
        $armed = $false
      }
      $pendingText = ''
      $pendingTicks = 0
    } else {
      $armed = $true
      # ② 超长提示词：打字停顿 StablePolls 个轮询周期后弹一次
      if ($clean.Length -ge $MinLongChars) {
        if ($clean -eq $pendingText) { $pendingTicks++ } else { $pendingText = $clean; $pendingTicks = 1 }
        if ($pendingTicks -ge $StablePolls) {
          $id = Get-TextId $clean
          if ($id -ne $firedId) {
            Invoke-Pieter '-LongPrompt' $text
            $firedId = $id
            Log ("long input len={0} id={1} -> card" -f $clean.Length, $id)
          }
        }
      } else {
        $pendingText = ''
        $pendingTicks = 0
        $firedId = ''
      }
    }
  } catch {
    Log ("watch error: {0}" -f $_.Exception.Message)
  }
  Start-Sleep -Milliseconds $IntervalMs
}
