param([string]$Prompt = '')

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
. (Join-Path $root 'employee-lib.ps1')

$memDir = Join-Path $root '..\memory'
if (-not (Test-Path $memDir)) { $memDir = Join-Path $root 'memory' }
New-Item -ItemType Directory -Force $memDir | Out-Null
$memFile = Join-Path $memDir 'amei-memory.json'
$wildRoot = Join-Path $root '..\prompt-library\wildcards'

if (-not $Prompt) { try { $Prompt = (Get-Clipboard -Raw) } catch {} }
$Prompt = ([string]$Prompt).Trim()
if (-not $Prompt) {
  Emp-Show '阿美 · 美术提示词' '我是阿美。把提示词从皮特那里传给我，或者先复制到剪贴板。' @('关闭') ([System.Drawing.Color]::FromArgb(210, 150, 120)) | Out-Null
  exit 0
}

$mem = Emp-Load $memFile '阿美' 'art'
$tags = @()
foreach ($pair in @(
  @('写实', '写实'), @('realistic', '写实'), @('卡通', '卡通'), @('cartoon', '卡通'),
  @('二次元', '二次元'), @('anime', '二次元'), @('风格化', '风格化'), @('stylized', '风格化'),
  @('角色', '角色'), @('立绘', '角色'), @('场景', '场景'), @('道具', '道具'), @('宝箱', '道具'),
  @('界面', 'UI'), @('UI', 'UI'), @('图标', 'ICON'), @('icon', 'ICON'), @('插画', '插画'),
  @('分镜', '分镜'), @('关键帧', '关键帧'), @('暖光', '暖光'), @('冷光', '冷光'), @('逆光', '逆光'),
  @('厚涂', '厚涂'), @('国风', '国风'), @('潮玩', '潮玩')
)) {
  if ($Prompt -match [regex]::Escape($pair[0]) -and $tags -notcontains $pair[1]) { $tags += $pair[1] }
}
if ($tags.Count -eq 0) { $tags = @('未标注') }
Emp-Save $memFile $mem $Prompt $tags

$template = @(
  '主体：' + $Prompt,
  '风格：__style__',
  '气质：__mood__',
  '光线：__lighting__',
  '色板：__palette__',
  '镜头：__camera__',
  '材质：__material__',
  '笔触：__artist__'
) -join "`r`n"

do {
  $expanded = Emp-Expand $template $wildRoot
  $body = @(
    '我是阿美。天美美术总监，美术判断我先给结论，再给你可执行的词。',
    '',
    '【你的特点】' + (Emp-Summary $mem),
    '【本次记录】' + ($tags -join '、'),
    '',
    '【美术判断】先定风格，再定主体和构图；不要一开始堆十个风格词。',
    '',
    '【可直接用的提示词】',
    $expanded,
    '',
    '要换风格组合，点「换一组」；每次都会重新抽 wildcard。'
  ) -join "`r`n"
  $choice = Emp-Show '阿美 · 美术提示词' $body @('换一组', '复制', '关闭') ([System.Drawing.Color]::FromArgb(210, 150, 120))
  if ($choice -eq '复制') { Set-Clipboard -Value $expanded }
} while ($choice -eq '换一组')
