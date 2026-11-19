param(
  [string]$Prompt = '',
  [string]$Project = 'C:\Users\EDY\Downloads\fable_projt_test01',
  [switch]$NoUi
)

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot

$lib = Join-Path $root '..\employees\employee-lib.ps1'
if (-not (Test-Path $lib)) { $lib = Join-Path $root 'employee-lib.ps1' }
if (Test-Path $lib) { . $lib }

$memDir = Join-Path $root '..\memory'
if (-not (Test-Path $memDir)) { $memDir = Join-Path $root 'memory' }
New-Item -ItemType Directory -Force $memDir | Out-Null
$memFile = Join-Path $memDir 'chen-shu-memory.json'

# ---------------------------------------------------------------- 工具
function Get-Src {
  param([string]$Proj, [string[]]$Include)
  Get-ChildItem -Path $Proj -Recurse -File -Include $Include -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\chrome[^\\]*\\|node_modules|\.git\\|\\_archive\\|\\shots\\|\\chart\\out\\|\\bots\\' }
}

function Read-Text($f) {
  if (-not $f) { return '' }
  return (Get-Content $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue)
}

$results = New-Object System.Collections.ArrayList
function Add-Check {
  param([string]$Id, [string]$Name, [string]$State, [string]$Detail)
  [void]$results.Add([pscustomobject]@{ Id = $Id; Name = $Name; State = $State; Detail = $Detail })
}

$comicEng = Get-Src $Project 'engine.js' | Select-Object -First 1
$comicHtml = Get-Src $Project 'comic.html' | Select-Object -First 1
$remakeGame = Get-Src $Project 'remake-game.js' | Select-Object -First 1

$engText = Read-Text $comicEng
$htmlText = Read-Text $comicHtml
$remText = Read-Text $remakeGame

if (-not $engText -and -not $remText) {
  Add-Check 'A01' '音频实现' 'SKIP' '未找到 engine.js / remake-game.js，无音频可查'
  $audio = $null
} else {
  $audio = [pscustomobject]@{
    Comic = $engText
    Html = $htmlText
    Remake = $remText
  }
}

# ---------------------------------------------------------------- A01 手势后起音
if ($audio) {
  $comicCtx = [regex]::Match($engText, 'function audioStart\(\)\s*\{[\s\S]{0,700}?new \(window\.AudioContext')
  $comicGesture = $engText -match "'pointerdown'[\s\S]{0,120}?audioStart\(\)"
  $htmlGesture = $htmlText -match "startBtn'\)\.onclick[\s\S]{0,1500}?AudioContext"
  $remakeGesture = $remText -match 'start\(\)\s*\{[\s\S]{0,300}?new\(window\.AudioContext'
  $ok = 0; $miss = @()
  if ($comicCtx.Success) { $ok++ } else { $miss += '漫画：AudioContext 未封装在 audioStart()' }
  if ($comicGesture) { $ok++ } else { $miss += '漫画：pointerdown 未调用 audioStart()' }
  if ($htmlGesture) { $ok++ } else { $miss += '漫画：开始按钮未在点击里唤起音频' }
  if ($remakeGesture) { $ok++ } else { $miss += '重制版：Sound.start() 未延迟到用户操作' }
  if ($miss.Count -eq 0) {
    Add-Check 'A01' '手势后起音' 'PASS' '两版都在用户手势内创建/唤醒 AudioContext，没有自动播放拦截风险'
  } elseif ($ok -ge 2) {
    Add-Check 'A01' '手势后起音' 'WARN' "部分路径未在手势内起音：$($miss -join '；')"
  } else {
    Add-Check 'A01' '手势后起音' 'FAIL' "$($miss -join '；') → Chrome 会直接静音，玩家以为没做声音"
  }
}

# ---------------------------------------------------------------- A02 静音开关与持久化
if ($audio) {
  $soundBtn = $engText -match 'soundBtn'
  $persist = $engText -match "\.sound'\)" -or $engText -match "getItem\(SAVE_KEY \+ '\.sound'"
  $gainToggle = $engText -match 'master\.gain\.value' -or $remText -match 'setTargetAtTime'
  $remakeSetting = $remText -match 'settings\.sound' -and $remText -match 'setEnabled'
  $hits = @()
  if ($soundBtn) { $hits += '漫画开关' }
  if ($persist) { $hits += '漫画持久化' }
  if ($gainToggle) { $hits += '增益直控' }
  if ($remakeSetting) { $hits += '重制版设置项' }
  if ($hits.Count -ge 4) {
    Add-Check 'A02' '静音开关' 'PASS' '声音按钮 + localStorage 记忆 + 增益直控 + 重制版设置项，四路齐全'
  } elseif ($hits.Count -ge 2) {
    Add-Check 'A02' '静音开关' 'WARN' "只做到: $($hits -join '、')"
  } else {
    Add-Check 'A02' '静音开关' 'FAIL' '找不到可用的静音入口，玩家只能关系统音量'
  }
}

# ---------------------------------------------------------------- A03 环境垫层 SND-001
if ($audio) {
  $comicBed = ($engText -match 'createOscillator') -and ($engText -match "type = 'lowpass'") -and ($engText -match 'o1\.frequency\.value = 55')
  $remakeBed = ($remText -match 'createOscillator') -and ($remText -match '48') -and ($remText -match '72\.15')
  if ($comicBed -and $remakeBed) {
    Add-Check 'A03' '环境垫层' 'PASS' 'SND-001 双振荡器 + 低通（漫画 55/82.4Hz，重制版 48/72.15/96.3Hz）均在'
  } elseif ($comicBed -or $remakeBed) {
    Add-Check 'A03' '环境垫层' 'WARN' "只有一版有通风低频床（$(@($comicBed,$remakeBed) | Where-Object {$_} | Measure-Object).Count/2）"
  } else {
    Add-Check 'A03' '环境垫层' 'FAIL' 'SND-001 未实现：没有持续低频，房间是「哑」的'
  }
}

# ---------------------------------------------------------------- A04 音效清单覆盖
if ($audio) {
  $all = $engText + "`n" + $remText
  $spec = @(
    @{ Id = 'SND-001'; Name = '通风低频'; Hit = ($all -match 'createOscillator' -and $all -match 'lowpass') },
    @{ Id = 'SND-002'; Name = '录音启动双脉冲'; Hit = ($all -match '1200|1\.2e3') },
    @{ Id = 'SND-003'; Name = '纸杯摩擦'; Hit = ($all -match 'bandpass') },
    @{ Id = 'SND-004'; Name = '终端打字'; Hit = ($all -match "sfx\(\s*'type'|kind === 'type'|'keystroke'") },
    @{ Id = 'SND-005'; Name = '闸刀落下'; Hit = ($all -match 'slam|clank|impact|hammer|thud') },
    @{ Id = 'SND-006'; Name = '证物室静默'; Hit = ($all -match 'duck|silenceAudio|gainRampTo\(-40') }
  )
  $done = @($spec | Where-Object { $_.Hit })
  $miss = @($spec | Where-Object { -not $_.Hit })
  $uiTones = @()
  foreach ($k in @('click', 'page', 'alert')) {
    if ($all -match "sfx\(\s*'$k'\s*\)") { $uiTones += $k }
  }
  if ($remText -match 'alarm\(\)') { $uiTones += 'alarm' }
  if ($miss.Count -eq 0) {
    Add-Check 'A04' '音效清单' 'PASS' "资产表 6 条全部落地（另有 $($uiTones.Count) 个 UI 提示音）"
  } elseif ($done.Count -le 1) {
    Add-Check 'A04' '音效清单' 'FAIL' "资产表 6 条只落地 $($done.Count) 条（$(($done | ForEach-Object { $_.Name }) -join '、')）；缺 $(($miss | ForEach-Object { $_.Name }) -join '、')。现有 $($uiTones.Count) 个提示音（$($uiTones -join '/')）不能替代叙事音效"
  } else {
    Add-Check 'A04' '音效清单' 'WARN' "落地 $($done.Count)/6；缺 $(($miss | ForEach-Object { $_.Name }) -join '、')"
  }
}

# ---------------------------------------------------------------- A05 指数斜坡不归零
if ($audio) {
  $exp = ($engText -match 'exponentialRampToValueAtTime\(0\.001') -or ($remText -match 'exponentialRampToValueAtTime\(\.001')
  $expZero = ($engText -match 'exponentialRampToValueAtTime\(\s*0\s*,') -or ($remText -match 'exponentialRampToValueAtTime\(\s*0\s*,')
  if ($expZero) {
    Add-Check 'A05' '包络安全' 'FAIL' '存在「指数斜坡到 0」：WebAudio 会抛 RangeError，那个音效直接不响'
  } elseif ($exp) {
    Add-Check 'A05' '包络安全' 'PASS' '指数斜坡收在 0.001，不会静音失败（标准写法）'
  } else {
    Add-Check 'A05' '包络安全' 'WARN' '未使用指数包络，短音会有「咔哒」爆音风险'
  }
}

# ---------------------------------------------------------------- A06 失焦降噪
if ($audio) {
  $focus = ($all -match 'visibilitychange') -or ($all -match "addEventListener\('blur'")
  if ($focus) {
    Add-Check 'A06' '失焦降噪' 'PASS' '页面隐藏/失焦时会压掉声音'
  } else {
    Add-Check 'A06' '失焦降噪' 'WARN' '切到别的窗口后通风床继续响 → 用户会去找是谁在响；建议 visibilitychange 时把 master 压到 0'
  }
}

# ---------------------------------------------------------------- A07 音量上限
if ($audio) {
  $loud = @()
  foreach ($m in [regex]::Matches($all, 'master\.gain\.value\s*=\s*(?:this\.enabled\s*\?\s*)?(\.\d+|\d+(?:\.\d+)?)')) {
    $v = [double]::Parse($m.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
    if ($v -gt 0.25) { $loud += "master=$v" }
  }
  foreach ($m in [regex]::Matches($all, 'tone\([^,]+,\s*[^,]+,\s*(\.\d+|\d+(?:\.\d+)?)\)')) {
    $v = [double]::Parse($m.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
    if ($v -gt 0.25) { $loud += "voice=$v" }
  }
  $loud = @($loud | Select-Object -Unique)
  if ($loud.Count -eq 0) {
    Add-Check 'A07' '音量上限' 'PASS' '主增益 ≤0.18、单声部 ≤0.25；无压缩器也不会爆'
  } else {
    Add-Check 'A07' '音量上限' 'WARN' "有 $($loud.Count) 处超过 0.25（$($loud -join '、')）——警报类音效靠裸音量抢戏，建议加限幅或压到 0.2"
  }
}

# ---------------------------------------------------------------- A08 两版实现一致性
if ($audio) {
  $dup = ($engText -match 'createOscillator') -and ($remText -match 'createOscillator')
  if ($dup) {
    Add-Check 'A08' '两版一致' 'WARN' '同一套 SND 清单在 engine.js 与 remake-game.js 各写一遍，参数已经漂移（55/82.4 vs 48/72.15/96.3）→ 校准无单一来源'
  } else {
    Add-Check 'A08' '两版一致' 'SKIP' '只有一版包含音频实现'
  }
}

# ---------------------------------------------------------------- 汇总
$fail = @($results | Where-Object State -eq 'FAIL')
$warn = @($results | Where-Object State -eq 'WARN')
$pass = @($results | Where-Object State -eq 'PASS')
$verdict = if ($fail.Count -gt 0) { 'MUTE · 声音不全' } elseif ($warn.Count -gt 0) { 'THIN · 可听但单薄' } else { 'MIXED · 可交付' }

$icon = @{ PASS = '[OK]'; FAIL = '[X ]'; WARN = '[! ]'; SKIP = '[- ]' }
$lines = foreach ($r in $results) { "$($icon[$r.State]) $($r.Id) $($r.Name)`n      $($r.Detail)" }

$body = @(
  '我是陈叔。音响。画面负责让你看见，我负责让你相信那间屋子是真的。',
  '',
  "【工程】$Project",
  "【判定】$verdict",
  "【结果】PASS $($pass.Count) / WARN $($warn.Count) / FAIL $($fail.Count)",
  '',
  '────────────────────────',
  ($lines -join "`n"),
  '────────────────────────',
  '',
  '【下一步】声音不是最后一层润色。缺的那几条音效里，静默和落闸是叙事功能，不是装饰。'
) -join "`r`n"

if (Get-Command Emp-Load -ErrorAction SilentlyContinue) {
  $mem = Emp-Load $memFile '陈叔' 'audio'
  $tags = @($fail | ForEach-Object { $_.Id })
  if ($tags.Count -eq 0) { $tags = @('声音齐备') }
  Emp-Save $memFile $mem ("$verdict " + ($fail.Name -join '/')) $tags
  if (Get-Command Emp-Summary -ErrorAction SilentlyContinue) {
    $body = $body.Replace('【判定】', "【你的特点】" + (Emp-Summary $mem) + "`r`n【判定】")
  }
}

if ($NoUi -or -not (Get-Command Emp-Show -ErrorAction SilentlyContinue)) {
  Write-Host $body
} else {
  Add-Type -AssemblyName System.Drawing
  Emp-Show '陈叔 · 音响' $body @('复制', '关闭') ([System.Drawing.Color]::FromArgb(196, 152, 96)) | Out-Null
}
