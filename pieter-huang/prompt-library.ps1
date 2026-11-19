$ErrorActionPreference = 'Stop'
$node = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\DeepSeek Harness.exe'
$script = Join-Path $PSScriptRoot '..\tools\prompt-library.mjs'
$logDir = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Force $logDir | Out-Null
$old = $env:ELECTRON_RUN_AS_NODE
$env:ELECTRON_RUN_AS_NODE = '1'
try {
  $p = Start-Process -FilePath $node -ArgumentList @($script) -Wait -PassThru -NoNewWindow
  Add-Content (Join-Path $logDir 'prompt-library.log') ("[{0}] exit={1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $p.ExitCode) -Encoding utf8
  exit $p.ExitCode
} finally {
  if ($null -eq $old) { Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue } else { $env:ELECTRON_RUN_AS_NODE = $old }
}
