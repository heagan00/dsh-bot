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
$memFile = Join-Path $memDir 'lao-cang-memory.json'

# ---------------------------------------------------------------- 工具
$results = New-Object System.Collections.ArrayList
function Add-Check {
  param([string]$Id, [string]$Name, [string]$State, [string]$Detail)
  [void]$results.Add([pscustomobject]@{ Id = $Id; Name = $Name; State = $State; Detail = $Detail })
}

function Get-Text($path) {
  if (-not (Test-Path $path)) { return '' }
  return (Get-Content $path -Raw -Encoding UTF8 -ErrorAction SilentlyContinue)
}

function Get-GzipSize([string]$path) {
  $in = [System.IO.File]::OpenRead($path)
  $ms = New-Object System.IO.MemoryStream
  $gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Compress, $true)
  try { $in.CopyTo($gz) } finally { $gz.Dispose(); $in.Dispose() }
  $n = $ms.Length
  $ms.Dispose()
  return $n
}

$pairs = @(
  @{ Label = '互动漫画'; Out = '文明的余烬_互动漫画.html'; Src = @(
      'game\comic\comic.html', 'game\comic\ink.js', 'game\comic\art.js',
      'game\comic\story.js', 'game\comic\engine.js', 'game\comic\pages.js') },
  @{ Label = '重制版'; Out = '文明的余烬_重制版.html'; Src = @(
      'game\remake.html', 'game\remake-scene.js', 'game\remake-game.js', 'game\three.min.js') }
)

# ---------------------------------------------------------------- B01 占位符残留
$marks = @()
foreach ($p in $pairs) {
  $t = Get-Text (Join-Path $Project $p.Out)
  $n = ([regex]::Matches($t, '@@[A-Z]+@@')).Count
  if ($n -gt 0) { $marks += "$($p.Label) ×$n" }
}
if ($marks.Count -gt 0) {
  Add-Check 'B01' '占位符残留' 'FAIL' "交付 HTML 里还有构建占位: $($marks -join '、') → 打开就是空白/半截"
} else {
  Add-Check 'B01' '占位符残留' 'PASS' '两份交付 HTML 的 /*@@KEY@@*/ 均已替换'
}

# ---------------------------------------------------------------- B02 产物新鲜度
$stale = @(); $fresh = @()
foreach ($p in $pairs) {
  $out = Join-Path $Project $p.Out
  if (-not (Test-Path $out)) { $stale += "$($p.Label)：交付文件缺失"; continue }
  $outTime = (Get-Item $out).LastWriteTime
  $srcFiles = @($p.Src | ForEach-Object { Join-Path $Project $_ } | Where-Object { Test-Path $_ })
  if ($srcFiles.Count -eq 0) { continue }
  $newest = $srcFiles | ForEach-Object { Get-Item $_ } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($newest.LastWriteTime -gt $outTime) {
    $stale += "$($p.Label)：$($newest.Name) $($newest.LastWriteTime.ToString('MM-dd HH:mm')) > 产物 $($outTime.ToString('MM-dd HH:mm'))"
  } else {
    $fresh += $p.Label
  }
}
if ($stale.Count -gt 0) {
  Add-Check 'B02' '产物新鲜度' 'FAIL' "产物落后于源: $($stale -join '；') → 你测的不是你改的"
} else {
  Add-Check 'B02' '产物新鲜度' 'PASS' "($($fresh -join '、'))：产物均不早于其源文件"
}

# ---------------------------------------------------------------- B03 包体口径
$comicOut = Join-Path $Project '文明的余烬_互动漫画.html'
$remakeOut = Join-Path $Project '文明的余烬_重制版.html'
if (-not (Test-Path $comicOut)) {
  Add-Check 'B03' '包体口径' 'SKIP' '互动漫画交付文件缺失'
} else {
  $actualKiB = [math]::Round((Get-Item $comicOut).Length / 1KB, 1)
  $doc = Get-Text (Join-Path $Project '互动漫画_说明.md')
  $claim = [regex]::Match($doc, '约\s*(\d+)\s*KB')
  if (-not $claim.Success) {
    Add-Check 'B03' '包体口径' 'WARN' "说明里没写包体；实际 $actualKiB KiB"
  } else {
    $claimed = [double]$claim.Groups[1].Value
    $dev = [math]::Round((($actualKiB - $claimed) / $claimed) * 100, 1)
    if ([math]::Abs($dev) -gt 10) {
      Add-Check 'B03' '包体口径' 'FAIL' "说明写约 $claimed KB，实际 $actualKiB KiB（偏差 $dev%）→ 包体承诺失真"
    } else {
      Add-Check 'B03' '包体口径' 'PASS' "说明约 $claimed KB，实际 $actualKiB KiB（偏差 $dev%）"
    }
  }
}

# ---------------------------------------------------------------- B04 单文件自包含
$ext = @()
foreach ($p in $pairs) {
  $t = Get-Text (Join-Path $Project $p.Out)
  $n = ([regex]::Matches($t, '<(?:script|link)[^>]+(?:src|href)="(?:https?:)?//')).Count
  if ($n -gt 0) { $ext += "$($p.Label) ×$n" }
}
if ($ext.Count -gt 0) {
  Add-Check 'B04' '单文件自包含' 'FAIL' "仍有外链脚本/样式: $($ext -join '、') → 断网打不开，且版本不受控"
} else {
  Add-Check 'B04' '单文件自包含' 'PASS' '两份交付 HTML 无外链资源，双击即开'
}

# ---------------------------------------------------------------- B05 three.js 版本
$threeFiles = @(Get-ChildItem -Path $Project -Recurse -File -Filter 'three*.js' -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\chrome' })
$three = $threeFiles | Sort-Object Length -Descending | Select-Object -First 1
$remakeText = Get-Text $remakeOut
$docRemake = Get-Text (Join-Path $Project '游戏说明_重制版.md')
$claimRev = [regex]::Match($docRemake, 'Three\.js\s*r(\d+)')
if (-not $three -and -not $remakeText) {
  Add-Check 'B05' 'three.js 版本' 'SKIP' '未找到 three.js'
} else {
  $rev = ''
  if ($three) { $rev = [regex]::Match((Get-Text $three.FullName), 'const e="(\d+)"').Groups[1].Value }
  if (-not $rev -and $remakeText) { $rev = [regex]::Match($remakeText, 'const e="(\d+)"').Groups[1].Value }
  if ($claimRev.Success -and $rev -and $claimRev.Groups[1].Value -eq $rev) {
    Add-Check 'B05' 'three.js 版本' 'PASS' "文档称 r$($claimRev.Groups[1].Value)，内嵌实为 r$rev；$($threeFiles.Count) 份副本"
  } elseif ($rev) {
    Add-Check 'B05' 'three.js 版本' 'WARN' "内嵌 r$rev，但文档未锁定版本（$($threeFiles.Count) 份副本，升级无单一来源）"
  } else {
    Add-Check 'B05' 'three.js 版本' 'WARN' "无法从库文件读出 REVISION；$($threeFiles.Count) 份副本，版本不可审计"
  }
}

# ---------------------------------------------------------------- B06 构建脚本
$builds = @('game\comic\build.py', 'game\build-remake.py')
$bMiss = @(); $bHard = @()
foreach ($b in $builds) {
  $path = Join-Path $Project $b
  if (-not (Test-Path $path)) { $bMiss += $b; continue }
  $t = Get-Text $path
  if ($t -notmatch "assert './\*@@|assert '/\*@@") { $bMiss += "$b（无占位符断言）" }
  if ($t -match '[A-Za-z]:\\|/Users/|/home/') { $bHard += $b }
}
if ($bMiss.Count -gt 0) {
  Add-Check 'B06' '构建脚本' 'FAIL' "$($bMiss -join '、') → 构建不能保证「五个脚本都写进去了」"
} elseif ($bHard.Count -gt 0) {
  Add-Check 'B06' '构建脚本' 'WARN' "$($bHard -join '、') 含绝对路径，换机器构建会断"
} else {
  Add-Check 'B06' '构建脚本' 'PASS' '两份 build.py 均以脚本目录为根、带占位断言、无绝对路径'
}

# ---------------------------------------------------------------- B07 调试目录
$junk = Get-ChildItem -Path $Project -Recurse -Directory -Filter 'chrome*' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\_archive\\' }
$junkMB = 0.0
$junkNames = @()
foreach ($d in $junk) {
  $mb = (Get-ChildItem $d.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
  $junkMB += $mb
  if ($mb -gt 1) { $junkNames += ("{0} {1}MB" -f $d.Name, [int]$mb) }
}
if ($junkMB -gt 20) {
  Add-Check 'B07' '调试目录' 'FAIL' ("{0} 个浏览器配置目录进了工程，共 {1} MB（{2}）→ 换个浏览器就重下，且全进了备份/同步" -f $junkNames.Count, [int]$junkMB, ($junkNames -join '、'))
} else {
  Add-Check 'B07' '调试目录' 'PASS' "chrome 调试目录合计 $([int]$junkMB) MB，未超标"
}

# ---------------------------------------------------------------- B08 仓库体积
$shots = Join-Path $Project 'shots'
if (-not (Test-Path $shots)) {
  Add-Check 'B08' '仓库体积' 'SKIP' '无 shots/ 目录'
} else {
  $sum = (Get-ChildItem $shots -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum)
  $mb = [math]::Round($sum.Sum / 1MB, 0)
  $png = @(Get-ChildItem $shots -Recurse -File -Filter '*.png' -ErrorAction SilentlyContinue).Count
  $blend = @(Get-ChildItem $shots -Recurse -File -Filter '*.blend*' -ErrorAction SilentlyContinue).Count
  if ($mb -gt 500) {
    Add-Check 'B08' '仓库体积' 'WARN' "shots/ 共 $mb MB（$png 张 PNG、$blend 个 .blend）→ 中间产物应与交付物分开；进 Git 前先删 _cycles/ 与 .blend1"
  } else {
    Add-Check 'B08' '仓库体积' 'PASS' "shots/ $mb MB，可接受"
  }
}

# ---------------------------------------------------------------- B09 压缩后体积
$gzParts = @()
foreach ($p in $pairs) {
  $f = Join-Path $Project $p.Out
  if (-not (Test-Path $f)) { continue }
  $raw = (Get-Item $f).Length
  $gz = Get-GzipSize $f
  $gzParts += ("{0} {1}→{2} KiB（{3}%）" -f $p.Label, [math]::Round($raw / 1KB, 0), [math]::Round($gz / 1KB, 0), [math]::Round($gz * 100 / $raw, 0))
}
if ($gzParts.Count -gt 0) {
  Add-Check 'B09' '压缩后体积' 'PASS' ($gzParts -join '；')
} else {
  Add-Check 'B09' '压缩后体积' 'SKIP' '无交付文件'
}

# ---------------------------------------------------------------- 汇总
$fail = @($results | Where-Object State -eq 'FAIL')
$warn = @($results | Where-Object State -eq 'WARN')
$pass = @($results | Where-Object State -eq 'PASS')
$verdict = if ($fail.Count -gt 0) { 'BLOATED · 不可交付' } elseif ($warn.Count -gt 0) { 'CAUTION · 可跑不可发' } else { 'LEAN · 可交付' }

$icon = @{ PASS = '[OK]'; FAIL = '[X ]'; WARN = '[! ]'; SKIP = '[- ]' }
$lines = foreach ($r in $results) { "$($icon[$r.State]) $($r.Id) $($r.Name)`n      $($r.Detail)" }

$body = @(
  '我是老苍。构建和包体。我只问三件事：能不能复现、是不是单文件、重不重。',
  '',
  "【工程】$Project",
  "【判定】$verdict",
  "【结果】PASS $($pass.Count) / WARN $($warn.Count) / FAIL $($fail.Count)",
  '',
  '────────────────────────',
  ($lines -join "`n"),
  '────────────────────────',
  '',
  '【下一步】先把调试浏览器目录从工程里清出去，再谈包体。构建脚本能复现，才谈得上发布。'
) -join "`r`n"

if (Get-Command Emp-Load -ErrorAction SilentlyContinue) {
  $mem = Emp-Load $memFile '老苍' 'build'
  $tags = @($fail | ForEach-Object { $_.Id })
  if ($tags.Count -eq 0) { $tags = @('可复现') }
  Emp-Save $memFile $mem ("$verdict " + ($fail.Name -join '/')) $tags
  if (Get-Command Emp-Summary -ErrorAction SilentlyContinue) {
    $body = $body.Replace('【判定】', "【你的特点】" + (Emp-Summary $mem) + "`r`n【判定】")
  }
}

if ($NoUi -or -not (Get-Command Emp-Show -ErrorAction SilentlyContinue)) {
  Write-Host $body
} else {
  Add-Type -AssemblyName System.Drawing
  Emp-Show '老苍 · 构建与包体' $body @('复制', '关闭') ([System.Drawing.Color]::FromArgb(176, 160, 120)) | Out-Null
}
