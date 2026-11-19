# 何大奔 · iCreat 用量分析师

| 项 | 内容 |
|---|---|
| 名字 | 何大奔 |
| 岗位 | iCreat API 用量分析师 |
| 上班 | 每天 **07:00** |
| 输出 | 弹窗：iCreat 余额/3 日 + DSH 今日消耗/余额/累计；另出周报/月报 |
| 数据源 | `~/.icreat/token.txt` → iCreat 控制台 API；DSH `~/.dsh/sessions` |
| 脚本 | `sync/icreat-usage.ps1`、`sync/he-daben-report.cmd` |
| 计划任务 | `何大奔 · iCreat 用量提醒`（07:00）、`何大奔 · 用量周报月报`（07:10） |

## 数据口径

- 余额：`availableBalanceUsd`
- 用量：`/api/nexus/log/self` 的 `cashFee`，500,000 点 = 1 USD
- 三日：本地时区的今日/昨日/前日
- 登录失效：弹窗提示更新 `~/.icreat/token.txt`

## 周报/月报

`-ReportOnly` 模式不弹窗，只生成：

- `sync/reports/usage-latest.md`
- `site/content/92-usage-report.md`
- 周一额外写 `site/content/92-usage-weekly.md`
- 每月 1 日额外写 `site/content/92-usage-monthly.md`

内容：

- iCreat：本周/本月现金消耗 + 次数 + 余额
- DSH：今日/本周/本月 token、消息数、会话数
- 两者口径不同，不直接相加

```cmd
powershell.exe -NoProfile -File "sync\icreat-usage.ps1" -ReportOnly
```

## 手动

```cmd
schtasks /Run /TN "何大奔 · iCreat 用量提醒"
powershell.exe -NoProfile -STA -File "sync\icreat-usage.ps1"
```

## 登录

```text
C:\Users\EDY\.icreat\登录iCreat.cmd
```

登录后由 `tools/icreat-login.mjs` 读取专用 Chrome 的 Cookie/token。
**token 只存本机 `~/.icreat/`，不进 Git。**

弹窗**不会自动关闭**，必须手动点右上角 ×。

