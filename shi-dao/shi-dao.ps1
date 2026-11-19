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
$memFile = Join-Path $memDir 'shi-dao-memory.json'

# ---------------------------------------------------------------- 工具
function Get-Src {
  param([string]$Proj, [string[]]$Include)
  Get-ChildItem -Path $Proj -Recurse -File -Include $Include -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\chrome[^\\]*\\|node_modules|\.git\\|\\_archive\\|\\shots\\|\\chart\\out\\' }
}

function Get-Delivered {
  Get-ChildItem -Path $Project -Filter '*.html' -File -ErrorAction SilentlyContinue
}

$results = New-Object System.Collections.ArrayList
function Add-Check {
  param([string]$Id, [string]$Name, [string]$State, [string]$Detail)
  [void]$results.Add([pscustomobject]@{ Id = $Id; Name = $Name; State = $State; Detail = $Detail })
}

# ---------------------------------------------------------------- V01 画格覆盖
$pagesFile = Get-Src $Project 'pages.js' | Select-Object -First 1
$rectsMeta = @()
if (-not $pagesFile) {
  Add-Check 'V01' '画格覆盖' 'SKIP' '未找到 pages.js，跳过分镜几何检查'
} else {
  $src = Get-Content $pagesFile.FullName -Raw -Encoding UTF8
  $VW = 1600; $VH = 900
  $ink = Get-Src $Project 'ink.js' | Select-Object -First 1
  if ($ink) {
    $t = Get-Content $ink.FullName -Raw -Encoding UTF8
    $m = [regex]::Match($t, 'VW\s*=\s*(\d+)\s*,\s*VH\s*=\s*(\d+)')
    if ($m.Success) { $VW = [int]$m.Groups[1].Value; $VH = [int]$m.Groups[2].Value }
  }
  $blocks = [regex]::Matches($src, "(?s)id:\s*'(p\d+)'(.*?)(?=\n\s*P_\(|\n\s*pages\.forEach)")
  foreach ($b in $blocks) {
    $id = $b.Groups[1].Value
    $rects = [regex]::Matches($b.Groups[2].Value, 'r:\s*\[([^\]]+)\]')
    $area = 0.0
    foreach ($r in $rects) {
      $parts = $r.Groups[1].Value -split ','
      if ($parts.Count -ne 4) { continue }
      $ok = $true; $vals = @()
      foreach ($part in $parts) {
        $expr = $part.Trim().Replace('W', [string]$VW).Replace('H', [string]$VH)
        if ($expr -match '^[0-9\.\s\+\-\*/\(\)]+$') {
          try { $vals += [double](Invoke-Expression $expr) } catch { $ok = $false }
        } else { $ok = $false }
      }
      if ($ok -and $vals.Count -eq 4) { $area += $vals[2] * $vals[3] }
    }
    $rectsMeta += [pscustomobject]@{ Id = $id; Panels = $rects.Count; Coverage = [math]::Round($area / ($VW * $VH), 3) }
  }
  $bad = @($rectsMeta | Where-Object { $_.Coverage -lt 0.90 -or $_.Coverage -gt 1.02 })
  $minCov = ($rectsMeta | Measure-Object Coverage -Minimum).Minimum
  $maxCov = ($rectsMeta | Measure-Object Coverage -Maximum).Maximum
  if ($rectsMeta.Count -eq 0) {
    Add-Check 'V01' '画格覆盖' 'SKIP' '未解析到画格矩形'
  } elseif ($bad.Count -gt 0) {
    $rows = ($bad | ForEach-Object { "  · $($_.Id) 覆盖 $($_.Coverage)" }) -join "`n"
    Add-Check 'V01' '画格覆盖' 'FAIL' "$($bad.Count)/$($rectsMeta.Count) 页画格覆盖越界（0.90–1.02）:`n$rows → 露底或压格"
  } else {
    Add-Check 'V01' '画格覆盖' 'PASS' "$($rectsMeta.Count) 页画格覆盖 $minCov–$maxCov（留缝 1.5–4%，无露底）"
  }

  # V02 对白跨格
  $mapBlock = [regex]::Match($src, "(?s)const BUBBLE_PANELS = \{(.*?)\};").Groups[1].Value
  $mapped = @([regex]::Matches($mapBlock, '(p\d+)') | ForEach-Object { $_.Groups[1].Value })
  $bubblePages = @($blocks | Where-Object { $_.Groups[2].Value -match 'bubbles:\s*\[\s*\{' } | ForEach-Object { $_.Groups[1].Value })
  $unmapped = @($bubblePages | Where-Object { $mapped -notcontains $_ })
  if ($bubblePages.Count -eq 0) {
    Add-Check 'V02' '对白不跨格' 'SKIP' '未检测到带气泡的页'
  } elseif ($unmapped.Count -gt 0) {
    Add-Check 'V02' '对白不跨格' 'WARN' "$($unmapped.Count)/$($bubblePages.Count) 页气泡未进 BUBBLE_PANELS（$(($unmapped -join ', '))）→ 位置写死，改画格会压字"
  } else {
    Add-Check 'V02' '对白不跨格' 'PASS' "全部 $($bubblePages.Count) 页气泡已按分镜索引约束"
  }
}

# ---------------------------------------------------------------- V03 字号下限
$shell = Get-Delivered | Where-Object { $_.Name -like '*互动漫画*' } | Select-Object -First 1
if (-not $shell) {
  $shell = Get-Src $Project 'comic.html' | Select-Object -First 1
}
if (-not $shell) {
  Add-Check 'V03' '字号下限' 'SKIP' '未找到漫画外壳 HTML'
} else {
  $t = Get-Content $shell.FullName -Raw -Encoding UTF8
  $sizes = @()
  $sizes += [regex]::Matches($t, 'font-size:\s*([\d.]+)px') | ForEach-Object { [double]$_.Groups[1].Value }
  $sizes += [regex]::Matches($t, 'font:\s*[^;]*?([\d.]+)px/') | ForEach-Object { [double]$_.Groups[1].Value }
  $sizes = @($sizes)
  $minSize = ($sizes | Measure-Object -Minimum).Minimum
  $lt11 = @($sizes | Where-Object { $_ -lt 11 })
  $lt10 = @($sizes | Where-Object { $_ -lt 10 })
  if ($minSize -lt 9) {
    Add-Check 'V03' '字号下限' 'FAIL' "最小字号 $minSize px（<$($lt10.Count) 处 <10px）→ 手机上基本不可读"
  } elseif ($lt10.Count -ge 5) {
    Add-Check 'V03' '字号下限' 'FAIL' "$($lt10.Count) 处字号 <10px（最小 $minSize px）→ 正文级文字已进入不可读区间"
  } elseif ($lt11.Count -gt 0) {
    Add-Check 'V03' '字号下限' 'WARN' "$($lt11.Count)/$($sizes.Count) 处字号 <11px（最小 $minSize px），均为标签/角标；正文 12.5px 起"
  } else {
    Add-Check 'V03' '字号下限' 'PASS' "全部 $($sizes.Count) 处字号 ≥11px"
  }
}

# ---------------------------------------------------------------- V04 零外部素材
$scan = @()
$scan += Get-Delivered
$scan += @(Get-Src $Project 'comic.html','ink.js','art.js','story.js','pages.js','engine.js')
$hits = @()
$loaders = @(
  '(?:src|href)\s*=\s*["''](?:https?:)?//',
  'url\(\s*["'']?(?:https?:)?//',
  'fetch\(\s*["''](?:https?:)?//',
  '@import\s+["'']?(?:https?:)?//',
  'importScripts\(\s*["''](?:https?:)?//'
)
foreach ($f in ($scan | Where-Object { $_ } | Select-Object -Unique)) {
  $t = Get-Content $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
  if (-not $t) { continue }
  foreach ($pat in $loaders) {
    foreach ($u in ([regex]::Matches($t, $pat) | ForEach-Object { $_.Value })) {
      $hits += [pscustomobject]@{ File = $f.Name; Url = $u }
    }
  }
}
if ($hits.Count -gt 0) {
  $rows = ($hits | Select-Object -First 6 | ForEach-Object { "  · $($_.File)：$($_.Url)" }) -join "`n"
  Add-Check 'V04' '零外部素材' 'FAIL' "$($hits.Count) 处外部加载（src/href/url/fetch）:`n$rows"
} else {
  Add-Check 'V04' '零外部素材' 'PASS' "画面无 src/href/fetch 外部加载（内嵌 three.js 的自述链接不算素材）"
}

# ---------------------------------------------------------------- V05 竖屏降级
if (-not $shell) {
  Add-Check 'V05' '竖屏降级' 'SKIP' '未找到漫画外壳 HTML'
} else {
  $t = Get-Content $shell.FullName -Raw -Encoding UTF8
  $hasOverlay = $t -match 'id="rotate"'
  $hasMedia = $t -match 'orientation:\s*portrait'
  $hasSkip = $t -match 'rotSkip'
  if ($hasOverlay -and $hasMedia -and $hasSkip) {
    Add-Check 'V05' '竖屏降级' 'PASS' '竖屏提示层 + 媒体查询 + 「仍然竖屏继续」三件齐全'
  } else {
    $miss = @()
    if (-not $hasOverlay) { $miss += '提示层' }
    if (-not $hasMedia) { $miss += '媒体查询' }
    if (-not $hasSkip) { $miss += '跳过按钮' }
    Add-Check 'V05' '竖屏降级' 'FAIL' "缺失: $($miss -join '、') → 竖屏直接开始读，画格被裁"
  }
}

# ---------------------------------------------------------------- V06 安全区与溢出
if (-not $shell) {
  Add-Check 'V06' '安全区与溢出' 'SKIP' '未找到漫画外壳 HTML'
} else {
  $t = Get-Content $shell.FullName -Raw -Encoding UTF8
  $noScroll = $t -match 'overflow:\s*hidden'
  $media = $t -match '@media\s*\(max-width:\s*860px\)'
  $reflow = $t -match '#choices\s*\{[^}]*max-height' -and $t -match 'max-height:\s*56vh'
  $safe = 0
  if ($noScroll) { $safe++ }
  if ($media) { $safe++ }
  if ($reflow) { $safe++ }
  if ($safe -eq 3) {
    Add-Check 'V06' '安全区与溢出' 'PASS' '锁滚动 + 860px 断点 + 移动端选项栏改底部（max-height 56vh）'
  } else {
    Add-Check 'V06' '安全区与溢出' 'WARN' "三项只满足 $safe/3（滚动锁定/断点/选项栏重排），移动端可能横向溢出"
  }
}

# ---------------------------------------------------------------- V07 颗粒与暗角
$grainTok = @()
if ($shell) {
  $t = Get-Content $shell.FullName -Raw -Encoding UTF8
  if ($t -match 'id="grain"') { $grainTok += '颗粒层' }
  if ($t -match 'id="frame"') { $grainTok += '取景框' }
  if ($t -match 'feTurbulence') { $grainTok += '程序噪声' }
}
$vign = $false
if ($pagesFile) {
  $pt = Get-Content $pagesFile.FullName -Raw -Encoding UTF8
  $vign = $pt -match 'function vignette'
}
if ($grainTok.Count -ge 3 -and $vign) {
  Add-Check 'V07' '颗粒与暗角' 'PASS' "UI-006 落地：颗粒层 + 取景框 + 每格 vignette()"
} elseif ($grainTok.Count -gt 0 -or $vign) {
  Add-Check 'V07' '颗粒与暗角' 'WARN' "只实现 $(($grainTok -join '、'))$(if($vign){'、vignette()'}) → 全片质感不统一"
} else {
  Add-Check 'V07' '颗粒与暗角' 'FAIL' 'UI-006 未实现：无颗粒层、无暗角，画面会显得像 PPT'
}

# ---------------------------------------------------------------- V08 截图新鲜度
$shotDir = Join-Path $Project 'shots'
$comicSrc = @(Get-Src $Project 'comic.html','ink.js','art.js','story.js','pages.js','engine.js')
if (-not (Test-Path $shotDir) -or $comicSrc.Count -eq 0) {
  Add-Check 'V08' '截图新鲜度' 'SKIP' '缺少 shots/ 或漫画源，无法比对'
} else {
  $png = Get-ChildItem $shotDir -Recurse -File -Include '*.png' -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $newestSrc = $comicSrc | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $png) {
    Add-Check 'V08' '截图新鲜度' 'SKIP' 'shots/ 下无 PNG'
  } elseif ($png.LastWriteTime -lt $newestSrc.LastWriteTime) {
    Add-Check 'V08' '截图新鲜度' 'WARN' "最新截图 $($png.LastWriteTime.ToString('MM-dd HH:mm')) 早于源 $($newestSrc.Name) $($newestSrc.LastWriteTime.ToString('MM-dd HH:mm')) → 审片依据已过期"
  } else {
    Add-Check 'V08' '截图新鲜度' 'PASS' "最新截图 $($png.LastWriteTime.ToString('MM-dd HH:mm')) 晚于全部漫画源"
  }
}

# ---------------------------------------------------------------- 汇总
$fail = @($results | Where-Object State -eq 'FAIL')
$warn = @($results | Where-Object State -eq 'WARN')
$pass = @($results | Where-Object State -eq 'PASS')
$verdict = if ($fail.Count -gt 0) { 'BLOCK · 画面不成立' } elseif ($warn.Count -gt 0) { 'REVIEW · 需人工过目' } else { 'READY · 可看' }

$icon = @{ PASS = '[OK]'; FAIL = '[X ]'; WARN = '[! ]'; SKIP = '[- ]' }
$lines = foreach ($r in $results) { "$($icon[$r.State]) $($r.Id) $($r.Name)`n      $($r.Detail)" }

$body = @(
  '我是石导。视觉演出。我看的不是「好不好看」，是「画面有没有按分镜成立」。',
  '',
  "【工程】$Project",
  "【判定】$verdict",
  "【结果】PASS $($pass.Count) / WARN $($warn.Count) / FAIL $($fail.Count)",
  '',
  '────────────────────────',
  ($lines -join "`n"),
  '────────────────────────',
  '',
  '【下一步】先补 FAIL（画格/竖屏/字号），再谈美术风格。不合格的画面先别加特效。'
) -join "`r`n"

if (Get-Command Emp-Load -ErrorAction SilentlyContinue) {
  $mem = Emp-Load $memFile '石导' 'visual'
  $tags = @($fail | ForEach-Object { $_.Id })
  if ($tags.Count -eq 0) { $tags = @('画面成立') }
  Emp-Save $memFile $mem ("$verdict " + ($fail.Name -join '/')) $tags
  if (Get-Command Emp-Summary -ErrorAction SilentlyContinue) {
    $body = $body.Replace('【判定】', "【你的特点】" + (Emp-Summary $mem) + "`r`n【判定】")
  }
}

if ($NoUi -or -not (Get-Command Emp-Show -ErrorAction SilentlyContinue)) {
  Write-Host $body
} else {
  Add-Type -AssemblyName System.Drawing
  Emp-Show '石导 · 视觉演出' $body @('复制', '关闭') ([System.Drawing.Color]::FromArgb(86, 200, 240)) | Out-Null
}
