# DSH BOT Staff

七个本地自动化 BOT 的源码与资源。都走 Windows 计划任务，不依赖 DSH 在线，不需要逐次授权。

| BOT | 岗位 | 时间 | 任务名 |
|---|---|---|---|
| **张淑芬** | 知识库更新专员 | 工作日 18:30 更新 / 19:10 同步 / 19:15 验收 | `DSH GitHub Weekday Sync` |
| **何大奔** | iCreat 用量分析师 | 每天 07:00 | `何大奔 · iCreat 用量提醒` |
| **王大力** | 心理抚慰师 | 每天 09:00–24:00，每 30–45 分钟 | `王大力 · 心理抚慰师` |
| **李婶** | BOT 缓存清理员 | 每周二 21:00 | `李婶 · BOT缓存清理` |
| **周哥** | 全栈工程师 / 主程 | 每 5 分钟 | `周哥 · 全栈主程巡检` |
| **刘哥** | 全栈工程师 / 主程（复核） | 周哥弹窗时触发 | 无独立任务 |
| **皮特·黄** | 提示词结构工程师 / 主程 | 每 2 分钟；每日 19:30 | `皮特·黄 · 长提示词检查` / `皮特·黄 · 每日提示词库` |

## 目录

```text
zhang-shufeng/   BOT.md, weekday-sync.ps1, run-weekday-sync.cmd
he-daben/        HE-DABEN.md, icreat-usage.ps1, he-daben.cmd
wang-dali/       WANG-DALI.md, wang-dali.ps1, tips, audio/, voice/
li-shen/         LI-SHEN.md, li-shen-cleanup.ps1, li-shen.cmd
zhou-ge/         ZHOU-GE.md, zhou-ge.ps1, zhou-ge.cmd
liu-ge/          LIU-GE.md, liu-ge.ps1, liu-ge.cmd
pieter-huang/    PIETER-HUANG.md, pieter-huang.ps1, employees docs, prompt library scripts
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

## 隐私

- `.credentials.yaml`、Cookie、token 不进 Git。
- iCreat token 只放本机 `~/.icreat/token.txt`。
- 语音/BGM 已随仓库同步；大文件如需替换，注意仓库体积。

> 刘哥没有独立计划任务：周哥检测到需要弹窗时才会启动刘哥复核。

