Add-Type -AssemblyName System.Drawing

$master = [System.Drawing.Bitmap]::FromFile((Resolve-Path "assets\images\thai_otop_icon.png").Path)
$top = $master.GetPixel([int]($master.Width / 2), 14)
$bot = $master.GetPixel([int]($master.Width / 2), $master.Height - 15)

$S = 480
$fracs = @(0.72, 0.80, 0.85, 0.90)
$panel = New-Object System.Drawing.Bitmap(($S * $fracs.Count), $S, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$pg = [System.Drawing.Graphics]::FromImage($panel)
$pg.Clear([System.Drawing.Color]::FromArgb(255, 40, 40, 40))
$pg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$pg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

$i = 0
foreach ($frac in $fracs) {
  $cv = New-Object System.Drawing.Bitmap($S, $S, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($cv)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Point(0, 0)), (New-Object System.Drawing.Point(0, $S)), $top, $bot)
  $g.FillRectangle($grad, 0, 0, $S, $S)
  $d = [int][Math]::Round($S * $frac)
  $o = [int](($S - $d) / 2)
  $g.DrawImage($master, $o, $o, $d, $d)
  $g.Dispose()

  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse(0, 0, $S, $S)
  $mask = New-Object System.Drawing.Bitmap($S, $S, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $mg = [System.Drawing.Graphics]::FromImage($mask)
  $mg.Clear([System.Drawing.Color]::Transparent)
  $mg.SetClip($path)
  $mg.DrawImage($cv, 0, 0)
  $mg.Dispose()

  $pg.DrawImage($mask, ($i * $S), 0)
  $mask.Dispose()
  $cv.Dispose()
  $i++
}
$pg.Dispose()
$panel.Save((Join-Path (Get-Location) ".tmp_scales.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$panel.Dispose()
$master.Dispose()
"scales preview written (0.72 0.80 0.85 0.90)"
