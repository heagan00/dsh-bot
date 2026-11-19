# BOT 员工总览

| 员工 | 岗位 | 时间 | 任务名 | 说明 |
|---|---|---|---|---|
| **张淑芬** | 知识库更新专员 | 工作日 18:30 更新；19:10 同步；19:15 验收 | `DSH GitHub Weekday Sync` | 知识库、对话、工作区同步 |
| **何大奔** | iCreat 用量分析师 | 每天 07:00 | `何大奔 · iCreat 用量提醒` | 余额 + 今日/昨日/前日 + 3 日合计弹窗 |
| **王大力** | 心理抚慰师 | 每天 09:00–24:00，每 30–45 分钟 | `王大力 · 心理抚慰师` | 主屏左下角卡片 + 朗读 + 随机 BGM |
| **李婶** | BOT 缓存清理员 | 每周二 21:00 | `李婶 · BOT缓存清理` | 清理旧日志/日报/临时文件，不动语音与登录态 |
| **周哥** | 全栈工程师 / 主程 | 每 5 分钟 | `周哥 · 全栈主程巡检` | 扫描活跃会话，优先提醒算力浪费与低效路径 |
| **刘哥** | 全栈工程师 / 主程（复核） | 周哥弹窗时触发 | 无独立任务 | 复核周哥提醒，误报时主屏底部中间提示 |
| **皮特·黄** | 提示词结构工程师 / 主程 | 每 2 分钟；每日 19:30 | `皮特·黄 · 长提示词检查` / `皮特·黄 · 每日提示词库` | 长提示词整理、@阿皮 员工菜单、提示词库分类 |

## 文件

- 张淑芬：[BOT.md](BOT.md)、[weekday-sync.ps1](weekday-sync.ps1)、[run-weekday-sync.cmd](run-weekday-sync.cmd)
- 何大奔：[HE-DABEN.md](HE-DABEN.md)、[icreat-usage.ps1](icreat-usage.ps1)、[he-daben.cmd](he-daben.cmd)
- 王大力：[WANG-DALI.md](WANG-DALI.md)、[wang-dali.ps1](wang-dali.ps1)、[wang-dali-tips.json](wang-dali-tips.json)、[wang-dali.cmd](wang-dali.cmd)、[audio/](audio/)

## 原则

- 都走 Windows 计划任务，不依赖 DSH 在线，不需要逐次授权。
- 登录态、Cookie、token 只在本机，不进 Git。
- 大文件/语音缓存按需放本机；当前王大力 MP3/BGM 已随仓库同步。
- 李婶**无权**处理 `prompt-library/` 和 `sync/memory/`；只清理缓存与备份 BOT/skills/plugins。
- 任务为 Interactive only：PC 开机且已登录才运行。

> 所有弹窗（含 ×）都必须由 heagan00 手动点击，BOT 不会自动关闭；刘哥关闭还需二次确认。


