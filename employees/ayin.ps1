param([string]$Prompt = '')

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
. (Join-Path $root 'employee-lib.ps1')

$memDir = Join-Path $root '..\memory'
if (-not (Test-Path $memDir)) { $memDir = Join-Path $root 'memory' }
New-Item -ItemType Directory -Force $memDir | Out-Null
$memFile = Join-Path $memDir 'ayin-memory.json'

if (-not $Prompt) { try { $Prompt = (Get-Clipboard -Raw) } catch {} }
$Prompt = ([string]$Prompt).Trim()
if (-not $Prompt) {
  Emp-Show '阿音 · AI 音乐提示词' '我是阿音。把你想写的歌、想表达的故事，或者一段情绪交给我。' @('关闭') ([System.Drawing.Color]::FromArgb(170, 135, 210)) | Out-Null
  exit 0
}

$mem = Emp-Load $memFile '阿音' 'music'
$tags = @()
$genreMap = @(
  @('流行', '流行'), @('pop', '流行'), @('摇滚', '摇滚'), @('rock', '摇滚'), @('电子', '电子'),
  @('国风', '国风'), @('古风', '国风'), @('爵士', '爵士'), @('jazz', '爵士'), @('民谣', '民谣'),
  @('嘻哈', '嘻哈'), @('rap', '嘻哈'), @('管弦', '管弦'), @('交响', '管弦'), @('lo-fi', 'Lo-Fi'),
  @('金属', '金属'), @('r&b', 'R&B'), @('民乐', '民乐'), @('治愈', '治愈')
)
$moodMap = @(
  @('治愈', '治愈'), @('温暖', '温暖'), @('悲伤', '悲伤'), @('孤独', '孤独'), @('热血', '热血'),
  @('浪漫', '浪漫'), @('神秘', '神秘'), @('欢快', '欢快'), @('思念', '思念'), @('离别', '离别')
)
$vocalMap = @(
  @('女声', '女声'), @('男声', '男声'), @('合唱', '合唱'), @('纯音乐', '纯音乐'),
  @('说唱', '说唱'), @('童声', '童声'), @('和声', '和声')
)
$langMap = @(@('中文', '中文'), @('英文', '英文'), @('日语', '日语'), @('粤语', '粤语'))
$instMap = @(
  @('钢琴', '钢琴'), @('吉他', '吉他'), @('弦乐', '弦乐'), @('小提琴', '弦乐'), @('鼓', '鼓'),
  @('合成器', '合成器'), @('笛子', '竹笛'), @('二胡', '二胡'), @('古筝', '古筝'), @('贝斯', '贝斯')
)
foreach ($map in @($genreMap, $moodMap, $vocalMap, $langMap, $instMap)) {
  foreach ($pair in $map) {
    if ($Prompt -match [regex]::Escape($pair[0]) -and $tags -notcontains $pair[1]) { $tags += $pair[1] }
  }
}
if ($Prompt -match '(\d{2,3})\s*(bpm|BPM|拍)') { $tags += ($Matches[1] + ' BPM') }
if ($tags.Count -eq 0) { $tags = @('未标注') }
Emp-Save $memFile $mem $Prompt $tags

$styleParts = @()
if ($tags -match '国风') { $styleParts += 'Chinese folk-pop, guzheng and dizi, cinematic' }
elseif ($tags -match '电子') { $styleParts += 'electronic pop, warm synth, sidechain' }
elseif ($tags -match '摇滚') { $styleParts += 'alternative rock, live drums, distorted guitar' }
elseif ($tags -match '爵士') { $styleParts += 'jazz pop, brushed drums, upright bass' }
else { $styleParts += 'cinematic pop, piano and strings' }
if ($tags -match '女声') { $styleParts += 'female vocal' }
elseif ($tags -match '男声') { $styleParts += 'male vocal' }
elseif ($tags -match '纯音乐') { $styleParts += 'instrumental' }
else { $styleParts += 'intimate vocal' }
if ($tags -match '治愈|温暖') { $styleParts += 'warm, healing, gentle' }
elseif ($tags -match '悲伤|离别|孤独') { $styleParts += 'melancholic, sparse, emotional' }
elseif ($tags -match '热血') { $styleParts += 'epic, driving, uplifting' }
if ($tags -match 'BPM') { $styleParts += ($tags | Where-Object { $_ -like '* BPM' } | Select-Object -First 1) }
else { $styleParts += '88 BPM' }
$styleParts += 'clear vocal, wide stereo, radio-ready'

$lyrics = @'
[Intro]
（2 小节，留白，先给氛围）

[Verse 1]
（主歌：第一人称，写一个具体画面，不要先讲道理）
我把没说完的话，留在夜里的风里
（第二句：动作 + 细节 + 情绪）

[Pre-Chorus]
（预副歌：把情绪推上去，一句短句重复）

[Chorus]
（副歌：一句能记住的钩子，重复 2 次）
（第二句：把主题说透，不要堆形容词）

[Verse 2]
（主歌 2：换一个时间/地点，继续讲故事）

[Bridge]
（桥段：转调或降 instrumentation，给一句真话）

[Chorus]
（副歌重复，最后一句可以改一个字）

[Outro]
（收尾：回到开头的画面，留白）
'@

$body = @(
  '我是阿音。先听懂你要的画面，再把它翻译成 SUNO 能唱的 prompt。',
  '',
  '【你的特点】' + (Emp-Summary $mem),
  '【我听到的】' + $Prompt,
  '【情绪判断】' + (($tags | Where-Object { $_ -notlike '*BPM' }) -join '、'),
  '',
  '【SUNO Style】',
  ($styleParts -join ', '),
  '',
  '【SUNO Lyrics】',
  $lyrics,
  '',
  '【编曲建议】前 15 秒只留人声和一件乐器；副歌再加鼓和低频；桥段抽掉鼓，最后一遍副歌全开。',
  '',
  '【Negative】noisy mix, clipping, off-key vocal, muddy low end, random genre switch'
) -join "`r`n"

$choice = Emp-Show '阿音 · AI 音乐提示词' $body @('复制', '关闭') ([System.Drawing.Color]::FromArgb(170, 135, 210))
if ($choice -eq '复制') { Set-Clipboard -Value $body }
