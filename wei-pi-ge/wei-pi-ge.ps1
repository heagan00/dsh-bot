param(
  [ValidateSet('review', 'update')]
  [string]$Mode = 'review'
)

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
$node = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\DeepSeek Harness.exe'
$signals = Join-Path $root '..\tools\project-signals.mjs'
$outJson = Join-Path $root 'reports\project-signals.json'
$memoryDir = Join-Path $root 'memory'
$siteContent = Join-Path $root '..\site\content'
New-Item -ItemType Directory -Force (Join-Path $root 'reports'), $memoryDir, $siteContent | Out-Null

$old = $env:ELECTRON_RUN_AS_NODE
$env:ELECTRON_RUN_AS_NODE = '1'
try {
  $p = Start-Process -FilePath $node -ArgumentList @($signals, "--out=$outJson") -Wait -PassThru -NoNewWindow
  if ($p.ExitCode -ne 0) { exit $p.ExitCode }
} finally {
  if ($null -eq $old) { Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue } else { $env:ELECTRON_RUN_AS_NODE = $old }
}

$data = Get-Content $outJson -Raw -Encoding utf8 | ConvertFrom-Json
$projects = @($data.projects)
$low = @($projects | Where-Object { $_.score -lt 70 })
$now = Get-Date

$stateFile = Join-Path $memoryDir 'wei-pi-ge-projects.json'
$projects | ConvertTo-Json -Depth 6 | Set-Content $stateFile -Encoding utf8

$tasksFile = Join-Path $memoryDir 'wei-pi-ge-hr-tasks.json'
$tasks = @()
foreach ($p in $low) {
  $tasks += [pscustomobject]@{
    project = $p.project; score = $p.score; kind = '重点监控';
    instruction = '让李老师重点抽查参与该项目的 BOT，记录低效/返工/错误。'
    created = $now.ToString('yyyy-MM-dd HH:mm:ss')
  }
}
$tasks | ConvertTo-Json -Depth 5 | Set-Content $tasksFile -Encoding utf8

$lines = @(
  '# 伟痞哥 · 项目评估',
  '',
  "- 日期：$($now.ToString('yyyy-MM-dd'))",
  "- 模式：$Mode",
  '- VP 判断：先看结果，再看效率，最后看商业价值。',
  '',
  '## 项目评分',
  '',
  '| 项目 | 分数 | 正面反馈 | 负面反馈 | 提及 | 状态 |',
  '|---|---:|---:|---:|---:|---|'
)
foreach ($p in $projects) {
  $status = if ($p.score -lt 70) { '重点观察' } else { '正常' }
  $lines += ("| {0} | {1} | {2} | {3} | {4} | {5} |" -f $p.project, $p.score, $p.positive, $p.negative, $p.mentions, $status)
}
$lines += @('', '## 重点建议', '')
if ($low.Count -eq 0) { $lines += '暂无低分项目；保持当前节奏，但不要用忙碌代替结果。' }
else {
  foreach ($p in $low) {
    $lines += ("- **{0}**：分数 {1}。先停掉无效改动，明确本周唯一交付物；让李老师监控参与 BOT 的返工率。" -f $p.project, $p.score)
  }
}
$lines += @('', '## 终极目标', '')
$lines += '每个项目只保留一个可验收的当前目标；低于 70 分的项目本周不扩范围，只收敛。'
$lines += @('', '## HRD 任务', '')
if ($tasks.Count -eq 0) { $lines += '无重点监控任务。' }
else { foreach ($t in $tasks) { $lines += ("- {0}：{1}" -f $t.project, $t.instruction) } }

$text = $lines -join "`n"
Set-Content (Join-Path $memoryDir 'wei-pi-ge-latest.md') $text -Encoding utf8
Set-Content (Join-Path $siteContent '91-project-review.md') $text -Encoding utf8
Set-Content (Join-Path $root 'reports\wei-pi-ge-latest.md') $text -Encoding utf8
Add-Content (Join-Path $root 'logs\wei-pi-ge.log') ("[{0}] mode={1} projects={2} low={3}" -f $now.ToString('yyyy-MM-dd HH:mm:ss'), $Mode, $projects.Count, $low.Count) -Encoding utf8
Write-Host ("wei-pi-ge: mode={0} projects={1} low={2}" -f $Mode, $projects.Count, $low.Count)
