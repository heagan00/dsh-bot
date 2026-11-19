# BOT 员工总览

| 员工 | 岗位 | 时间 | 任务名 | 说明 |
|---|---|---|---|---|
| **张淑芬** | 知识库更新专员 | 工作日 18:30 更新；19:10 同步；19:15 验收 | `DSH GitHub Weekday Sync` | 知识库、对话、工作区同步 |
| **何大奔** | iCreat / DSH 用量分析师 | 每天 07:00；07:10 出周报/月报 | `何大奔 · iCreat 用量提醒` / `何大奔 · 用量周报月报` | 余额、3 日用量、DSH tokens、人民币日耗/余额、周报月报 |
| **王大力** | 心理抚慰师 | 每天 09:00 启动，每 90–120 分钟；启动即弹 | `王大力 · 心理抚慰师` | 主屏左下角卡片 + 朗读 + 随机 BGM，不抢焦点 |
| **李婶** | BOT 缓存清理员 | 每周二 21:00 | `李婶 · BOT缓存清理` | 清理旧日志/日报/临时文件，不动语音与登录态 |
| **周哥** | 全栈工程师 / 主程 | 每 5 分钟 | `周哥 · 全栈主程巡检` | 扫描活跃会话，优先提醒算力浪费与低效路径 |
| **刘哥** | 全栈工程师 / 主程（复核） | 周哥弹窗时触发 | 无独立任务 | 复核周哥提醒，误报时主屏底部中间提示 |
| **皮特·黄** | 提示词结构工程师 / 主程 | 每 2 分钟；每日 19:30 | `皮特·黄 · 长提示词检查` / `皮特·黄 · 每日提示词库` | 长提示词整理、@阿皮 协同菜单、提示词库分类 |
| **李老师** | HRD / BOT 绩效 | 每天 22:30；周报/月报 | `李老师 · BOT绩效` | 评分、纠偏、JD、记忆录入 |
| **伟痞哥** | VP / 项目与商业 | 每天 21:00 / 22:00 | `伟痞哥 · 项目复盘` / `伟痞哥 · 项目更新` | 项目评分、重点观察、给 HRD 派任务 |
| **阿美** | 美术提示词工程师 | 按需（@阿皮 / 命令行） | 无固定任务 | 美术风格、角色/场景/道具/UI/ICON、wildcards |
| **阿威** | 视频提示词工程师 | 按需（@阿皮 / 命令行） | 无固定任务 | 镜头、动作、运镜、光线、时长、音频 |
| **阿秃** | 代码提示词工程师 | 按需（@阿皮 / 命令行） | 无固定任务 | 目标、技术栈、约束、验收、测试 |
| **阿音** | AI 音乐 / SUNO 提示词工程师 | 按需（@阿皮 / 命令行） | 无固定任务 | 风格、编曲、作词、SUNO Style/Lyrics |
| **老段** | 验收 QA | 按需；每次构建后必跑 | 无固定任务 | 状态机验收：回溯打点、判定一致、证据可达、产物同步 |
| **闻姐** | 叙事一致性审计 | 按需；每次改稿后必跑 | 无固定任务 | 专名、数字、视角、伏笔、占位符一致性 |
| **石导** | 视觉演出导演 | 按需；每次改画面后必跑 | 无固定任务 | 画格覆盖、气泡约束、字号下限、竖屏降级、截图新鲜度 |
| **陈叔** | 音响 / 声音设计 | 按需；改音频后必跑 | 无固定任务 | 起音时机、音效清单落地、音量上限、失焦降噪 |
| **老苍** | 构建与包体 | 按需；发版前必跑 | 无固定任务 | 占位符、产物新鲜度、单文件自包含、包体与调试目录 |
| **小策** | 策划 / 数值与分支 | 按需；改分支后必跑 | 无固定任务 | 资源池口径、结局门槛可达、死选项、页数口径 |

## 分工平等

阿美、阿威、阿秃、阿音与皮特·黄是**平等的 DSH BOT Staff**，只是分工不同：

| 员工 | 领域 | 独立脚本 | 记忆 |
|---|---|---|---|
| **阿美** | 美术提示词 | `amei.ps1` | `memory/amei-memory.json` |
| **阿威** | 视频提示词 | `awei.ps1` | `memory/awei-memory.json` |
| **阿秃** | 代码提示词 | `atu.ps1` | `memory/atu-memory.json` |
| **阿音** | AI 音乐 / SUNO 提示词 | `ayin.ps1` | `memory/ayin-memory.json` |

四位同僚由 `@阿皮` 协同菜单启动，也可用命令行 `-Prompt` 单独调用；不存在上下级，只有领域分工。

### 项目线（六人）

老段、闻姐、石导、陈叔、老苍、小策是**面向具体工程**的验收组：只读工程、只出判定，不改代码，全部支持 `-NoUi`。

| 员工 | 领域 | 独立脚本 | 记忆 |
|---|---|---|---|
| **老段** | 验收 QA / 状态机 | `lao-duan.ps1` | `memory/lao-duan-memory.json` |
| **闻姐** | 叙事一致性 | `wen-jie.ps1` | `memory/wen-jie-memory.json` |
| **石导** | 视觉演出 / 分镜 | `shi-dao.ps1` | `memory/shi-dao-memory.json` |
| **陈叔** | 音响 / WebAudio | `chen-shu.ps1` | `memory/chen-shu-memory.json` |
| **老苍** | 构建 / 包体 | `lao-cang.ps1` | `memory/lao-cang-memory.json` |
| **小策** | 策划 / 数值与分支 | `xiao-ce.ps1` | `memory/xiao-ce-memory.json` |

六人用 `-Project` 指定要验收的工程，默认指向 `fable_projt_test01`。他们共用 `employees/employee-lib.ps1` 的记忆与卡片库，但不占用阿美/阿威/阿秃/阿音的领域。

## 文件

- 张淑芬：[BOT.md](BOT.md)、[weekday-sync.ps1](weekday-sync.ps1)、[run-weekday-sync.cmd](run-weekday-sync.cmd)
- 何大奔：[HE-DABEN.md](HE-DABEN.md)、[icreat-usage.ps1](icreat-usage.ps1)、[he-daben.cmd](he-daben.cmd)
- 王大力：[WANG-DALI.md](WANG-DALI.md)、[wang-dali.ps1](wang-dali.ps1)、[wang-dali-tips.json](wang-dali-tips.json)、[wang-dali.cmd](wang-dali.cmd)、[audio/](audio/)
- 老段：[LAO-DUAN.md](lao-duan/LAO-DUAN.md)、[lao-duan.ps1](lao-duan/lao-duan.ps1)
- 闻姐：[WEN-JIE.md](wen-jie/WEN-JIE.md)、[wen-jie.ps1](wen-jie/wen-jie.ps1)
- 石导：[SHI-DAO.md](shi-dao/SHI-DAO.md)、[shi-dao.ps1](shi-dao/shi-dao.ps1)
- 陈叔：[CHEN-SHU.md](chen-shu/CHEN-SHU.md)、[chen-shu.ps1](chen-shu/chen-shu.ps1)
- 老苍：[LAO-CANG.md](lao-cang/LAO-CANG.md)、[lao-cang.ps1](lao-cang/lao-cang.ps1)
- 小策：[XIAO-CE.md](xiao-ce/XIAO-CE.md)、[xiao-ce.ps1](xiao-ce/xiao-ce.ps1)

## 原则

- 有固定周期的 BOT 走 Windows 计划任务；按需同僚由 `@阿皮` / 命令行调用。
- 所有 BOT 都有独立脚本和独立记忆，地位平等，只是分工不同。
- 登录态、Cookie、token 只在本机，不进 Git。
- 大文件/语音缓存按需放本机；当前王大力 MP3/BGM 已随仓库同步。
- 李婶**无权**处理 `prompt-library/` 和 `sync/memory/`；只清理缓存与备份 BOT/skills/plugins。
- 任务为 Interactive only：PC 开机且已登录才运行。
- 项目线六人（老段/闻姐/石导/陈叔/老苍/小策）只读工程、不改代码；`-NoUi` 用于 CI 或脚本串联。

> 所有弹窗（含 ×）都必须由 heagan00 手动点击，BOT 不会自动关闭；刘哥关闭还需二次确认。


