param(
  [switch]$Apply
)

$ErrorActionPreference = 'Continue'
$kb = 'C:\Users\EDY\Downloads\ComfyUI相关'
$botRoot = Join-Path $kb 'sync'
$logDir = Join-Path $botRoot 'logs'
$reportDir = Join-Path $botRoot 'reports'
$logFile = Join-Path $logDir 'li-shen.log'
New-Item -ItemType Directory -Force $logDir, $reportDir | Out-Null

$now = Get-Date
$cutLog = $now.AddDays(-14)
$cutReport = $now.AddDays(-30)
$cutTemp = $now.AddDays(-7)
$cutPng = $now.AddDays(-1)
$deleted = New-Object System.Collections.Generic.List[object]
$freed = 0L

function Log([string]$msg) {
  Add-Content -Path $logFile -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding utf8
}

function Clean-File([System.IO.FileInfo]$file, [datetime]$cut, [string]$why) {
  if (-not $file.Exists) { return }
  if ($file.LastWriteTime -ge $cut) { return }
  try {
    $size = $file.Length
    if ($Apply) { Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop }
    $script:freed += $size
    $script:deleted.Add([pscustomobject]@{ path = $file.FullName; bytes = $size; reason = $why; time = $file.LastWriteTime })
    Log ("{0} {1} ({2} bytes, {3})" -f ($(if ($Apply) { 'DELETE' } else { 'DRYRUN' })), $file.FullName, $size, $why)
  } catch {
    Log ("SKIP {0}: {1}" -f $file.FullName, $_.Exception.Message)
  }
}

# 1) 旧日志（保留当前 li-shen.log 和 wang-dali-state.json）
Get-ChildItem $logDir -File -Filter '*.log' -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -ne 'li-shen.log' -and $_.Name -notlike 'wang-dali-state*' } |
  ForEach-Object { Clean-File $_ $cutLog 'log >14d' }

# 2) 旧日报（保留 latest / icreat-latest）
Get-ChildItem $reportDir -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -notin @('latest.md', 'icreat-latest.json', 'icreat-latest.txt') } |
  ForEach-Object { Clean-File $_ $cutReport 'report >30d' }

# 3) 临时/备份文件
Get-ChildItem $botRoot -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Extension -in @('.tmp', '.bak', '.old') } |
  ForEach-Object { Clean-File $_ $cutTemp 'temp >7d' }

# 4) 调试截图
Get-ChildItem $botRoot -File -Filter '*.png' -ErrorAction SilentlyContinue |
  ForEach-Object { Clean-File $_ $cutPng 'debug png >1d' }

# 5) iCreat 调试缓存（不碰 token/session/chrome-profile）
$icreat = Join-Path $env:USERPROFILE '.icreat'
foreach ($name in @('network.json')) {
  $f = Get-Item (Join-Path $icreat $name) -ErrorAction SilentlyContinue
  if ($f) { Clean-File $f $cutPng 'icreat debug >1d' }
}
$probe = Join-Path $env:USERPROFILE 'Downloads\icreat-probe'
if (Test-Path $probe) {
  Get-ChildItem $probe -Recurse -File -ErrorAction SilentlyContinue |
    ForEach-Object { Clean-File $_ $cutPng 'icreat probe >1d' }
}

$mode = if ($Apply) { 'APPLY' } else { 'DRYRUN' }
$lines = @(
  "# 李婶 · BOT 缓存清理报告",
  "",
  "- 模式：$mode",
  "- 时间：$($now.ToString('yyyy-MM-dd HH:mm:ss'))",
  "- 删除文件：$($deleted.Count)",
  "- 释放空间：$([math]::Round($freed / 1MB, 2)) MB",
  "",
  "## 明细",
  ""
)
if ($deleted.Count -eq 0) {
  $lines += "本次没有超过阈值的缓存。"
} else {
  $lines += "| 文件 | 大小 KB | 原因 | 修改时间 |"
  $lines += "|---|---:|---|---|"
  foreach ($d in $deleted) {
    $lines += ("| {0} | {1:N1} | {2} | {3} |" -f $d.path, ($d.bytes / 1KB), $d.reason, $d.time)
  }
}
$lines += @("", "## 保护清单", "", "`sync/audio`、`sync/voice`、`latest.md`、`icreat-latest.*`、`wang-dali-state.json`、`~/.icreat/token.txt`、`session.txt`、`chrome-profile` 不清理。")
$text = $lines -join "`n"
Set-Content (Join-Path $reportDir 'li-shen-latest.md') $text -Encoding utf8
Set-Content (Join-Path $reportDir ("li-shen-{0}.md" -f $now.ToString('yyyy-MM-dd'))) $text -Encoding utf8
Log ("done mode={0} deleted={1} freed={2}MB" -f $mode, $deleted.Count, [math]::Round($freed/1MB, 2))
Write-Host ("{0}: deleted {1}, freed {2} MB" -f $mode, $deleted.Count, [math]::Round($freed/1MB, 2))
