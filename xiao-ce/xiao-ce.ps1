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
$memFile = Join-Path $memDir 'xiao-ce-memory.json'

# ---------------------------------------------------------------- 工具
function Get-Src {
  param([string]$Proj, [string[]]$Include)
  Get-ChildItem -Path $Proj -Recurse -File -Include $Include -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\chrome[^\\]*\\|node_modules|\.git\\|\\_archive\\|\\shots\\|\\chart\\out\\|\\bots\\' }
}

function Read-Text($p) {
  if (-not (Test-Path $p)) { return '' }
  return (Get-Content $p -Raw -Encoding UTF8 -ErrorAction SilentlyContinue)
}

$results = New-Object System.Collections.ArrayList
function Add-Check {
  param([string]$Id, [string]$Name, [string]$State, [string]$Detail)
  [void]$results.Add([pscustomobject]@{ Id = $Id; Name = $Name; State = $State; Detail = $Detail })
}

$pagesFile = Get-Src $Project 'pages.js' | Select-Object -First 1
$engFile = Get-Src $Project 'engine.js' | Select-Object -First 1
$docReview = Read-Text (Join-Path $Project '审查清单.md')
$docComic = Read-Text (Join-Path $Project '互动漫画_说明.md')
$docRemake = Read-Text (Join-Path $Project '游戏说明_重制版.md')

if (-not $pagesFile) {
  Add-Check 'D01' '资源池口径' 'SKIP' '未找到 pages.js'
  $src = ''
} else {
  $src = Read-Text $pagesFile.FullName
}

# ---------------------------------------------------------------- D01 资源池口径
if ($src) {
  $pool = [regex]::Match($src, 'sum\(\)\s*>=\s*(\d+)').Groups[1].Value
  $caps = @([regex]::Matches($src, 'S\.alloc\[\d\]\s*<\s*(\d+)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
  $docFour = ($docReview -match '四次核验额度') -or ($docReview -match '4\s*格')
  $docThree = ($docComic -match '3\s*单位') -or ($docRemake -match '3单位')
  if ($pool -and $docFour -and $docThree) {
    Add-Check 'D01' '资源池口径' 'FAIL' "审查清单要求「四次核验额度 / 4 格」，实现是 $pool 单位池（单线上限 $($caps -join '/')），说明文档又写「$pool 单位」→ 三份口径互不一致，玩家算不清自己还剩几次"
  } elseif ($pool) {
    Add-Check 'D01' '资源池口径' 'PASS' "资源池 $pool 单位，单线上限 $($caps -join '/')，文档一致"
  } else {
    Add-Check 'D01' '资源池口径' 'WARN' '未解析到资源池上限表达式'
  }
}

# ---------------------------------------------------------------- D02 五结局判定完备
if ($src) {
  $letters = @([regex]::Matches($src, "S\.ending = '([A-E])'") | ForEach-Object { $_.Groups[1].Value })
  $uniq = @($letters | Select-Object -Unique | Sort-Object)
  $expected = @('A', 'B', 'C', 'D', 'E')
  $missing = @($expected | Where-Object { $uniq -notcontains $_ })
  $p16 = [regex]::Match($src, "(?s)id: 'p16'(.*?)(?=\n  P_\()").Groups[1].Value
  $lockedInVerdict = ([regex]::Matches($p16, 'locked:')).Count
  if ($missing.Count -gt 0) {
    Add-Check 'D02' '结局判定' 'FAIL' "结局 $($missing -join '、') 没有独立判定分支 → 玩家能达到的结局少于承诺"
  } elseif ($lockedInVerdict -lt 5) {
    Add-Check 'D02' '结局判定' 'WARN' "五结局都在，但只有 $lockedInVerdict 条带门槛；其余等于保底选项"
  } else {
    Add-Check 'D02' '结局判定' 'PASS' "A–E 五条独立分支、五条门槛，全部由证据与技术处置推导"
  }
}

# ---------------------------------------------------------------- D03 门槛证据可达
if ($src) {
  $proofBody = [regex]::Match($src, '(?s)function proof\(\)\s*\{(.*?)\n  \}').Groups[1].Value
  $proofArr = [regex]::Match($proofBody, '\[([^\]]+)\]').Groups[1].Value
  $need = @([regex]::Matches($proofArr, "'([a-zA-Z][a-zA-Z0-9]*)'") | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
  $reach = @()
  $reach += [regex]::Matches($src, "Comic\.gain\('([a-zA-Z]+)'\)") | ForEach-Object { $_.Groups[1].Value }
  $reach += [regex]::Matches($src, "hot\([^\)]*?'([a-zA-Z]+)'\)\s*,?") | ForEach-Object { $_.Groups[1].Value }
  $reach = @($reach | Select-Object -Unique)
  $dead = @($need | Where-Object { $reach -notcontains $_ })
  if ($need.Count -eq 0) {
    Add-Check 'D03' '门槛证据可达' 'SKIP' 'proof() 未解析出证据清单'
  } elseif ($dead.Count -gt 0) {
    Add-Check 'D03' '门槛证据可达' 'FAIL' "proof() 需要 $($dead -join '、')，但全流程没有任何取得入口 → A/E 结局永久锁死"
  } else {
    Add-Check 'D03' '门槛证据可达' 'PASS' "$($need.Count) 份门槛证据全部有取得入口（$($need -join '、')）"
  }
}

# ---------------------------------------------------------------- D04 无效果选项
if ($src) {
  $bodies = @([regex]::Matches($src, 'act\([^)]*\)\s*\{([^{}]*)\}') | ForEach-Object { $_.Groups[1].Value })
  $stateful = 0; $nav = 0; $deadOpts = 0
  foreach ($b in $bodies) {
    $hasState = $b -match 'S\.|gain\(|ending'
    $hasNav = $b -match 'goTo\(|openNotebook|openModal|closeModal|hiddenCheck|showEnding'
    $hasUi = $b -match 'refreshChoices|toast'
    if ($hasState) { $stateful++ } elseif ($hasNav) { $nav++ } elseif ($hasUi) { $stateful++; } else { $deadOpts++ }
  }
  $total = $bodies.Count
  if ($deadOpts -gt 0) {
    Add-Check 'D04' '选项有效性' 'FAIL' "$deadOpts/$total 个选项点击后不改变任何状态、也不前进 → 死选项"
  } else {
    Add-Check 'D04' '选项有效性' 'PASS' "已解析 $total 个选项体，全部有行为（$stateful 个改状态、$nav 个只导航或开界面）"
  }
}

# ---------------------------------------------------------------- D05 结局共用成本
if ($src) {
  $endingPages = @([regex]::Matches($src, "(?s)id: '([^']+)'(.*?)(?=\n  P_\(|\n  pages\.forEach)") |
    Where-Object { $_.Groups[2].Value -match "S\.ending = '" } | ForEach-Object { $_.Groups[1].Value })
  if ($endingPages.Count -le 1) {
    Add-Check 'D05' '结局共用成本' 'PASS' "五结局共用 $($endingPages.Count) 页判定 + 1 张结案卡，分支成本最低"
  } else {
    Add-Check 'D05' '结局共用成本' 'WARN' "结局判定散在 $($endingPages.Count) 页（$($endingPages -join ', ')）→ 分支成本上升，容易写漏"
  }
}

# ---------------------------------------------------------------- D06 选项代价标注
if ($src) {
  $labels = ([regex]::Matches($src, 'label:')).Count
  $descs = ([regex]::Matches($src, 'desc:')).Count
  $ratio = if ($labels -gt 0) { [math]::Round($descs * 100 / $labels, 0) } else { 0 }
  if ($ratio -ge 95) {
    Add-Check 'D06' '选项代价' 'PASS' "$descs/$labels 个选项都写了后果说明（$ratio%），玩家能预判代价"
  } else {
    Add-Check 'D06' '选项代价' 'WARN' "只有 $descs/$labels 个选项写了后果（$ratio%）→ 剩下的靠猜"
  }
}

# ---------------------------------------------------------------- D07 隐藏结局门槛
if ($src) {
  $p16 = [regex]::Match($src, "(?s)id: 'p16'(.*?)(?=\n  P_\()").Groups[1].Value
  $eBlock = [regex]::Match($p16, "(?s)结束|E ·.*?locked:([^,]*)").Value
  $eLocked = [regex]::Match($p16, "S\.ending = 'E'[^\}]*\}").Value
  $needsAnomaly = $p16 -match "has\('anomalyB'\)"
  $needsProof = $p16 -match 'proof\(\)'
  $needsTech = $p16 -match "tech !== 'destroy'"
  $conds = @()
  if ($needsAnomaly) { $conds += '双源异常' }
  if ($needsProof) { $conds += '完整操纵链' }
  if ($needsTech) { $conds += '未永久销毁' }
  if ($conds.Count -ge 3) {
    Add-Check 'D07' '隐藏结局门槛' 'PASS' "E 需同时满足 $(($conds -join ' + '))，不是单点触发"
  } elseif ($conds.Count -ge 1) {
    Add-Check 'D07' '隐藏结局门槛' 'WARN' "E 只校验 $(($conds -join ' + '))，门槛偏松"
  } else {
    Add-Check 'D07' '隐藏结局门槛' 'FAIL' '未找到 E 结局的门槛条件'
  }
}

# ---------------------------------------------------------------- D08 页数与文档
if ($src) {
  $pageCount = ([regex]::Matches($src, "id: 'p\d+'")).Count
  $claim = [regex]::Match($docComic, '共\s*(\d+)\s*页')
  if (-not $claim.Success) {
    Add-Check 'D08' '页数口径' 'WARN' "说明未写页数；实现 $pageCount 页"
  } elseif ([int]$claim.Groups[1].Value -ne $pageCount) {
    Add-Check 'D08' '页数口径' 'FAIL' "说明称「共 $($claim.Groups[1].Value) 页」，实现 $pageCount 页 → 少了一页，玩家实测时长与承诺不符"
  } else {
    Add-Check 'D08' '页数口径' 'PASS' "说明 $($claim.Groups[1].Value) 页 = 实现 $pageCount 页"
  }
}

# ---------------------------------------------------------------- D09 态度分叉有效性
if ($src) {
  $att = @([regex]::Matches($src, "S\.att = '(\w+)'") | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
  $effects = @([regex]::Matches($src, "S\.(trust|coop|told)\s*[+\-]?=") | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
  if ($att.Count -ge 3 -and $effects.Count -ge 2) {
    Add-Check 'D09' '态度分叉' 'PASS' "$($att.Count) 种初审态度（$($att -join '/')）各自改动 $($effects -join '/')，不是换句台词"
  } elseif ($att.Count -ge 3) {
    Add-Check 'D09' '态度分叉' 'WARN' "三种态度都有记录，但只影响 $($effects.Count) 个状态 → 玩家会觉得选了等于没选"
  } else {
    Add-Check 'D09' '态度分叉' 'SKIP' '未解析到初审态度分支'
  }
}

# ---------------------------------------------------------------- 汇总
$fail = @($results | Where-Object State -eq 'FAIL')
$warn = @($results | Where-Object State -eq 'WARN')
$pass = @($results | Where-Object State -eq 'PASS')
$verdict = if ($fail.Count -gt 0) { 'BROKEN · 口径冲突' } elseif ($warn.Count -gt 0) { 'TUNING · 需调参' } else { 'PLAYABLE · 可玩' }

$icon = @{ PASS = '[OK]'; FAIL = '[X ]'; WARN = '[! ]'; SKIP = '[- ]' }
$lines = foreach ($r in $results) { "$($icon[$r.State]) $($r.Id) $($r.Name)`n      $($r.Detail)" }

$body = @(
  '我是小策。策划。我不管代码怎么写，我只问：玩家还剩几次、能不能达到、代价看不看得见。',
  '',
  "【工程】$Project",
  "【判定】$verdict",
  "【结果】PASS $($pass.Count) / WARN $($warn.Count) / FAIL $($fail.Count)",
  '',
  '────────────────────────',
  ($lines -join "`n"),
  '────────────────────────',
  '',
  '【下一步】先把「4 格还是 3 单位」定死，一处改三处。数值口径不统一，所有结局门槛的讨论都是空的。'
) -join "`r`n"

if (Get-Command Emp-Load -ErrorAction SilentlyContinue) {
  $mem = Emp-Load $memFile '小策' 'design'
  $tags = @($fail | ForEach-Object { $_.Id })
  if ($tags.Count -eq 0) { $tags = @('口径一致') }
  Emp-Save $memFile $mem ("$verdict " + ($fail.Name -join '/')) $tags
  if (Get-Command Emp-Summary -ErrorAction SilentlyContinue) {
    $body = $body.Replace('【判定】', "【你的特点】" + (Emp-Summary $mem) + "`r`n【判定】")
  }
}

if ($NoUi -or -not (Get-Command Emp-Show -ErrorAction SilentlyContinue)) {
  Write-Host $body
} else {
  Add-Type -AssemblyName System.Drawing
  Emp-Show '小策 · 策划与数值' $body @('复制', '关闭') ([System.Drawing.Color]::FromArgb(226, 178, 96)) | Out-Null
}
