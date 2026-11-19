param(
  [int]$IntervalMs = 400
)

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force $logDir | Out-Null
$logFile = Join-Path $logDir 'pieter-input.log'
$pieter = Join-Path $root 'pieter-huang.ps1'

function Log([string]$msg) {
  Add-Content -Path $logFile -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding utf8
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

Log "input watcher started interval=$IntervalMs"
$armed = $true
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
    if ($text -match '@阿皮') {
      if ($armed) {
        $quoted = '"' + ($text -replace '"', '\"') + '"'
        Start-Process -FilePath 'powershell.exe' -ArgumentList @(
          '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass',
          '-File', $pieter, '-ForceMention', '-Prompt', $quoted
        ) -WindowStyle Minimized
        Log 'input mention @阿皮 -> menu'
        $armed = $false
      }
    } else {
      $armed = $true
    }
  } catch {
    Log ("watch error: {0}" -f $_.Exception.Message)
  }
  Start-Sleep -Milliseconds $IntervalMs
}
