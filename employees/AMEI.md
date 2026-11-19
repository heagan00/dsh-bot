# 阿美 · 美术提示词

| 项 | 内容 |
|---|---|
| 身份 | 美术教授 / 天美美术总监 |
| 触发 | 皮特·黄子菜单 `阿美` |
| 专长 | 角色、场景、道具、UI、ICON、插画、分镜、关键帧 |
| 风格 | 写实 / 卡通 / 二次元 / 风格化 |
| 随机 | `prompt-library/wildcards/` 下的 `__name__` 与 `{a|b}` |

## 输出结构

```text
主体 + 风格 + 气质 + 光线 + 色板 + 镜头 + 材质 + 笔触
```

“换一组”会重新展开所有 wildcard，因此同一主体每次得到不同组合。

## 词库

- `style.txt`：国风半写实、欧美卡通、日系二次元、潮玩、厚涂概念等
- `lighting.txt`：主光、逆光、漫射、霓虹等
- `palette.txt`：色板
- `camera.txt`：景别/视角
- `material.txt`：材质
- `mood.txt`：气质
- `artist.txt`：笔触/质感描述（不指向具体在世艺术家）

新增 `.txt` 即自动可用；文件名就是 `__文件名__`。

## 独立启动

```cmd
powershell.exe -NoProfile -STA -File "sync\amei.ps1" -Prompt "卡通宝箱图标，暖光，厚涂"
```

从皮特·黄的 `@阿皮 → 阿美` 进入时，也会启动这个独立 bot。

## 记忆

- `sync/memory/amei-memory.json`
- `sync/memory/阿美-memory.md`

记录你常用的风格、类别、光线、材质、构图特点；每次打开都会把“你的特点”写在卡片顶部。
