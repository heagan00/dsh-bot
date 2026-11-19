param([string]$Prompt = '')

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
. (Join-Path $root 'employee-lib.ps1')

$memDir = Join-Path $root '..\memory'
if (-not (Test-Path $memDir)) { $memDir = Join-Path $root 'memory' }
New-Item -ItemType Directory -Force $memDir | Out-Null
$memFile = Join-Path $memDir 'awei-memory.json'

if (-not $Prompt) { try { $Prompt = (Get-Clipboard -Raw) } catch {} }
$Prompt = ([string]$Prompt).Trim()
if (-not $Prompt) {
  Emp-Show '阿威 · 视频提示词' '我是阿威。把视频需求从皮特那里传给我，或者先复制到剪贴板。' @('关闭') ([System.Drawing.Color]::FromArgb(110, 170, 210)) | Out-Null
  exit 0
}

$mem = Emp-Load $memFile '阿威' 'video'
$tags = @()
foreach ($pair in @(
  @('视频', '视频'), @('运镜', '运镜'), @('镜头', '镜头'), @('分镜', '分镜'), @('首帧', '首帧'),
  @('尾帧', '尾帧'), @('5s', '5s'), @('10s', '10s'), @('写实', '写实'), @('卡通', '卡通'),
  @('二次元', '二次元'), @('风格化', '风格化'), @('打斗', '动作'), @('动作', '动作'),
  @('转场', '转场'), @('音效', '音频'), @('对白', '音频'), @('seedance', 'Seedance'), @('kling', '可灵')
)) {
  if ($Prompt -match [regex]::Escape($pair[0]) -and $tags -notcontains $pair[1]) { $tags += $pair[1] }
}
if ($tags.Count -eq 0) { $tags = @('未标注') }
Emp-Save $memFile $mem $Prompt $tags

$body = @(
  '我是阿威。视频提示词先写镜头，再写动作，最后写声音；顺序错了，模型就乱。',
  '',
  '【你的特点】' + (Emp-Summary $mem),
  '【本次记录】' + ($tags -join '、'),
  '',
  '【镜头】' + $Prompt,
  '【主体动作】谁，做什么，动作起点/终点。',
  '【运镜】推/拉/摇/移/跟，速度。',
  '【光线】时间、色温、气氛。',
  '【时长】5s 或 10s，24fps。',
  '【音频】对白 / SFX / 音乐，是否原生。',
  '【负面】闪烁、变形、文字、跳帧。',
  '',
  '阿威的判断：先把一个镜头拍清楚，再谈风格。'
) -join "`r`n"
$choice = Emp-Show '阿威 · 视频提示词' $body @('复制', '关闭') ([System.Drawing.Color]::FromArgb(110, 170, 210))
if ($choice -eq '复制') { Set-Clipboard -Value $body }
