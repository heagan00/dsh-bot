param(
  [string]$Text = '',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$node = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\DeepSeek Harness.exe'
$script = Join-Path $PSScriptRoot '..\tools\prompt-guess.mjs'

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ImeCheck {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll")] public static extern IntPtr GetKeyboardLayout(uint idThread);
}
'@

$hwnd = [ImeCheck]::GetForegroundWindow()
$procId = 0
$tid = [ImeCheck]::GetWindowThreadProcessId($hwnd, [ref]$procId)
$layout = [ImeCheck]::GetKeyboardLayout($tid)
$lang = ([int64]$layout) -band 0xFFFF
$primary = $lang -band 0x3FF
$english = ($primary -eq 0x09)

if (-not $Force -and -not $english) {
  Write-Host ("当前输入法语言=0x{0:X4}，不是英文输入法；高频词猜想已跳过。" -f $lang)
  exit 0
}

$old = $env:ELECTRON_RUN_AS_NODE
$env:ELECTRON_RUN_AS_NODE = '1'
try {
  $args = @('--ime=en')
  if ($Text) { $args += ("--text=" + $Text) }
  $p = Start-Process -FilePath $node -ArgumentList (@($script) + $args) -Wait -PassThru -NoNewWindow
  exit $p.ExitCode
} finally {
  if ($null -eq $old) { Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue } else { $env:ELECTRON_RUN_AS_NODE = $old }
}
