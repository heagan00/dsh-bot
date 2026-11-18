param(
  [switch]$Apply
)

$ErrorActionPreference = 'Continue'
$kb = 'C:\Users\EDY\Downloads\ComfyUI相关'
$botRoot = Join-Path $kb 'sync'
$logDir = Join-Path $botRoot 'logs'
$reportDir = Join-Path $botRoot 'reports'
$logFile = Join-Path $logDir 'li-shen.log'
$backupRoot = Join-Path $kb 'backups'
$botBackupDir = Join-Path $backupRoot 'bots'
$skillBackupDir = Join-Path $backupRoot 'skills'
$pluginBackupDir = Join-Path $backupRoot 'plugins'
New-Item -ItemType Directory -Force $logDir, $reportDir, $botBackupDir, $skillBackupDir, $pluginBackupDir | Out-Null

$now = Get-Date
$cutLog = $now.AddDays(-14)
$cutReport = $now.AddDays(-30)
$cutTemp = $now.AddDays(-7)
$cutPng = $now.AddDays(-1)
$deleted = New-Object System.Collections.Generic.List[object]
$backups = New-Object System.Collections.Generic.List[object]
$freed = 0L

function Log([string]$msg) {
  Add-Content -Path $logFile -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) -Encoding utf8
}

function Make-Zip($files, [string]$dest, [string]$label) {
  if (-not $files -or @($files).Count -eq 0) {
    Log ("BACKUP SKIP {0}: no files" -f $label)
    return
  }
  if (-not $Apply) {
    Log ("DRYRUN BACKUP {0} -> {1} ({2} files)" -f $label, $dest, @($files).Count)
    $script:backups.Add([pscustomobject]@{ label = $label; path = $dest; files = @($files).Count; mode = 'DRYRUN' })
    return
  }
  try {
    $paths = @($files | ForEach-Object { if ($_ -is [System.IO.FileInfo]) { $_.FullName } else { [string]$_ } })
    Compress-Archive -Path $paths -DestinationPath $dest -Force -ErrorAction Stop
    $size = (Get-Item $dest).Length
    Log ("BACKUP {0} -> {1} ({2} files, {3:N1} KB)" -f $label, $dest, @($files).Count, ($size / 1KB))
    $script:backups.Add([pscustomobject]@{ label = $label; path = $dest; files = @($files).Count; mode = 'OK'; bytes = $size })
  } catch {
    Log ("BACKUP FAIL {0}: {1}" -f $label, $_.Exception.Message)
  }
}

function Backup-Bots {
  $files = Get-ChildItem $botRoot -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in @('.ps1', '.cmd', '.md', '.json') -and $_.Name -ne 'repair-push.ps1' }
  $dest = Join-Path $botBackupDir 'bots-weekly.zip'
  Make-Zip $files $dest 'bots（保留 1 份滚动版本）'
  if ($Apply) {
    Get-ChildItem $botBackupDir -File -Filter 'bots-*.zip' -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -ne $dest } |
      Remove-Item -Force -ErrorAction SilentlyContinue
  }
}

function Backup-Skills {
  $roots = @(
    (Join-Path $env:USERPROFILE '.dsh\skills'),
    (Join-Path $botRoot 'skills'),
    (Join-Path $kb '.dsh\skills'),
    (Join-Path $kb 'skills')
  ) | Where-Object { Test-Path $_ }
  $files = @()
  foreach ($r in $roots) {
    $files += Get-ChildItem $r -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -in @('.md', '.json', '.js', '.mjs', '.ts', '.py', '.ps1', '.yaml', '.yml') }
  }
  $dest = Join-Path $skillBackupDir ("skills-{0}.zip" -f $now.ToString('yyyy-MM-dd-HHmmss'))
  Make-Zip $files $dest 'skills（保留所有历史版本）'
}

function Backup-Plugins {
  $profile = $env:DSH_PROFILE_DIR
  $files = @()
  if ($profile -and (Test-Path $profile)) {
    foreach ($n in @('cordis.patch.yml', 'cordis.yml', 'package.json', 'pnpm-lock.yaml')) {
      $f = Join-Path $profile $n
      if (Test-Path $f) { $files += Get-Item $f }
    }
  }
  $cfg = Join-Path $botRoot 'dsh-config'
  if (Test-Path $cfg) {
    $files += Get-ChildItem $cfg -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -in @('.yml', '.json', '.yaml') }
  }
  $dest = Join-Path $pluginBackupDir 'plugins-prev.zip'
  Make-Zip $files $dest 'plugins（保留 1 份上一版本）'
  if ($Apply) {
    Get-ChildItem $pluginBackupDir -File -Filter 'plugins-*.zip' -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -ne $dest } |
      Remove-Item -Force -ErrorAction SilentlyContinue
  }
}

Backup-Bots
Backup-Skills
Backup-Plugins

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
$lines += @("", "## 备份", "")
if ($backups.Count -eq 0) {
  $lines += "本次没有可备份文件。"
} else {
  foreach ($b in $backups) {
    $lines += ("- {0}：`{1}`（{2} 个文件，{3}）" -f $b.label, $b.path, $b.files, $b.mode)
  }
}
$lines += @("", "## 保护清单", "", "`sync/audio`、`sync/voice`、`latest.md`、`icreat-latest.*`、`wang-dali-state.json`、`~/.icreat/token.txt`、`session.txt`、`chrome-profile` 不清理。")
$text = $lines -join "`n"
Set-Content (Join-Path $reportDir 'li-shen-latest.md') $text -Encoding utf8
Set-Content (Join-Path $reportDir ("li-shen-{0}.md" -f $now.ToString('yyyy-MM-dd'))) $text -Encoding utf8
Log ("done mode={0} deleted={1} freed={2}MB" -f $mode, $deleted.Count, [math]::Round($freed/1MB, 2))
Write-Host ("{0}: deleted {1}, freed {2} MB" -f $mode, $deleted.Count, [math]::Round($freed/1MB, 2))
