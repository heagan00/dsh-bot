# DSH BOT Staff

十九个本地自动化 BOT 的源码与资源。固定周期任务走 Windows 计划任务；按需同僚由 `@阿皮` / 命令行调用。

| BOT | 岗位 | 时间 | 任务名 |
|---|---|---|---|
| **张淑芬** | 知识库更新专员 | 工作日 18:30 更新 / 19:10 同步 / 19:15 验收 | `DSH GitHub Weekday Sync` |
| **何大奔** | iCreat 用量分析师 | 每天 07:00 | `何大奔 · iCreat 用量提醒` |
| **王大力** | 心理抚慰师 | 每天 09:00 启动，每 90–120 分钟，启动即弹 | `王大力 · 心理抚慰师` |
| **李婶** | BOT 缓存清理员 | 每周二 21:00 | `李婶 · BOT缓存清理` |
| **周哥** | 全栈工程师 / 主程 | 每 5 分钟（仅有正在回答的对话时巡检） | `周哥 · 全栈主程巡检` |
| **刘哥** | 全栈工程师 / 主程（复核） | 周哥弹窗时触发 | 无独立任务 |
| **皮特·黄** | 提示词结构工程师 / 主程 | 每 2 分钟；每日 19:30 | `皮特·黄 · 长提示词检查` / `皮特·黄 · 每日提示词库` |
| **李老师** | HRD / BOT 绩效 | 每天 22:30；周报/月报 | `李老师 · BOT绩效` |
| **伟痞哥** | VP / 项目与商业 | 每天 21:00 / 22:00 | `伟痞哥 · 项目复盘` / `伟痞哥 · 项目更新` |
| **阿美** | 美术提示词工程师 | 按需（@阿皮 / 命令行） | 独立 bot |
| **阿威** | 视频提示词工程师 | 按需（@阿皮 / 命令行） | 独立 bot |
| **阿秃** | 代码提示词工程师 | 按需（@阿皮 / 命令行） | 独立 bot |
| **阿音** | AI 音乐 / SUNO 提示词工程师 | 按需（@阿皮 / 命令行） | 独立 bot |
| **老段** | 验收 QA | 按需；每次构建后必跑 | 独立 bot |
| **闻姐** | 叙事一致性审计 | 按需；每次改稿后必跑 | 独立 bot |
| **石导** | 视觉演出导演 | 按需；每次改画面后必跑 | 独立 bot |
| **陈叔** | 音响 / 声音设计 | 按需；改音频后必跑 | 独立 bot |
| **老苍** | 构建与包体 | 按需；发版前必跑 | 独立 bot |
| **小策** | 策划 / 数值与分支 | 按需；改分支后必跑 | 独立 bot |

> 阿美、阿威、阿秃、阿音与皮特·黄是平等的 BOT Staff，只是领域分工不同；每人独立脚本、独立记忆。

> 老段、闻姐、石导、陈叔、老苍、小策是项目线验收组：只读工程、只出判定，均支持 `-NoUi`。

## 目录

```text
zhang-shufeng/   BOT.md, weekday-sync.ps1, run-weekday-sync.cmd
he-daben/        HE-DABEN.md, icreat-usage.ps1, he-daben.cmd
wang-dali/       WANG-DALI.md, wang-dali.ps1, tips, audio/, voice/
li-shen/         LI-SHEN.md, li-shen-cleanup.ps1, li-shen.cmd
zhou-ge/         ZHOU-GE.md, zhou-ge.ps1, zhou-ge.cmd
liu-ge/          LIU-GE.md, liu-ge.ps1, liu-ge.cmd
pieter-huang/    PIETER-HUANG.md, pieter-huang.ps1, employees docs, prompt library scripts
employees/       amei.ps1 / awei.ps1 / atu.ps1 / ayin.ps1 + employee-lib
li-teacher/      HRD 绩效评分与报告
wei-pi-ge/       VP 项目评分与目标更新
lao-duan/        LAO-DUAN.md, lao-duan.ps1（验收 QA · 状态机）
wen-jie/         WEN-JIE.md, wen-jie.ps1（叙事一致性审计）
shi-dao/         SHI-DAO.md, shi-dao.ps1（视觉演出 / 分镜）
chen-shu/        CHEN-SHU.md, chen-shu.ps1（音响 / WebAudio）
lao-cang/        LAO-CANG.md, lao-cang.ps1（构建 / 包体）
xiao-ce/         XIAO-CE.md, xiao-ce.ps1（策划 / 数值与分支）
prompt-library/  wildcards/ 词库（生成内容默认不进 Git）
tools/           iCreat 登录态读取/调试脚本
```

## 安装

1. 克隆/复制到本机。
2. 按需修改脚本里的路径（`$kb`、`$conv`、`$ws`，以及 `~/.icreat/token.txt`）。
3. 注册计划任务（需要当前用户已登录）：

```cmd
schtasks /Create /TN "DSH GitHub Weekday Sync" /TR "C:\path\to\zhang-shufeng\run-weekday-sync.cmd" /SC WEEKLY /D MON,TUE,WED,THU,FRI /ST 19:10 /F
schtasks /Create /TN "何大奔 · iCreat 用量提醒" /TR "C:\path\to\he-daben\he-daben.cmd" /SC DAILY /ST 07:00 /F
schtasks /Create /TN "王大力 · 心理抚慰师" /TR "C:\path\to\wang-dali\wang-dali.cmd" /SC DAILY /ST 09:00 /F
schtasks /Create /TN "李婶 · BOT缓存清理" /TR "C:\path\to\li-shen\li-shen.cmd" /SC WEEKLY /D TUE /ST 21:00 /F
schtasks /Create /TN "周哥 · 全栈主程巡检" /TR "C:\path\to\zhou-ge\zhou-ge.cmd" /SC MINUTE /MO 5 /F
schtasks /Create /TN "皮特·黄 · 长提示词检查" /TR "C:\path\to\pieter-huang\pieter-huang.cmd" /SC MINUTE /MO 2 /F
schtasks /Create /TN "皮特·黄 · 每日提示词库" /TR "C:\path\to\pieter-huang\prompt-library.cmd" /SC DAILY /ST 19:30 /F
```

## 项目线验收组

老段、闻姐、石导、陈叔、老苍、小策不注册计划任务：改完工程手动跑一次，全部支持 `-NoUi` 输出纯文本判定。

```powershell
.\lao-duan\lao-duan.ps1 -NoUi -Project "C:\path\to\project"
.\wen-jie\wen-jie.ps1   -NoUi -Project "C:\path\to\project"
.\shi-dao\shi-dao.ps1   -NoUi -Project "C:\path\to\project"
.\chen-shu\chen-shu.ps1 -NoUi -Project "C:\path\to\project"
.\lao-cang\lao-cang.ps1 -NoUi -Project "C:\path\to\project"
.\xiao-ce\xiao-ce.ps1   -NoUi -Project "C:\path\to\project"
```

判定用统一的三档：`PASS` / `WARN` / `FAIL`（各自的结论名如 `BLOCK`、`MUTE`、`BLOATED`、`BROKEN` 都在同一套口径下）。
去掉 `-NoUi` 则弹出同款卡片，按钮为「复制 / 关闭」，**不会自动关闭**。

## 隐私

- `.credentials.yaml`、Cookie、token 不进 Git。
- iCreat token 只放本机 `~/.icreat/token.txt`。
- 语音/BGM 已随仓库同步；大文件如需替换，注意仓库体积。

> 刘哥没有独立计划任务：周哥检测到需要弹窗时才会启动刘哥复核。

