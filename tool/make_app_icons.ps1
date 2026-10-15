# ---------------------------------------------------------------------------
# make_app_icons.ps1 — สร้างไอคอนแอปทั้งหมดจากโลโก้ต้นฉบับ
#
# ใช้โลโก้ assets/images/thai_otop_logo.png (พื้นหลังสี่เหลี่ยมมุมมนสีเขียว) แล้วสร้าง
#   - Android: mipmap ic_launcher / ic_launcher_round / ic_launcher_foreground
#              + adaptive icon (mipmap-anydpi-v26) + สีพื้น (values/ic_launcher_background.xml)
#   - Web:    web/favicon.png, web/icons/Icon-*.png
#   - iOS:    ios/Runner/Assets.xcassets/AppIcon.appiconset/*
#
# วิธีใช้:  powershell -ExecutionPolicy Bypass -File tool\make_app_icons.ps1
# ---------------------------------------------------------------------------
param(
  [string]$Source = "assets\images\thai_otop_logo.png"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$Root = Split-Path -Parent $PSScriptRoot
if (-not $Root) { $Root = (Get-Location).Path }

function Resolve-FromRoot([string]$p) {
  if ([System.IO.Path]::IsPathRooted($p)) { return $p }
  return (Join-Path $Root $p)
}

$sourcePath = Resolve-FromRoot $Source
if (-not (Test-Path $sourcePath)) { throw "ไม่พบไฟล์โลโก้ต้นฉบับ: $sourcePath" }

# --- robust System.Drawing helpers -----------------------------------------
function New-Scaled([System.Drawing.Image]$img, [int]$size) {
  $b = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($b)
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.DrawImage($img, 0, 0, $size, $size)
  $g.Dispose()
  return $b
}

function Save-Scaled([System.Drawing.Image]$img, [int]$size, [string]$path, [System.Drawing.Color]$bg) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $b = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($b)
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear($bg)
  $g.DrawImage($img, 0, 0, $size, $size)
  $g.Dispose()
  $b.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $b.Dispose()
}

function Write-Utf8NoBom([string]$path, [string]$text) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# Builds an adaptive-icon foreground: the artwork is drawn centred at `frac` of
# the canvas and the surrounding ring is left transparent, so the background
# (a green gradient matching the logo) shows through. This keeps the whole
# artwork inside the launcher's circular safe zone — nothing is clipped.
function Save-Foreground([System.Drawing.Image]$img, [int]$size, [string]$path, [double]$frac) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $b = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($b)
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)
  $d = [int][Math]::Round($size * $frac)
  $o = [int](($size - $d) / 2)
  $g.DrawImage($img, $o, $o, $d, $d)
  $g.Dispose()
  $b.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $b.Dispose()
}

# --- 1) build a clean transparent rounded-square master ---------------------
$src = [System.Drawing.Bitmap]::FromFile($sourcePath)
$work = New-Scaled $src 1024
$src.Dispose()

$n = $work.Width

# the green square = pixels that are clearly green (ignore the faint shadow/AA)
function Test-Green($c) { return (($c.G -gt ($c.R + 12)) -and ($c.G -gt ($c.B + 4))) }

$minX = $n; $minY = $n; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $n; $y++) {
  for ($x = 0; $x -lt $n; $x++) {
    if (Test-Green ($work.GetPixel($x, $y))) {
      if ($x -lt $minX) { $minX = $x }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
}
if ($maxX -lt 0) { throw "ตรวจไม่พบพื้นที่สีเขียวในโลโก้" }
$bw = $maxX - $minX + 1
$bh = $maxY - $minY + 1

# corner radius: first row (from the top) whose left edge reaches minX
$radius = [int]($bw * 0.25)
for ($y = $minY; $y -le $minY + [int]($bh / 2); $y++) {
  $lx = -1
  for ($x = $minX; $x -le $maxX; $x++) {
    if (Test-Green ($work.GetPixel($x, $y))) { $lx = $x; break }
  }
  if ($lx -ge 0 -and ($lx - $minX) -le 2) { $radius = $y - $minY; break }
}

# a representative green for the adaptive background / maskable web icons
$midY = [int](($minY + $maxY) / 2)
$cL = $work.GetPixel($minX + 24, $midY)
$cR = $work.GetPixel($maxX - 24, $midY)
$bgGreen = [System.Drawing.Color]::FromArgb(255, [int](($cL.R + $cR.R) / 2), [int](($cL.G + $cR.G) / 2), [int](($cL.B + $cR.B) / 2))

$master = New-Object System.Drawing.Bitmap($n, $n, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$mg = [System.Drawing.Graphics]::FromImage($master)
$mg.Clear([System.Drawing.Color]::Transparent)
$mg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$mg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$mg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

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

$mg.SetClip($path)
$mg.DrawImage($work, (New-Object System.Drawing.RectangleF($dx, $dy, $destW, $destH)),
  (New-Object System.Drawing.RectangleF($minX, $minY, $bw, $bh)), [System.Drawing.GraphicsUnit]::Pixel)
$mg.ResetClip()
$mg.Dispose()
$work.Dispose()

$masterPath = Resolve-FromRoot "assets\images\thai_otop_icon.png"
Save-Scaled $master $n $masterPath ([System.Drawing.Color]::Transparent)

Write-Output ("master  -> {0} ({1}x{1})  green=#{2:X2}{3:X2}{4:X2}  radius={5}" -f $masterPath, $n, $bgGreen.R, $bgGreen.G, $bgGreen.B, $radius)

# green at the top / bottom of the square -> used for the adaptive-background
# gradient, so the ring around the (inset) foreground blends with the artwork.
# Sample away from the centre: the top-middle is the golden spire tip and the
# bottom-middle is the golden wave, which would tint the ring gold.
function Avg-Green([System.Drawing.Color]$a, [System.Drawing.Color]$b) {
  return [System.Drawing.Color]::FromArgb(255, [int](($a.R + $b.R) / 2), [int](($a.G + $b.G) / 2), [int](($a.B + $b.B) / 2))
}
$topG = Avg-Green ($master.GetPixel([int]($n * 0.30), 20)) ($master.GetPixel([int]($n * 0.70), 20))
$botG = Avg-Green ($master.GetPixel([int]($n * 0.30), $n - 21)) ($master.GetPixel([int]($n * 0.70), $n - 21))
# the launchers crop adaptive icons to a circle; keep the artwork inside the
# safe zone so nothing (e.g. the "OTOP" wordmark) is clipped.
$fgScale = 0.86

# --- 2) Android launcher icons ---------------------------------------------
$android = Resolve-FromRoot "android\app\src\main\res"
# density -> [legacy/round size, adaptive foreground size]
$densities = [ordered]@{
  "mipmap-mdpi"    = @(48, 108)
  "mipmap-hdpi"    = @(72, 162)
  "mipmap-xhdpi"   = @(96, 216)
  "mipmap-xxhdpi"  = @(144, 324)
  "mipmap-xxxhdpi" = @(192, 432)
}
foreach ($dir in $densities.Keys) {
  $legacy = $densities[$dir][0]
  $fg = $densities[$dir][1]
  Save-Scaled $master $legacy (Join-Path $android "$dir\ic_launcher.png") ([System.Drawing.Color]::Transparent)
  Save-Scaled $master $legacy (Join-Path $android "$dir\ic_launcher_round.png") ([System.Drawing.Color]::Transparent)
  Save-Foreground $master $fg (Join-Path $android "$dir\ic_launcher_foreground.png") $fgScale
}
Write-Output "android -> launcher + round + adaptive foreground (5 densities)"

# adaptive icon descriptors
$anydpi = Join-Path $android "mipmap-anydpi-v26"
if (-not (Test-Path $anydpi)) { New-Item -ItemType Directory -Path $anydpi | Out-Null }
$adaptiveXml = @"
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"@
Write-Utf8NoBom (Join-Path $anydpi "ic_launcher.xml") $adaptiveXml
Write-Utf8NoBom (Join-Path $anydpi "ic_launcher_round.xml") $adaptiveXml

# adaptive background: a vertical green gradient that matches the logo
$bgDrawable = @"
<?xml version="1.0" encoding="utf-8"?>
<!-- สีพื้นของ adaptive launcher icon (สร้างโดย tool/make_app_icons.ps1) -->
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient
        android:type="linear"
        android:angle="270"
        android:startColor="#$(("{0:X2}{1:X2}{2:X2}" -f $topG.R, $topG.G, $topG.B))"
        android:endColor="#$(("{0:X2}{1:X2}{2:X2}" -f $botG.R, $botG.G, $botG.B))" />
</shape>
"@
Write-Utf8NoBom (Join-Path (Join-Path $android "drawable") "ic_launcher_background.xml") $bgDrawable
# remove the old flat-colour resource if a previous run created it
$oldColor = Join-Path (Join-Path $android "values") "ic_launcher_background.xml"
if (Test-Path $oldColor) { Remove-Item $oldColor -Force }
Write-Output "android -> adaptive icon xml + background gradient drawable"

# --- 3) Web icons -----------------------------------------------------------
$web = Resolve-FromRoot "web"
Save-Scaled $master 16 (Join-Path $web "favicon.png") ([System.Drawing.Color]::Transparent)
Save-Scaled $master 32 (Join-Path $web "icons\favicon-32.png") ([System.Drawing.Color]::Transparent)
Save-Scaled $master 192 (Join-Path $web "icons\Icon-192.png") ([System.Drawing.Color]::Transparent)
Save-Scaled $master 512 (Join-Path $web "icons\Icon-512.png") ([System.Drawing.Color]::Transparent)
# maskable icons need an opaque, full-bleed background
Save-Scaled $master 192 (Join-Path $web "icons\Icon-maskable-192.png") $bgGreen
Save-Scaled $master 512 (Join-Path $web "icons\Icon-maskable-512.png") $bgGreen
Write-Output "web     -> favicon + icons (192/512 + maskable)"

# --- 4) iOS app icons (opaque, iOS rounds the corners itself) ---------------
$ios = Resolve-FromRoot "ios\Runner\Assets.xcassets\AppIcon.appiconset"
$iosSizes = [ordered]@{
  "Icon-App-20x20@1x.png"    = 20
  "Icon-App-20x20@2x.png"    = 40
  "Icon-App-20x20@3x.png"    = 60
  "Icon-App-29x29@1x.png"    = 29
  "Icon-App-29x29@2x.png"    = 58
  "Icon-App-29x29@3x.png"    = 87
  "Icon-App-40x40@1x.png"    = 40
  "Icon-App-40x40@2x.png"    = 80
  "Icon-App-40x40@3x.png"    = 120
  "Icon-App-60x60@2x.png"    = 120
  "Icon-App-60x60@3x.png"    = 180
  "Icon-App-76x76@1x.png"    = 76
  "Icon-App-76x76@2x.png"    = 152
  "Icon-App-83.5x83.5@2x.png" = 167
  "Icon-App-1024x1024@1x.png" = 1024
}
foreach ($name in $iosSizes.Keys) {
  Save-Scaled $master $iosSizes[$name] (Join-Path $ios $name) $bgGreen
}
Write-Output "ios     -> AppIcon.appiconset (15 sizes)"

$master.Dispose()
Write-Output "เสร็จแล้ว"
