param(
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$kb   = 'C:\Users\EDY\Downloads\ComfyUI相关'
$conv = 'C:\Users\EDY\Downloads\dsh-conversations'
$ws   = 'C:\Users\EDY\Downloads\dsh-workspace'
$logDir = Join-Path $kb 'sync\logs'
New-Item -ItemType Directory -Force $logDir | Out-Null
$log = Join-Path $logDir ("weekday-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$start = Get-Date
$status = 'OK'
$errText = ''
$code = 0
$before = @{}
$after = @{}

function Log([string]$msg) {
  $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $msg
  Write-Host $line
  Add-Content -Path $log -Value $line -Encoding utf8
}

function Run([string]$file, [string[]]$arguments) {
  Log "RUN $file $($arguments -join ' ')"
  & $file @arguments 2>&1 | ForEach-Object { Log $_ }
  if ($LASTEXITCODE -ne 0) { throw "command failed ($LASTEXITCODE): $file" }
}

function SyncRepo([string]$dir, [string]$message) {
  if (-not (Test-Path (Join-Path $dir '.git'))) {
    Log "SKIP no git repo: $dir"
    return
  }
  Run 'git' @('-C', $dir, 'add', '-A')
  & git -C $dir diff --cached --quiet
  if ($LASTEXITCODE -eq 0) {
    Log "OK no changes: $dir"
    return
  }
  Run 'git' @('-C', $dir, 'commit', '-m', $message)
  $pushed = $false
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
      Run 'git' @('-C', $dir, 'push')
      $pushed = $true
      break
    } catch {
      if ($attempt -eq 3) { throw }
      Log "WARN push failed (attempt $attempt/3): $($_.Exception.Message); retry in 20s"
      Start-Sleep -Seconds 20
    }
  }
  if ($pushed) { Log "OK pushed: $dir" }
}

function Get-Head([string]$dir) {
  if (-not (Test-Path (Join-Path $dir '.git'))) { return '' }
  $h = & git -C $dir rev-parse --short HEAD 2>$null
  if ($LASTEXITCODE -ne 0) { return '' }
  return ($h | Select-Object -First 1)
}

function Write-Report {
  try {
    $reportDir = Join-Path $kb 'sync\reports'
    New-Item -ItemType Directory -Force $reportDir | Out-Null
    $date = Get-Date -Format 'yyyy-MM-dd'
    $duration = [int]((Get-Date) - $start).TotalSeconds
    $lines = @(
      "# 张淑芬工作日日报 · $date",
      "",
      "- 状态：$status",
      "- 开始：$($start.ToString('yyyy-MM-dd HH:mm:ss'))",
      "- 耗时：${duration}s",
      "- 日志：``$log``",
      "",
      "## 仓库提交",
      "",
      "| 仓库 | 运行前 | 运行后 |",
      "|---|---|---|",
      "| 知识库 | $($before.kb) | $($after.kb) |",
      "| 对话 | $($before.conv) | $($after.conv) |",
      "| 工作区 | $($before.ws) | $($after.ws) |"
    )
    if ($errText) {
      $lines += @("", "## 错误", "", '```text', $errText, '```')
    }
    $text = $lines -join "`n"
    Set-Content -Path (Join-Path $reportDir "$date.md") -Value $text -Encoding utf8
    Set-Content -Path (Join-Path $reportDir 'latest.md') -Value $text -Encoding utf8
    Log "report: $(Join-Path $reportDir "$date.md")"
  } catch {
    Log "WARN report failed: $($_.Exception.Message)"
  }
}

try {
  Log "=== DSH weekday sync start ==="
  Log "KB=$kb"
  Log "CONV=$conv"
  Log "WS=$ws"
  $gitProxy = & git config --get http.proxy 2>$null
  Log "GIT_PROXY=$gitProxy"
  $status = 'OK'
  $before.kb = Get-Head $kb
  $before.conv = Get-Head $conv
  $before.ws = Get-Head $ws

  $ps = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
  if (-not $ps) { $ps = (Get-Command powershell -ErrorAction Stop).Source }
  Run $ps @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $kb 'site\build.ps1'))

  $node = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\DeepSeek Harness.exe'
  if (Test-Path $node) {
    Log "export conversations..."
    $old = $env:ELECTRON_RUN_AS_NODE
    $env:ELECTRON_RUN_AS_NODE = '1'
    try {
      $nodeArgs = @((Join-Path $kb 'tools\export-dsh-sessions.mjs'), '--out', (Join-Path $conv 'conversations'), '--tools')
      $p = Start-Process -FilePath $node -ArgumentList $nodeArgs -Wait -PassThru -NoNewWindow
      if ($p.ExitCode -ne 0) { throw "conversation export failed ($($p.ExitCode))" }
      Log "OK conversations exported"
    } finally {
      if ($null -eq $old) { Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue }
      else { $env:ELECTRON_RUN_AS_NODE = $old }
    }
  } else {
    Log "WARN DSH node not found; skip conversation export"
  }

  if ($DryRun) {
    Log "DRY RUN: skip git commit/push"
  } else {
    SyncRepo $kb 'chore: scheduled KB sync'
    SyncRepo $conv 'chore: scheduled conversation sync'
    SyncRepo $ws 'chore: scheduled workspace sync'
  }

  Log "=== DSH weekday sync done ==="
  $code = 0
} catch {
  $status = 'FAILED'
  $errText = $_.Exception.Message
  $code = 1
  Log "ERROR $errText"
} finally {
  $after.kb = Get-Head $kb
  $after.conv = Get-Head $conv
  $after.ws = Get-Head $ws
  Write-Report
}

exit $code

