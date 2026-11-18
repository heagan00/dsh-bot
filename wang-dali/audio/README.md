# 王大力 BGM / 自然声

## 文件

- `bgm.html`：纯 HTML + Web Audio API 生成器，可试听/导出 WAV
- `music1-3.wav`：30s 纯音乐循环
- `rain.wav` / `waves.wav` / `stream.wav` / `birds.wav`：30s 自然白噪声循环

## 随机感

- `bgm.html` 每次播放/导出都用新的随机种子：随机调式、和弦进行、琶音/铃音、自然事件密度。
- 弹窗每次随机选一条音轨（55% 纯音乐 / 45% 自然声），并从随机位置开始播放，避免每次听同一段。
- 音量压低到 0.13–0.20，不盖过朗读。

## 重新生成

打开：

```text
sync/audio/bgm.html
```

点“播放”试听；点“导出 WAV”保存随机版本。弹窗会优先使用 `sync/audio` 下同名 WAV。
