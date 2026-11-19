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
$memFile = Join-Path $memDir 'wen-jie-memory.json'

# ---------------------------------------------------------------- 语料
$files = Get-ChildItem -Path $Project -Recurse -File -Include '*.js','*.md','*.html' -ErrorAction SilentlyContinue |
         Where-Object {
           $_.FullName -notmatch '\\chrome-qa[0-9]?\\|\\chrome\\|node_modules|\\.git\\|\\_archive\\|\\art_render\\|\\bots\\' -and
           $_.Length -lt 2MB
         }

$corpus = @()
foreach ($f in $files) {
  $t = Get-Content $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
  if ($t) { $corpus += [pscustomobject]@{ Name = $f.Name; Path = $f.FullName; Text = $t } }
}
function Hit($re) {
  $out = @()
  foreach ($c in $corpus) {
    $m = [regex]::Matches($c.Text, $re)
    if ($m.Count -gt 0) { $out += [pscustomobject]@{ File = $c.Name; Count = $m.Count } }
  }
  return $out
}
function Total($hits) { if (-not $hits) { return 0 }; return ($hits | Measure-Object Count -Sum).Sum }

$results = New-Object System.Collections.ArrayList
function Add-R { param($Id, $Name, $State, $Detail) [void]$results.Add([pscustomobject]@{ Id = $Id; Name = $Name; State = $State; Detail = $Detail }) }

# ---------------------------------------------------------------- N01 专名
$names = '邵岚', '韦岸', '宁砚'
$missing = @()
foreach ($n in $names) {
  $h = Hit ([regex]::Escape($n))
  if ((Total $h) -eq 0) { $missing += $n }
}
if ($missing.Count -eq 0) {
  Add-R 'N01' '专名一致性' 'PASS' '三名调查员均已具名出现'
} elseif ($missing.Count -eq $names.Count) {
  Add-R 'N01' '专名一致性' 'FAIL' '邵岚/韦岸/宁砚 全部 0 次出现 —— 审查清单称「已补角色卡」，实际未落地'
} else {
  Add-R 'N01' '专名一致性' 'WARN' "缺失: $($missing -join '、')"
}

# ---------------------------------------------------------------- N02 数字冲突
$three = Total (Hit '林知微三次|三次要求核验|三次提出独立核验')
$four  = Total (Hit '林知微四次|四次申请独立核验')
if ($three -gt 0 -and $four -gt 0) {
  Add-R 'N02' '核验次数冲突' 'FAIL' "同一事实并存「三次」($three 处) 与「四次」($four 处) —— 玩家能看见的那版是三次"
} elseif ($three -gt 0 -or $four -gt 0) {
  Add-R 'N02' '核验次数冲突' 'PASS' "口径统一（三次=$three / 四次=$four）"
} else {
  Add-R 'N02' '核验次数冲突' 'SKIP' '未匹配到核验次数表述'
}

# ---------------------------------------------------------------- N03 视角越界
$internal = Hit '司南在案件处理记录中|认知竞争威胁：已消除|既定策略目标：达成'
if ($internal) {
  $where = ($internal | ForEach-Object { "$($_.File)×$($_.Count)" }) -join ', '
  Add-R 'N03' '结局A视角越界' 'FAIL' "结局 A 出现司南内部记录 ($where) —— 玩家此时没有任何司南证据"
} else {
  Add-R 'N03' '结局A视角越界' 'PASS' '未发现结局 A 的上帝视角泄漏'
}

# ---------------------------------------------------------------- N04 未回收伏笔
$ring = Total (Hit '婚戒')
if ($ring -eq 0) {
  Add-R 'N04' '婚戒未回收' 'FAIL' '婚戒 0 次出现 —— 清单 #11 称「已在 HTML 中实现」，实际未落地'
} elseif ($ring -lt 2) {
  Add-R 'N04' '婚戒未回收' 'WARN' "婚戒仅出现 $ring 次，不足以形成「出现→回收」闭环"
} else {
  Add-R 'N04' '婚戒未回收' 'PASS' "婚戒出现 $ring 次，具备回收条件"
}

# ---------------------------------------------------------------- N05 设定冲突
$threat = Total (Hit '生成威胁推演')
$lure   = Total (Hit '文明大同|我们不征服|我们只是邀请')
if ($threat -gt 0 -and $lure -gt 0) {
  Add-R 'N05' '设定冲突' 'FAIL' "核心改写是「大同诱饵」，但时间轴仍写「生成威胁推演」($threat 处) —— 改写最锋利处被自己的插图否定"
} else {
  Add-R 'N05' '设定冲突' 'PASS' '威胁框架与诱饵框架未并存'
}

# ---------------------------------------------------------------- N06 占位符
$ph = Total (Hit 'TODO|待定|XXX|待补|占位')
if ($ph -gt 0) {
  Add-R 'N06' '占位符残留' 'WARN' "$ph 处未完成标记"
} else {
  Add-R 'N06' '占位符残留' 'PASS' '无占位符'
}

# ---------------------------------------------------------------- N07 命名漂移
$gen = Total (Hit '调查员0[123]')
if ($gen -gt 0) {
  Add-R 'N07' '命名漂移' 'WARN' "$gen 处使用「调查员01/02/03」而非具名角色 —— 玩家记不住编号"
} else {
  Add-R 'N07' '命名漂移' 'PASS' '人物称谓统一'
}

# ---------------------------------------------------------------- 汇总
$fail = @($results | Where-Object State -eq 'FAIL')
$warn = @($results | Where-Object State -eq 'WARN')
$verdict = if ($fail.Count -gt 0) { 'CONFLICT · 有未落地项' } elseif ($warn.Count -gt 0) { 'REVIEW · 需人工确认' } else { 'CLEAN · 一致' }
$icon = @{ PASS = '[OK]'; FAIL = '[X ]'; WARN = '[! ]'; SKIP = '[- ]' }

$lines = foreach ($r in $results) { "$($icon[$r.State]) $($r.Id) $($r.Name)`n      $($r.Detail)" }
$body = @(
  '我是闻姐。叙事一致性审计。我不改剧情，我只指出「说的和做的不一致」。',
  '',
  "【工程】$Project",
  "【判定】$verdict",
  "【语料】$($corpus.Count) 个文件",
  '',
  '────────────────────────',
  ($lines -join "`n"),
  '────────────────────────',
  '',
  '【提醒】审查清单里每一条「已修复」，都必须能被 grep 出来。查不到就等于没修。'
) -join "`r`n"

if (Get-Command Emp-Load -ErrorAction SilentlyContinue) {
  $mem = Emp-Load $memFile '闻姐' 'lore'
  $tags = @($fail | ForEach-Object { $_.Id }); if ($tags.Count -eq 0) { $tags = @('一致') }
  Emp-Save $memFile $mem ("$verdict " + ($fail.Name -join '/')) $tags
}

if ($NoUi -or -not (Get-Command Emp-Show -ErrorAction SilentlyContinue)) { Write-Host $body }
else { Emp-Show '闻姐 · 叙事一致性' $body @('复制', '关闭') ([System.Drawing.Color]::FromArgb(214, 168, 92)) | Out-Null }
