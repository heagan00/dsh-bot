# 老段 · 验收 QA

| 项 | 内容 |
|---|---|
| 名字 | 老段 |
| 岗位 | 验收 QA / State & Systems QA |
| 归属 | 质量线（P0） |
| 触发 | 按需（`@老段` / 命令行）；**每次构建后必跑** |
| 工期 | 单次 3–5 分钟（静态分析） |
| 脚本 | `lao-duan/lao-duan.ps1` |
| 记忆 | `memory/lao-duan-memory.json` |
| 计划任务 | 无（构建后触发）或每周一 09:00 复查 |

## 我为什么存在

前两轮审计里查出的 P0 级问题**全是状态机问题，不是代码写错**：

- 回溯功能只在 `mount()` 打了点，`goTo()` 从不打点 → 面板永远只有 1~2 个可用节点
- `proof()` 在漫画版和重制版里是两套互不兼容的定义
- 存档不校验证据 id → 旧档打开案卷直接 `TypeError`
- 引擎把格子绘制异常 `console.error` 掉，而测试只监听 `exceptionThrown` → 「errors 0」是恒真的假断言

周哥的主程巡检是**进程级健康检查**（服务是否活着），它永远不会发现「回溯坏了」——因为游戏不报错，只是功能不存在。

**这就是我的岗位缺口：没有任何人验证「玩法功能是否真的存在」。**

## 我检查什么

| ID | 项 | 判定依据 |
|---|---|---|
| S01 | 回溯打点 | `goTo()` 内是否有 `checkpoint()` |
| S02 | `proof()` 单一定义 | 跨文件比对判定条件是否一致 |
| S03 | 证据可达性 | EV 表里每份证据是否有 `gain()` 入口 |
| S04 | 存档字段校验 | `load()` 是否校验 `ev` 中的 id 有效性 |
| S05 | 异常被吞 | 是否存在 `catch { console.error }` 静默失败 |
| S06 | 产物同步 | 源文件是否比构建产物新 |
| S07 | 版本控制 | 项目根目录是否有 `.git` |
| S08 | 工程污染 | 是否有浏览器配置目录等体积异常物进工程 |

## 判定口径

| 结果 | 含义 | 允许发布 |
|---|---|---|
| **PASS** | 全部通过 | ✅ |
| **CAUTION** | 有 WARN，无 FAIL | ⚠️ 可玩，不可发布 |
| **BLOCK** | 有任一 FAIL | ❌ 不可发布 |

**我不接受「文档里写了已修复」作为证据。** 只有能跑出来的结果算数。

## 输出

一份逐项清单 + 判定 + 下一步建议。FAIL 项会写进记忆，下次优先复查。

## 独立启动

```cmd
powershell.exe -NoProfile -STA -File "sync\lao-duan\lao-duan.ps1"
```

指定项目：

```cmd
powershell.exe -NoProfile -STA -File "sync\lao-duan\lao-duan.ps1" -Project "C:\Users\EDY\Downloads\fable_projt_test01"
```

无界面模式（CI / 脚本调用）：

```powershell
.\sync\lao-duan\lao-duan.ps1 -NoUi -Project "C:\Users\EDY\Downloads\fable_projt_test01"
```

## 边界

- 我**不**做视觉验收（那是石导的事）。
- 我**不**做叙事一致性（那是闻姐的事）。
- 我**不**改代码，只出判定和证据；修由周哥/阿秃执行。
- 我**不**自动关闭弹窗（遵循全组原则）。
