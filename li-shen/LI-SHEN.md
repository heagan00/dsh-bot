# 李婶 · BOT 缓存清理

| 项 | 内容 |
|---|---|
| 名字 | 李婶 |
| 岗位 | BOT 缓存清理员 |
| 时间 | **每周二 21:00** |
| 任务名 | `李婶 · BOT缓存清理` |
| 脚本 | `sync/li-shen-cleanup.ps1` |
| 包装 | `sync/li-shen.cmd`（带 `-Apply`） |
| 报告 | `sync/reports/li-shen-latest.md` + `li-shen-YYYY-MM-DD.md` |
| 日志 | `sync/logs/li-shen.log` |

## 备份规则

备份到 `backups/`（本机，已加入 `.gitignore`）：

| 对象 | 规则 | 路径 |
|---|---|---|
| **BOT** | 每周覆盖 1 份滚动版本，保留一周前的代码 | `backups/bots/bots-weekly.zip` |
| **skills** | 每次运行都新建，保留所有历史版本 | `backups/skills/skills-YYYY-MM-DD-HHmmss.zip` |
| **plugins** | 保留 1 份上一版本（profile 配置 + dsh-config） | `backups/plugins/plugins-prev.zip` |

> 当前没有自定义 `~/.dsh/skills`；有 skill 后会自动按时间戳全量备份。

## 清理规则

| 对象 | 阈值 |
|---|---|
| `sync/logs/*.log` | 超过 14 天 |
| `sync/reports/*`（保留 latest/icreat-latest） | 超过 30 天 |
| `sync/*.tmp / *.bak / *.old` | 超过 7 天 |
| `sync/*.png`（调试截图） | 超过 1 天 |
| `~/.icreat/network.json` | 超过 1 天 |
| `~/Downloads/icreat-probe/*` | 超过 1 天 |

## 绝对不清理

- `sync/audio/`、`sync/voice/`（BGM/语音资产）
- `sync/reports/latest.md`、`icreat-latest.*`
- `sync/logs/wang-dali-state.json`（提醒间隔状态）
- `~/.icreat/token.txt`、`session.txt`、`chrome-profile`（登录态）
- `site/cases/*/out/`（项目产出）
- 任何 `.git`、源码、脚本

## 手动

```cmd
schtasks /Run /TN "李婶 · BOT缓存清理"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "sync\li-shen-cleanup.ps1"
```

默认是 dry-run；包装脚本用 `-Apply` 才会真删。
