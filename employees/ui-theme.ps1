function Set-DshCardStyle($form, $accentColor) {
  Add-Type -AssemblyName System.Drawing
  $form.BackColor = [System.Drawing.Color]::FromArgb(14, 17, 22)
  $form.Add_Paint({
    param($sender, $e)
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(42, 48, 58), 1)
    try { $e.Graphics.DrawRectangle($pen, 0, 0, $form.Width - 1, $form.Height - 1) } finally { $pen.Dispose() }
  })
  $radius = 12
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddArc(0, 0, $radius, $radius, 180, 90)
  $path.AddArc($form.Width - $radius, 0, $radius, $radius, 270, 90)
  $path.AddArc($form.Width - $radius, $form.Height - $radius, $radius, $radius, 0, 90)
  $path.AddArc(0, $form.Height - $radius, $radius, $radius, 90, 90)
  $path.CloseFigure()
  $form.Region = New-Object System.Drawing.Region($path)
}
