# 王大力 · 心理抚慰师

| 项 | 内容 |
|---|---|
| 名字 | 王大力 |
| 岗位 | 心理抚慰师 |
| 上班 | 每天 **09:00–24:00** |
| 频率 | 两次提醒间隔 **30–45 分钟**（start-to-start） |
| 形式 | 主屏幕左下角卡片 + “朗读”按钮 + 随机 BGM/自然声 |
| 声线 | **Microsoft Edge TTS `zh-CN-XiaoxiaoNeural`**，成年女性、自然语气，rate −5% |
| 语音文件 | `sync/voice/tip-01.mp3` … `tip-12.mp3`（本机预生成，不依赖网络） |
| BGM | `sync/audio/*.wav`；55% 纯音乐 / 45% 自然声，随机起点 |
| 脚本 | `sync/wang-dali.ps1` |
| 计划任务 | `王大力 · 心理抚慰师`（每天 09:00） |

## 提醒逻辑

- 09:00 启动，首次立即提醒；之后按 **30–45 分钟**随机间隔。
- 用 `sync/logs/wang-dali-state.json` 记录上次提醒时间；任务重启也不会 30 分钟内重复。
- 24:00 自动退出；次日 09:00 再启动。
- 同时只允许一个实例（全局 mutex）。

## 语音

- 点击卡片上的 **“朗读”** 播放自然女声；再点 **“停止”**。
- 语音文件由 `uvx --from edge-tts edge-tts` 预生成，避免每次联网。
- 没有 MP3 时回退 Windows SAPI（Huihui），但默认走 Xiaoxiao。

## 手动

```cmd
schtasks /Run /TN "王大力 · 心理抚慰师"
powershell.exe -NoProfile -STA -File "sync\wang-dali.ps1" -Test
```

## 重新生成语音

```powershell
$tips = (Get-Content sync\wang-dali-tips.json -Raw -Encoding UTF8 | ConvertFrom-Json).tips
for ($i=0; $i -lt $tips.Count; $i++) {
  $n = $i + 1
  uvx --from edge-tts edge-tts --voice zh-CN-XiaoxiaoNeural --rate=-5% `
    --text $tips[$i] --write-media ("sync\voice\tip-{0:D2}.mp3" -f $n)
}
```

弹窗**不会自动关闭**，必须手动点右上角 ×；关闭前提醒会一直保留。

