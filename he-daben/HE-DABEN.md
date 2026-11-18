# 何大奔 · iCreat 用量分析师

| 项 | 内容 |
|---|---|
| 名字 | 何大奔 |
| 岗位 | iCreat API 用量分析师 |
| 上班 | 每天 **07:00** |
| 输出 | Windows 右下角弹窗：余额 + 今日/昨日/前日 + 3 日合计 |
| 数据源 | `~/.icreat/token.txt` → iCreat 控制台 API |
| 脚本 | `icreat-usage.ps1` |
| 计划任务 | `何大奔 · iCreat 用量提醒` |

## 数据口径

- 余额：`availableBalanceUsd`
- 用量：`/api/nexus/log/self` 的 `cashFee`，500,000 点 = 1 USD
- 三日：本地时区的今日/昨日/前日
- 登录失效：弹窗提示更新 `~/.icreat/token.txt`

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

