# 皮特·黄 · 提示词结构工程师

| 项 | 内容 |
|---|---|
| 名字 | 皮特·黄（“秉笔太监”） |
| 岗位 | 提示词结构工程师 / 主程 |
| 巡检 | 每 2 分钟扫描 DSH 活跃会话 |
| 触发 | 用户消息超过 100 字 |
| 位置 | 主屏左下角，必须手动关闭 |
| 任务 | `皮特·黄 · 长提示词检查` |
| 日报库 | 每天 19:30，任务 `皮特·黄 · 每日提示词库` |
| 文件 | `sync/pieter-huang.ps1`、`tools/prompt-watch.mjs`、`tools/prompt-library.mjs` |

## 长提示词

弹窗：

```text
官家，需要秉笔太监皮特·黄为您整理提示词吗？
[要] [否] [30分钟内不再出现]
```

- **要**：显示结构化后的提示词，可复制
- **否**：关闭
- **30分钟内不再出现**：该会话静音 30 分钟

## @阿皮

提示词里出现 `@阿皮` 时，直接弹子菜单：

```text
[优化提示词] [阿美] [阿威] [阿秃] [取消]
```

| 员工 | 职责 |
|---|---|
| **阿美** | 美术教授 / 天美美术总监视角；整理角色、场景、道具、UI、ICON、插画、分镜、关键帧；支持 wildcards 随机 |
| **阿威** | 视频生成提示词；镜头、动作、运镜、光线、时长、音频 |
| **阿秃** | 代码提示词；目标、技术栈、输入、约束、验收、测试 |

三名员工是皮特·黄的**按需模块**，不单独起定时器，避免空转占算力。

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

索引：`prompt-library/index.md`、`index.json`。

## 高频词猜词

```cmd
node tools\prompt-guess.mjs --text="做一个卡通宝箱图标"
```

输出：候选分类、命中词、建议补充的维度。用于先把模糊提示词猜到一个一级分类，再细分类。

`index.json` 同时保存分类计数和 top 高频词；分类采用加权命中，不是“第一个关键词命中就归类的单规则”。

## Wildcards

参考 AUTOMATIC1111 wildcards 扩展的机制复现：

- `__style__` → 从 `wildcards/style.txt` 随机取一行
- 子目录：`__art/color__` → `wildcards/art/color.txt`
- 嵌套：选中的行里继续展开 `__lighting__`
- 内联：`{red|blue|green}` 随机取一个
- 阿美每次“换一组”都会重新随机，组合不固定

词库在 `prompt-library/wildcards/`，可直接加 `.txt` 文件扩展。

## 手动

```cmd
schtasks /Run /TN "皮特·黄 · 长提示词检查"
schtasks /Run /TN "皮特·黄 · 每日提示词库"
powershell.exe -NoProfile -STA -File "sync\pieter-huang.ps1" -Test
```
