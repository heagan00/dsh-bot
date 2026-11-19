$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'ui-theme.ps1')

function Emp-Load([string]$file, [string]$owner, [string]$domain) {
  $mem = @{ owner = $owner; domain = $domain; updated = ''; samples = @(); traits = @{} }
  if (Test-Path $file) {
    try {
      $old = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($old.owner) { $mem.owner = $old.owner }
      if ($old.domain) { $mem.domain = $old.domain }
      if ($old.samples) { $mem.samples = @($old.samples) }
      if ($old.traits) { $old.traits.PSObject.Properties | ForEach-Object { $mem.traits[$_.Name] = [int]$_.Value } }
    } catch {}
  }
  return $mem
}

function Emp-Save([string]$file, $mem, [string]$prompt, [string[]]$tags) {
  $entry = [pscustomobject]@{ time = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); prompt = $prompt; tags = @($tags) }
  $mem.samples = @(@($mem.samples) + $entry | Select-Object -Last 20)
  foreach ($t in $tags) {
    if (-not $mem.traits.ContainsKey($t)) { $mem.traits[$t] = 0 }
    $mem.traits[$t] = [int]$mem.traits[$t] + 1
  }
  $mem.updated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  New-Item -ItemType Directory -Force (Split-Path $file -Parent) | Out-Null
  $mem | ConvertTo-Json -Depth 8 | Set-Content $file -Encoding utf8

  $rows = @("# $($mem.owner) 的小本本", '', "> 记录你给 $($mem.owner) 的提示词特点；只用于本领域。", '', '| 特点 | 次数 |', '|---|---:|')
  foreach ($k in ($mem.traits.Keys | Sort-Object { $mem.traits[$_] } -Descending | Select-Object -First 20)) {
    $rows += ("| {0} | {1} |" -f $k, $mem.traits[$k])
  }
  $rows += @('', '## 最近样例', '')
  foreach ($s in (@($mem.samples) | Select-Object -Last 5)) {
    $rows += ('- ' + $s.time + '：' + $s.prompt)
  }
  Set-Content (Join-Path (Split-Path $file -Parent) ($mem.owner + '-memory.md')) ($rows -join "`n") -Encoding utf8
}

function Emp-Summary($mem) {
  $top = @($mem.traits.Keys | Sort-Object { $mem.traits[$_] } -Descending | Select-Object -First 8 |
    ForEach-Object { "$_×$($mem.traits[$_])" })
  if ($top.Count -eq 0) { return '还没有记录；这是第一次，我会记住这条的特点。' }
  return ($top -join '、')
}

function Emp-Expand([string]$text, [string]$wildRoot) {
  for ($i = 0; $i -lt 8; $i++) {
    $before = $text
    $text = [regex]::Replace($text, '__([A-Za-z0-9_\-/]+)__', {
      param($m)
      $name = $m.Groups[1].Value
      $file = Join-Path $wildRoot ($name + '.txt')
      if (-not (Test-Path $file)) { return $m.Value }
      $lines = @(Get-Content $file -Encoding utf8 | Where-Object { $_.Trim() })
      if ($lines.Count -eq 0) { return $m.Value }
      return ($lines | Get-Random)
    })
    $text = [regex]::Replace($text, '\{([^{}]+)\}', {
      param($m)
      $opts = @($m.Groups[1].Value -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
      if ($opts.Count -eq 0) { return $m.Value }
      return ($opts | Get-Random)
    })
    if ($text -eq $before) { break }
  }
  return $text
}

function Emp-Show([string]$title, [string]$body, [string[]]$buttons, $accentColor) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $form = New-Object System.Windows.Forms.Form
  $form.Text = $title
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
  $form.TopMost = $true
  $form.ShowInTaskbar = $false
  $form.Width = 660
  $form.Height = 520
  Set-DshCardStyle $form $accentColor
  $form.BackColor = [System.Drawing.Color]::FromArgb(22, 24, 28)
  $screen = [System.Windows.Forms.Screen]::PrimaryScreen
  $wa = $screen.WorkingArea
  $form.Left = $wa.Left + 24
  $form.Top = $wa.Bottom - $form.Height - 24
  $script:empForm = $form

  $accent = New-Object System.Windows.Forms.Panel
  $accent.Dock = [System.Windows.Forms.DockStyle]::Top
  $accent.Height = 5
  $accent.BackColor = $accentColor
  $form.Controls.Add($accent)

  $label = New-Object System.Windows.Forms.Label
  $label.Text = $title
  $label.Font = New-Object System.Drawing.Font('Microsoft YaHei', 14, [System.Drawing.FontStyle]::Bold)
  $label.ForeColor = [System.Drawing.Color]::FromArgb(240, 232, 220)
  $label.Left = 20; $label.Top = 16; $label.Width = 590; $label.Height = 28
  $form.Controls.Add($label)

  $close = New-Object System.Windows.Forms.Button
  $close.Text = '×'
  $close.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $close.FlatAppearance.BorderSize = 0
  $close.ForeColor = [System.Drawing.Color]::FromArgb(190, 190, 195)
  $close.BackColor = $form.BackColor
  $close.Font = New-Object System.Drawing.Font('Microsoft YaHei', 15)
  $close.Left = 620; $close.Top = 10; $close.Width = 30; $close.Height = 30
  $close.Add_Click({ $script:empChoice = '关闭'; $script:empForm.Close() })
  $form.Controls.Add($close)

  $box = New-Object System.Windows.Forms.RichTextBox
  $box.Text = $body
  $box.ReadOnly = $true
  $box.BorderStyle = [System.Windows.Forms.BorderStyle]::None
  $box.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
  $box.BackColor = $form.BackColor
  $box.ForeColor = [System.Drawing.Color]::FromArgb(225, 230, 235)
  $box.Font = New-Object System.Drawing.Font('Microsoft YaHei', 10.5)
  $box.Left = 20; $box.Top = 54; $box.Width = 620; $box.Height = 370
  $form.Controls.Add($box)

  $x = 20
  foreach ($b in $buttons) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $b
    $btn.Left = $x; $btn.Top = 440
    $btn.Width = [Math]::Max(100, 28 + ([int]$b.Length * 16)); $btn.Height = 34
    $btn.UseVisualStyleBackColor = $false
    $btn.BackColor = if ($b -eq '复制' -or $b -eq '换一组') { $accentColor } else { [System.Drawing.Color]::FromArgb(60, 64, 72) }
    $btn.ForeColor = if ($b -eq '复制' -or $b -eq '换一组') { [System.Drawing.Color]::FromArgb(25, 22, 18) } else { [System.Drawing.Color]::FromArgb(240, 242, 245) }
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $btn.Font = New-Object System.Drawing.Font('Microsoft YaHei', 9.5)
    $btn.Tag = $b
    $btn.Add_Click({ $script:empChoice = $this.Tag; $script:empForm.Close() })
    $form.Controls.Add($btn)
    $x += $btn.Width + 8
  }

  $script:empChoice = '关闭'
  [System.Windows.Forms.Application]::Run($form)
  $form.Dispose()
  return $script:empChoice
}
