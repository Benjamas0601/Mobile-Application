Add-Type -AssemblyName System.Drawing

$srcPath = (Resolve-Path "assets\images\thai_otop_logo.png").Path
$src = [System.Drawing.Bitmap]::FromFile($srcPath)

$n = 1024
function New-Scaled([System.Drawing.Image]$img, [int]$size) {
  $b = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($b)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.DrawImage($img, 0, 0, $size, $size)
  $g.Dispose()
  return $b
}

$img = New-Scaled $src $n
$src.Dispose()

# A pixel counts as the green square when it is clearly green (ignoring the
# faint drop shadow and the anti-aliased rim, which are near-white/grey).
function Is-Green($c) {
  return (($c.G -gt ($c.R + 12)) -and ($c.G -gt ($c.B + 4)))
}

# --- bounding box of the green square ---
$minX = $n; $minY = $n; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $n; $y++) {
  for ($x = 0; $x -lt $n; $x++) {
    if (Is-Green ($img.GetPixel($x, $y))) {
      if ($x -lt $minX) { $minX = $x }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
}
$bw = $maxX - $minX + 1
$bh = $maxY - $minY + 1
"green bbox = ($minX,$minY)-($maxX,$maxY) w=$bw h=$bh"

# --- corner radius: first row (from the top) whose left edge reaches minX ---
$radius = [int]($bw * 0.25)
for ($y = $minY; $y -le $minY + [int]($bh / 2); $y++) {
  $lx = -1
  for ($x = $minX; $x -le $maxX; $x++) {
    if (Is-Green ($img.GetPixel($x, $y))) { $lx = $x; break }
  }
  if ($lx -ge 0 -and ($lx - $minX) -le 2) { $radius = $y - $minY; break }
}
"corner radius ~= $radius px (of $bw)"

# --- green for the adaptive background (sampled just inside the edges) ---
$midY = [int](($minY + $maxY) / 2)
$c1 = $img.GetPixel($minX + 22, $midY)
$c2 = $img.GetPixel($maxX - 22, $midY)
$sg = [int](($c1.G + $c2.G) / 2); $sr = [int](($c1.R + $c2.R) / 2); $sb = [int](($c1.B + $c2.B) / 2)
"green mid = #{0:X2}{1:X2}{2:X2}" -f $sr, $sg, $sb

# --- build a clean transparent rounded square at $n ---
$out = New-Object System.Drawing.Bitmap($n, $n, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($out)
$g.Clear([System.Drawing.Color]::Transparent)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# Draw the green square a touch larger than the canvas so its anti-aliased rim
# and drop shadow fall outside the edges, then clip the corners with a rounded
# rectangle whose radius matches the logo (a bit larger) so no white shows.
$overscan = 1.05
$scale = ($n * $overscan) / [Math]::Max($bw, $bh)
$destW = $bw * $scale
$destH = $bh * $scale
$dx = ($n - $destW) / 2
$dy = ($n - $destH) / 2
$clipR = ($radius + 14) * $scale

$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$d = 2 * $clipR
$path.AddArc(0, 0, $d, $d, 180, 90)
$path.AddArc($n - $d, 0, $d, $d, 270, 90)
$path.AddArc($n - $d, $n - $d, $d, $d, 0, 90)
$path.AddArc(0, $n - $d, $d, $d, 90, 90)
$path.CloseFigure()

$g.SetClip($path)
$srcRect = New-Object System.Drawing.RectangleF($minX, $minY, $bw, $bh)
$destRect = New-Object System.Drawing.RectangleF($dx, $dy, $destW, $destH)
$g.DrawImage($img, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$g.ResetClip()
$g.Dispose()

$outPath = (Join-Path (Get-Location) "assets\images\thai_otop_icon.png")
$out.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
"wrote $outPath ({0}x{1})" -f $out.Width, $out.Height
$ca = $out.GetPixel(4, 4); $cc = $out.GetPixel([int]($n / 2), 4)
"corner alpha = $($ca.A)  top-mid alpha = $($cc.A)"
$out.Dispose()
$img.Dispose()
