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
$memFile = Join-Path $memDir 'lao-duan-memory.json'

# ---------------------------------------------------------------- 工具
function Get-Src {
  param([string]$Proj, [string[]]$Include)
  Get-ChildItem -Path $Proj -Recurse -File -Include $Include -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\chrome-qa[0-9]?\\|\\chrome\\|node_modules|\\.git\\|\\_archive\\' }
}

function Read-First($files) {
  if (-not $files) { return $null }
  $f = @($files)[0]
  return @{ Path = $f.FullName; Text = (Get-Content $f.FullName -Raw -Encoding UTF8) }
}

$results = New-Object System.Collections.ArrayList

function Add-Check {
  param([string]$Id, [string]$Name, [string]$State, [string]$Detail)
  [void]$results.Add([pscustomobject]@{ Id = $Id; Name = $Name; State = $State; Detail = $Detail })
}

# ---------------------------------------------------------------- 01 回溯打点
$eng = Read-First (Get-Src $Project 'engine.js')
if (-not $eng) {
  Add-Check 'S01' '回溯打点' 'SKIP' '未找到 engine.js，跳过'
} else {
  $goTo = [regex]::Match($eng.Text, 'function goTo\([\s\S]*?(?=\n\s*function |\n\s*/\* )').Value
  $inGoTo = $goTo -match 'checkpoint\s*\('
  $all = [regex]::Matches($eng.Text, 'checkpoint\s*\(').Count
  if ($inGoTo) {
    Add-Check 'S01' '回溯打点' 'PASS' "goTo() 内已打点，共 $all 处调用"
  } else {
    Add-Check 'S01' '回溯打点' 'FAIL' "goTo() 内无 checkpoint()，全文件仅 $all 处调用 → 回溯面板只会有 1~2 个可用节点"
  }
}

# ---------------------------------------------------------------- 02 proof() 单一定义
$defs = @()
foreach ($f in (Get-Src $Project '*.js','*.mjs')) {
  $t = Get-Content $f.FullName -Raw -Encoding UTF8
  foreach ($m in [regex]::Matches($t, 'function\s+proof\s*\(\s*\)\s*\{[\s\S]{0,400}?\}')) {
    $ids = [regex]::Matches($m.Value, "'([a-zA-Z][a-zA-Z0-9]+)'") | ForEach-Object { $_.Groups[1].Value }
    $defs += [pscustomobject]@{
      File = $f.Name
      Keys = (@($ids | Select-Object -Unique | Sort-Object) -join ',')
    }
  }
}
if ($defs.Count -eq 0) {
  Add-Check 'S02' 'proof() 单一定义' 'SKIP' '未找到 proof()'
} elseif (($defs.Keys | Select-Object -Unique).Count -gt 1) {
  $rows = ($defs | ForEach-Object { "  · $($_.File): [$($_.Keys)]" }) -join "`n"
  Add-Check 'S02' 'proof() 单一定义' 'FAIL' "存在 $($defs.Count) 份不一致的判定:`n$rows"
} else {
  Add-Check 'S02' 'proof() 单一定义' 'PASS' "唯一判定: [$($defs[0].Keys)]"
}

# ---------------------------------------------------------------- 03 证据可达性
$evIds = @()
if ($eng) {
  $evIds = [regex]::Matches($eng.Text, '(?m)^\s*([a-zA-Z][a-zA-Z0-9]*)\s*:\s*\{\s*id\s*:') |
           ForEach-Object { $_.Groups[1].Value }
}
$pages = Read-First (Get-Src $Project 'pages.js')
$dead = @()
if ($evIds.Count -gt 0 -and $pages) {
  foreach ($id in $evIds) {
    if ($pages.Text -notmatch ("gain\(\s*'" + [regex]::Escape($id) + "'\s*\)") -and
        $pages.Text -notmatch ("gain\(\s*`"?" + [regex]::Escape($id))) {
      $dead += $id
    }
  }
}
if ($evIds.Count -eq 0) {
  Add-Check 'S03' '证据可达性' 'SKIP' '未解析到 EV 表'
} elseif ($dead.Count -gt 0) {
  Add-Check 'S03' '证据可达性' 'FAIL' "$($dead.Count)/$($evIds.Count) 份证据没有任何获得入口 → $(($dead -join ', '))"
} else {
  Add-Check 'S03' '证据可达性' 'PASS' "$($evIds.Count) 份证据均有 gain() 入口"
}

# ---------------------------------------------------------------- 04 存档字段校验
if ($eng) {
  $loadBlock = [regex]::Match($eng.Text, 'function load\([\s\S]*?\n\s*\}').Value
  $verifyEv = $loadBlock -match 'EV\[' -or $loadBlock -match 'has\(|ev\.every|ev\.filter'
  if ($verifyEv) {
    Add-Check 'S04' '存档字段校验' 'PASS' 'load() 会校验证据 id 有效性'
  } else {
    Add-Check 'S04' '存档字段校验' 'FAIL' 'load() 只校验版本号与 alloc 长度，不校验 ev 中的 id → 旧档打开案卷会 TypeError'
  }
}

# ---------------------------------------------------------------- 05 异常被吞
$swallow = 0
foreach ($f in (Get-Src $Project 'engine.js','pages.js','art.js','story.js')) {
  $t = Get-Content $f.FullName -Raw -Encoding UTF8
  $swallow += [regex]::Matches($t, 'catch\s*\([^)]*\)\s*\{\s*console\.error').Count
}
if ($swallow -gt 0) {
  Add-Check 'S05' '异常被吞' 'WARN' "$swallow 处 catch 后仅 console.error → 测试监听 exceptionThrown，永远抓不到"
} else {
  Add-Check 'S05' '异常被吞' 'PASS' '无静默吞异常'
}

# ---------------------------------------------------------------- 06 产物与源同步
$html = Get-ChildItem -Path $Project -Filter '*.html' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '*互动漫画*' } | Select-Object -First 1
$srcJs = Get-Src $Project 'pages.js','engine.js','story.js','art.js','ink.js'
if ($html -and $srcJs) {
  $newest = ($srcJs | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
  if ($newest.LastWriteTime -gt $html.LastWriteTime) {
    Add-Check 'S06' '产物同步' 'FAIL' "源文件比产物新: $($newest.Name) ($($newest.LastWriteTime.ToString('MM-dd HH:mm'))) > html ($($html.LastWriteTime.ToString('MM-dd HH:mm')))"
  } else {
    Add-Check 'S06' '产物同步' 'PASS' '产物不早于源文件'
  }
}

# ---------------------------------------------------------------- 07 版本控制
$git = Test-Path (Join-Path $Project '.git')
if ($git) {
  Add-Check 'S07' '版本控制' 'PASS' '.git 存在'
} else {
  Add-Check 'S07' '版本控制' 'FAIL' '项目根目录无 .git → 无 diff / 无回滚 / 文档与代码漂移不可见'
}

# ---------------------------------------------------------------- 08 工程污染
$junkDirs = Get-ChildItem -Path $Project -Recurse -Directory -Filter 'chrome*' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\_archive\\' }
$junkMB = 0
foreach ($d in $junkDirs) {
  $junkMB += ((Get-ChildItem $d.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
               Measure-Object Length -Sum).Sum / 1MB)
}
if ($junkMB -gt 20) {
  Add-Check 'S08' '工程污染' 'WARN' "$([int]$junkMB) MB 浏览器配置目录进了工程: $(($junkDirs | ForEach-Object Name) -join ', ')"
} else {
  Add-Check 'S08' '工程污染' 'PASS' '未发现体积异常的临时目录'
}

# ---------------------------------------------------------------- 汇总
$fail = @($results | Where-Object State -eq 'FAIL')
$warn = @($results | Where-Object State -eq 'WARN')
$pass = @($results | Where-Object State -eq 'PASS')
$verdict = if ($fail.Count -gt 0) { 'BLOCK · 不可发布' } elseif ($warn.Count -gt 0) { 'CAUTION · 可玩不可发布' } else { 'PASS · 可发布' }

$icon = @{ PASS = '[OK]'; FAIL = '[X ]'; WARN = '[! ]'; SKIP = '[- ]' }
$lines = foreach ($r in $results) {
  "$($icon[$r.State]) $($r.Id) $($r.Name)`n      $($r.Detail)"
}

$body = @(
  '我是老段。验收 QA。我只认能跑出来的结果，不认文档里写的“已修复”。',
  '',
  "【工程】$Project",
  "【判定】$verdict",
  "【结果】PASS $($pass.Count) / WARN $($warn.Count) / FAIL $($fail.Count)",
  '',
  '────────────────────────',
  ($lines -join "`n"),
  '────────────────────────',
  '',
  '【下一步】先修 FAIL，再谈美术。FAIL 项每一条都是“功能说了没做”。'
) -join "`r`n"

# 记忆
if (Get-Command Emp-Load -ErrorAction SilentlyContinue) {
  $mem = Emp-Load $memFile '老段' 'qa'
  $tags = @($fail | ForEach-Object { $_.Id })
  if ($tags.Count -eq 0) { $tags = @('全部通过') }
  Emp-Save $memFile $mem ("$verdict " + ($fail.Name -join '/')) $tags
}

if ($NoUi -or -not (Get-Command Emp-Show -ErrorAction SilentlyContinue)) {
  Write-Host $body
} else {
  Emp-Show '老段 · 验收 QA' $body @('复制', '关闭') ([System.Drawing.Color]::FromArgb(90, 200, 190)) | Out-Null
}
