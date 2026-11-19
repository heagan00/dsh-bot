$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
$logDir = Join-Path $root 'logs'
$reportDir = Join-Path $root 'reports'
$memoryDir = Join-Path $root 'memory'
$siteContent = Join-Path $root '..\site\content'
New-Item -ItemType Directory -Force $reportDir, $memoryDir, $siteContent | Out-Null

$now = Get-Date
$day = $now.ToString('yyyy-MM-dd')
$bots = @(
  [pscustomobject]@{ Name = '张淑芬'; Role = '知识库更新'; Logs = @('scheduler.log', 'weekday-*.log'); Memory = $null },
  [pscustomobject]@{ Name = '何大奔'; Role = 'iCreat 用量'; Logs = @('he-daben.log'); Memory = $null },
  [pscustomobject]@{ Name = '王大力'; Role = '心理抚慰'; Logs = @('wang-dali.log'); Memory = $null },
  [pscustomobject]@{ Name = '李婶'; Role = '缓存清理'; Logs = @('li-shen.log'); Memory = $null },
  [pscustomobject]@{ Name = '周哥'; Role = '主程巡检'; Logs = @('zhou-ge.log'); Memory = 'zhou-memory.json' },
  [pscustomobject]@{ Name = '刘哥'; Role = '主程复核'; Logs = @('liu-ge.log'); Memory = 'zhou-memory.json' },
  [pscustomobject]@{ Name = '皮特·黄'; Role = '提示词结构'; Logs = @('pieter-huang.log', 'pieter-input.log'); Memory = $null },
  [pscustomobject]@{ Name = '阿美'; Role = '美术提示词'; Logs = @(); Memory = 'amei-memory.json' },
  [pscustomobject]@{ Name = '阿威'; Role = '视频提示词'; Logs = @(); Memory = 'awei-memory.json' },
  [pscustomobject]@{ Name = '阿秃'; Role = '代码提示词'; Logs = @(); Memory = 'atu-memory.json' },
  [pscustomobject]@{ Name = '阿音'; Role = 'AI 音乐'; Logs = @(); Memory = 'ayin-memory.json' }
)

function Score-Bot($b) {
  $files = @()
  foreach ($pat in @($b.Logs)) {
    $files += Get-ChildItem $logDir -File -Filter $pat -ErrorAction SilentlyContinue
  }
  $text = ''
  foreach ($f in $files) { $text += (Get-Content $f.FullName -Raw -Encoding utf8) }
  $errors = ([regex]::Matches($text, '(?i)error|fail|exception|failed')).Count
  $activity = if ($files.Count -gt 0) { [Math]::Min(15, [Math]::Round(((Get-Date) - ($files | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime).TotalDays * -3 + 15)) } else { 0 }
  if ($activity -lt 0) { $activity = 0 }
  $memorySamples = 0
  if ($b.Memory) {
    $mf = Join-Path $memoryDir $b.Memory
    if (Test-Path $mf) {
      try { $m = Get-Content $mf -Raw -Encoding utf8 | ConvertFrom-Json; $memorySamples = @($m.samples).Count } catch {}
    }
  }
  $output = [Math]::Min(15, $files.Count * 2 + $memorySamples)
  $reliability = [Math]::Max(0, 40 - ($errors * 4))
  $efficiency = if ($errors -eq 0) { 20 } else { [Math]::Max(0, 20 - $errors * 2) }
  $collab = if ($memorySamples -gt 0 -or $files.Count -gt 0) { 10 } else { 5 }
  $score = [Math]::Min(100, $reliability + $output + $efficiency + $collab)
  return [pscustomobject]@{
    name = $b.Name; role = $b.Role; score = $score; errors = $errors;
    logs = $files.Count; memory = $memorySamples;
    reliability = $reliability; output = $output; efficiency = $efficiency; collaboration = $collab
  }
}

$scores = @($bots | ForEach-Object { Score-Bot $_ } | Sort-Object score -Descending)
$low = @($scores | Where-Object { $_.score -lt 70 })
$top = @($scores | Select-Object -First 3)

$weekTag = if ($now.DayOfWeek -eq 'Monday') { 'WEEKLY' } else { 'DAILY' }
$monthTag = if ($now.Day -eq 1) { 'MONTHLY' } else { '' }
$mode = (@($weekTag, $monthTag) | Where-Object { $_ }) -join '+'

$lines = @(
  '# 李老师 · BOT 绩效报告',
  '',
  "- 日期：$day",
  "- 周期：$mode",
  "- 评分模型：可靠性 40 / 产出 30 / 效率 20 / 协作 10（按 BOT 数量动态归一）",
  '',
  '## 评分榜',
  '',
  '| BOT | 岗位 | 总分 | 可靠性 | 产出 | 效率 | 协作 | 错误 | 记忆样本 |',
  '|---|---|---:|---:|---:|---:|---:|---:|---:|'
)
foreach ($s in $scores) {
  $lines += ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} |" -f $s.name, $s.role, $s.score, $s.reliability, $s.output, $s.efficiency, $s.collaboration, $s.errors, $s.memory)
}
$lines += @('', '## 重点纠偏（低分）', '')
if ($low.Count -eq 0) { $lines += '本期没有低于 70 分的 BOT。' }
else {
  foreach ($s in $low) {
    $lines += ("- **{0}**（{1}）：先查 {2} 条错误日志，减少无效调用；{3}" -f $s.name, $s.score, $s.errors, $(if ($s.memory -eq 0) { '补充记忆样本，否则无法评估领域能力。' } else { '抽查最近 3 次运行输出。' }))
  }
}
$lines += @('', '## 优秀样本', '')
foreach ($s in $top) { $lines += ("- {0}（{1}）：{2}" -f $s.name, $s.score, $s.role) }
$lines += @('', '## 新 BOT JD 建议', '')
$lines += '- **QA/验收 BOT**：负责对每次交付做最小验收、回归和证据留存；要求能读日志、复现问题、给出通过/不通过结论。'
$lines += '- **资源/版权 BOT**：负责素材来源、授权、商用边界和替代方案；要求懂游戏美术资产与音频授权。'
$lines += @('', '## 伟痞哥派单', '')
$hrTaskFile = Join-Path $memoryDir 'wei-pi-ge-hr-tasks.json'
$hrTasks = @()
if (Test-Path $hrTaskFile) {
  try { $hrTasks = @(Get-Content $hrTaskFile -Raw -Encoding utf8 | ConvertFrom-Json) } catch {}
}
if ($hrTasks.Count -eq 0) { $lines += '无重点监控派单。' }
else { foreach ($t in $hrTasks) { $lines += ("- {0}（分数 {1}）：{2}" -f $t.project, $t.score, $t.instruction) } }
$lines += @('', '## 记忆录入', '')
$lines += '低分 BOT 的纠偏建议已写入 `memory/li-teacher-notes.json`；下一轮优先抽查低分 BOT。'

$text = $lines -join "`n"
Set-Content (Join-Path $reportDir 'li-teacher-latest.md') $text -Encoding utf8
Set-Content (Join-Path $reportDir ("li-teacher-{0}.md" -f $day)) $text -Encoding utf8
Set-Content (Join-Path $siteContent '90-bot-hr.md') $text -Encoding utf8
if ($now.DayOfWeek -eq 'Monday') { Set-Content (Join-Path $siteContent '90-bot-hr-weekly.md') $text -Encoding utf8 }
if ($now.Day -eq 1) { Set-Content (Join-Path $siteContent '90-bot-hr-monthly.md') $text -Encoding utf8 }

$notesFile = Join-Path $memoryDir 'li-teacher-notes.json'
$notes = @{}
if (Test-Path $notesFile) {
  try {
    $old = Get-Content $notesFile -Raw -Encoding utf8 | ConvertFrom-Json
    $old.PSObject.Properties | ForEach-Object { $notes[$_.Name] = $_.Value }
  } catch {}
}
foreach ($s in $scores) {
  $note = [pscustomobject]@{
    score = $s.score; updated = $now.ToString('yyyy-MM-dd HH:mm:ss');
    note = if ($s.score -lt 70) { '低分：优先抽查运行日志与输出，下一周期复核。' } else { '正常：保持当前分工。' }
  }
  $notes[$s.name] = $note
  Set-Content (Join-Path $memoryDir ("li-teacher-{0}.json" -f $s.name)) ($note | ConvertTo-Json -Depth 4) -Encoding utf8
}
$notes | ConvertTo-Json -Depth 6 | Set-Content $notesFile -Encoding utf8
Add-Content (Join-Path $logDir 'li-teacher.log') ("[{0}] mode={1} low={2} top={3}" -f $now.ToString('yyyy-MM-dd HH:mm:ss'), $mode, $low.Count, ($top | ForEach-Object { $_.name }) -join ',') -Encoding utf8
Write-Host ("li-teacher: mode={0} low={1}" -f $mode, $low.Count)
