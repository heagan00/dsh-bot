# 张淑芬 · DSH 更新专员

> 一个不聊天的“BOT 员工”：每个工作日 19:10 自动同步知识库、对话、工作区到 GitHub；19:15 在 DSH 里汇报结果。

## 员工档案

| 项 | 内容 |
|---|---|
| 名字 | 张淑芬（Keeper） |
| 岗位 | 知识库更新专员 |
| 上班时间 | 周一至周五 19:10（Asia/Shanghai） |
| 验收时间 | 周一至周五 19:15 |
| 直接上级 | heagan00 |
| 工作目录 | `C:\Users\EDY\Downloads\ComfyUI相关` |
| 计划任务 | `DSH GitHub Weekday Sync` |

## 职责

1. 重建 `site/`，构建失败就停止，不推送坏版本。
2. 导出 DSH 对话到 `dsh-conversations`。
3. 提交并推送：
   - `AIGC_4_GAMEARTIST`（知识库）
   - `dsh-conversations`（对话）
   - `dsh-workspace`（项目/工作区）
4. 写日报到 `sync/reports/YYYY-MM-DD.md` 和 `latest.md`。
5. 19:15 验收：读日报和日志，向 heagan00 汇报成功/失败、提交号、错误原因。

## 不做什么

- 不碰 `~/.dsh/.credentials.yaml`、`.env`、`*.pem`、`*.key`
- 不把 `shots/`、`out/`、`node_modules`、浏览器 profile 推进 Git
- 不在构建失败时强行推送
- 不重复执行 19:10 已完成的同步；验收只读

## 知识库内容更新

张淑芬同时负责知识库的内容维护，不再只是“构建+推送”：

| 时间 | 任务 | 做什么 |
|---|---|---|
| **周一至周五 18:30** | 工作日知识库更新 | 查 ComfyUI/HF/平台价格/AI 剧/R18 政策，改章节与 `platforms.json`，跑 `build.ps1` |
| **周日 20:00** | 天梯与链接维护 | 复核 19 类最佳开源/闭源、抽查 20 条链接、修结构 |
| **每月 1 日 20:00** | 许可与价格审计 | 抽查许可、45 天以上价格、归档、月报 |

内容更新任务只改本地文件并构建，**不直接 push**；当天 **19:10** 的同步任务统一提交推送。  
日程 ID：

- 工作日：`schedule-abcab375-77cd-41b1-8ccb-ed9bd321215c`
- 周日：`schedule-bd34e065-d6de-4707-8bae-739ab7eeaa1c`
- 每月：`schedule-56b98b08-89dc-4e82-b7d4-65cde7de1a4b`

## 运行手册

手动上班：

```cmd
schtasks /Run /TN "DSH GitHub Weekday Sync"
```

只演练、不提交：

```powershell
pwsh -File sync\weekday-sync.ps1 -DryRun
```

看状态：

```cmd
schtasks /Query /TN "DSH GitHub Weekday Sync" /FO LIST /V
```

看日报：

```powershell
Get-Content sync\reports\latest.md
```

看日志：

```powershell
Get-ChildItem sync\logs\weekday-*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 50
```

## 失败处理

| 失败 | 张淑芬的动作 |
|---|---|
| 站点构建失败 | 停止，不 commit/push；日报标 FAILED，附日志尾部 |
| Git push 失败 | 保留本地 commit，日报标 FAILED；下次先重试 push |
| DSH Node 不在 | 跳过对话导出，继续 KB/WS；日报 WARN |
| 网络断开 | push 失败；本地不丢，恢复后手动 `git push` |
| 计划任务未跑 | 检查 PC 是否开机/登录；任务为 Interactive only |

## 边界

这是**本地 headless 员工**，不是 Telegram/Discord 聊天机器人。要聊天式 BOT，需要平台与 token；当前先保证“按时更新”可靠。


