# 皮特·黄 · 提示词结构工程师

| 项 | 内容 |
|---|---|
| 名字 | 皮特·黄（“秉笔太监”） |
| 岗位 | 提示词结构工程师 / 主程 |
| 触发 | 输入框监听：`@阿皮` 立即弹菜单；超长输入（≥100 字且停顿 ≥1.2 秒）立即弹整理卡 |
| 位置 | 主屏左下角，必须手动关闭 |
| 常驻 | 登录启动项 `PieterInputWatch`（无计划任务） |
| 日报库 | 每天 19:30，任务 `皮特·黄 · 每日提示词库` |
| 文件 | `pieter-huang.ps1`、`pieter-input-watch.ps1`、`tools/prompt-watch.mjs`、`tools/prompt-library.mjs`、`tools/prompt-guess.mjs` |

> 已经没有 `皮特·黄 · 长提示词检查` 这个每 2 分钟的计划任务了：长提示词改由输入框监听器在**发送前**发现并唤起。

## 怎么跑

一个常驻监听器 `pieter-input-watch.ps1` 每 **400 毫秒**用 UI Automation 读一次 DSH 输入框，命中两种情形就立刻拉起 `pieter-huang.ps1`（不用等消息发出去）：

| 输入框状态 | 动作 |
|---|---|
| 出现 `@阿皮` | 立刻弹 `DSH BOT Staff · 协同` 菜单 |
| 超长提示词（去掉 `@阿皮` 后 ≥**100** 字，且连续 **3** 个轮询周期没有变化，约 1.2 秒停顿） | 立刻弹「需要秉笔太监整理吗」 |

- 同一段文字只弹一次：监听器按内容哈希记忆已弹过的文本，输入框清空或删短后才重新待命。
- `@阿皮` 同样有边沿触发：**被删掉之后**才会再次弹菜单，避免连续刷屏。
- 文本通过临时文件 `logs/pieter-input-last.txt` 传给主脚本，不走命令行参数，长文本和换行不会被截断。

## 长提示词

弹窗：

```text
官家，需要秉笔太监皮特·黄为您整理提示词吗？
[要] [否] [30分钟内不再出现]
```

- **要**：显示结构化后的提示词（七段模板），可复制
- **否**：关闭
- **30分钟内不再出现**：输入框静音 30 分钟（记在 `logs/pieter-huang-state.json` 的 `__composer__` 键上；输入框侧没有会话 id，静音按整个输入框算）

弹之前先把这条内容的 id 写进 `processed`，所以同一段文字不会再烦你第二次。

## 怎么判断（会话日志侧，手动补扫用）

不传任何参数直接跑 `pieter-huang.ps1` 时，走会话日志扫描，规则是：

- 只挑**真实用户输入**，丢掉太短的（<100 字）和系统注入的噪声（`system-reminder`、工作目录提示、技能清单等）
- 按消息 id 去重，按时间取**最近 5 条**，只处理**第一条命中**
- 弹之前先把 id 记进 `processed`，所以不会重复烦你
- 会话已静音（30 分钟内点过“不再出现”）就跳过

这条路径以前由每 2 分钟的 `schtasks` 轮询，现在**不再注册计划任务**，只在手动补扫或脚本串联时用。

## @阿皮

提示词里出现 `@阿皮` 时，直接弹子菜单：

```text
[优化提示词] [阿美] [阿威] [阿秃] [阿音] [取消]
```

| 同僚 | 职责 |
|---|---|
| **阿美** | 美术教授 / 天美美术总监视角；整理角色、场景、道具、UI、ICON、插画、分镜、关键帧；支持 wildcards 随机 |
| **阿威** | 视频生成提示词；镜头、动作、运镜、光线、时长、音频 |
| **阿秃** | 代码提示词；目标、技术栈、输入、约束、验收、测试 |
| **阿音** | AI 音乐 / SUNO；风格、编曲、作词、Style/Lyrics |

四位同僚是**平等的独立 bot**，由 `@阿皮` 协同菜单启动，各自有独立记忆；不是上下级，只是领域分工：

- 阿美：`employees/amei.ps1` → `memory/amei-memory.json`
- 阿威：`employees/awei.ps1` → `memory/awei-memory.json`
- 阿秃：`employees/atu.ps1` → `memory/atu-memory.json`
- 阿音：`employees/ayin.ps1` → `memory/ayin-memory.json`

选中同僚时用 `Start-Process` 把对应的独立脚本拉起来，并把你的原文传过去（`-Prompt`）；脚本没装才回落到本文件内置的模板卡。

它们不会各自起空白定时器；只在被请来协作时工作，避免空转占算力。

## 每日提示词库

每天 19:30 扫描当日活跃会话，按以下层级落盘：

```text
prompt-library/
├─ task/
├─ vibcoding/
├─ video/
└─ art/
   ├─ character/{realistic,cartoon,anime,stylized}/
   ├─ scene/{...}/
   ├─ props/{...}/
   ├─ ui/{...}/
   ├─ icon/{...}/
   ├─ illustration/{...}/
   ├─ storyboard/{...}/
   └─ keyframe/{...}/
```

分类靠关键词打分：**每命中一个词 +2**，被 `@阿美` / `@阿威` / `@阿秃` 点名直接 **+10**；大类胜出后对美术再细分到 8 类 × 4 风格的子目录，落成带 YAML 头的 md。

索引：`prompt-library/index.md`、`index.json`。

## 高频词猜词

只在**英文输入法**下出现；中文输入法直接跳过（用 Win32 取前台窗口键盘布局判定，`primary == 0x09` 才算英文）。这是故意的，免得在中文输入时乱猜。

```cmd
powershell.exe -NoProfile -File "prompt-guess.ps1" -Text="做一个卡通宝箱图标"
```

输出：候选分类、命中词、建议补充的维度。用于先把模糊提示词猜到一个一级分类，再细分类。

测试时可加 `-Force` 强制运行；直接跑 Node 需要 `--ime=en`。

`index.json` 同时保存分类计数和 top 高频词；分类采用加权命中，不是“第一个关键词命中就归类的单规则”。

## Wildcards

参考 AUTOMATIC1111 wildcards 扩展的机制复现：

- `__style__` → 从 `wildcards/style.txt` 随机取一行
- 子目录：`__art/color__` → `wildcards/art/color.txt`
- 嵌套：选中的行里继续展开 `__lighting__`
- 内联：`{red|blue|green}` 随机取一个
- 阿美每次“换一组”都会重新随机，组合不固定

词库在 `prompt-library/wildcards/`，可直接加 `.txt` 文件扩展。

## 参数

| 参数 | 作用 |
|---|---|
| `-Test` | 只弹一张测试卡，验界面用 |
| `-ForceMention` | 直接弹协同菜单（监听器命中 `@阿皮` 时用） |
| `-LongPrompt` | 直接走长提示词整理卡（监听器命中超长输入时用） |
| `-Prompt <文本>` | 直接给原文；留空则读剪贴板 |
| `-PromptFile <路径>` | 从文件读原文（监听器用这条，避免长文本被命令行截断） |

监听器参数：`-IntervalMs`（默认 400）、`-MinLongChars`（默认 100）、`-StablePolls`（默认 3）。

## 启动

登录启动项（当前用户，无需管理员）：

```text
HKCU\Software\Microsoft\Windows\CurrentVersion\Run
PieterInputWatch = "C:\Users\EDY\Downloads\ComfyUI相关\sync\pieter-input-watch.cmd"
```

**只需这一个常驻项**；`皮特·黄 · 长提示词检查` 的 `schtasks` 注册可以删掉了：

```cmd
schtasks /Delete /TN "皮特·黄 · 长提示词检查" /F
```

## 手动

```cmd
schtasks /Run /TN "皮特·黄 · 每日提示词库"
powershell.exe -NoProfile -STA -File "pieter-huang.ps1" -Test
powershell.exe -NoProfile -STA -File "pieter-huang.ps1" -LongPrompt -Prompt "（一百字以上的提示词）"
powershell.exe -NoProfile -STA -File "pieter-huang.ps1"          # 手动补扫一次会话日志
```
