param([string]$Prompt = '')

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
. (Join-Path $root 'employee-lib.ps1')

$memDir = Join-Path $root '..\memory'
if (-not (Test-Path $memDir)) { $memDir = Join-Path $root 'memory' }
New-Item -ItemType Directory -Force $memDir | Out-Null
$memFile = Join-Path $memDir 'atu-memory.json'

if (-not $Prompt) { try { $Prompt = (Get-Clipboard -Raw) } catch {} }
$Prompt = ([string]$Prompt).Trim()
if (-not $Prompt) {
  Emp-Show '阿秃 · 代码提示词' '我是阿秃。把代码需求从皮特那里传给我，或者先复制到剪贴板。' @('关闭') ([System.Drawing.Color]::FromArgb(140, 190, 140)) | Out-Null
  exit 0
}

$mem = Emp-Load $memFile '阿秃' 'code'
$tags = @()
foreach ($pair in @(
  @('TypeScript', 'TypeScript'), @('ts', 'TypeScript'), @('Python', 'Python'), @('PowerShell', 'PowerShell'),
  @('API', 'API'), @('接口', 'API'), @('UI', 'UI'), @('前端', '前端'), @('后端', '后端'),
  @('测试', '测试'), @('部署', '部署'), @('性能', '性能'), @('重构', '重构'), @('bug', 'Bug'),
  @('脚本', '脚本'), @('自动化', '自动化'), @('数据库', '数据库'), @('并发', '并发')
)) {
  if ($Prompt -match [regex]::Escape($pair[0]) -and $tags -notcontains $pair[1]) { $tags += $pair[1] }
}
if ($tags.Count -eq 0) { $tags = @('未标注') }
Emp-Save $memFile $mem $Prompt $tags

$body = @(
  '我是阿秃。代码提示词先定验收，再写实现；不写验收就是耍流氓。',
  '',
  '【你的特点】' + (Emp-Summary $mem),
  '【本次记录】' + ($tags -join '、'),
  '',
  '【目标】' + $Prompt,
  '【技术栈】语言/框架/版本。',
  '【输入】文件、接口、数据结构。',
  '【约束】不能改什么，性能/兼容要求。',
  '【验收】可运行命令 + 预期输出。',
  '【测试】最小复现 / 单测。',
  '',
  '阿秃的判断：先写验收，再写最小改动；不要先造抽象。'
) -join "`r`n"
$choice = Emp-Show '阿秃 · 代码提示词' $body @('复制', '关闭') ([System.Drawing.Color]::FromArgb(140, 190, 140))
if ($choice -eq '复制') { Set-Clipboard -Value $body }
