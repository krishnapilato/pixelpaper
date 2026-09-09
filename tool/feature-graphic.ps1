# -*- coding: utf-8 -*-
# Draws the 1024x500 feature graphic Google Play asks for.
#
#   powershell -File tool/feature-graphic.ps1
#
# Same palette and same mark as the app: dark surface, the seed blue, the A4
# sheet whose corner comes away as pixels. Play crops this image differently on
# different surfaces, so everything that matters stays well inside the middle.
# Text is drawn with Segoe UI; on a machine without it, GDI+ falls back and the
# spacing shifts slightly.

Add-Type -AssemblyName System.Drawing

$W = 1024; $H = 500
$surface = [System.Drawing.Color]::FromArgb(255, 17, 19, 24)
$blue    = [System.Drawing.Color]::FromArgb(255, 76, 141, 255)
$white   = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$muted   = [System.Drawing.Color]::FromArgb(255, 169, 173, 184)

function New-RoundedPath([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  if ($r -le 0) { $p.AddRectangle((New-Object System.Drawing.RectangleF($x, $y, $w, $h))); return $p }
  $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  return $p
}

$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.TextRenderingHint = 'ClearTypeGridFit'
$g.Clear($surface)

# A wide, very soft glow behind the mark: the scanner light, not a spotlight.
$glow = New-Object System.Drawing.Drawing2D.GraphicsPath
$glow.AddEllipse(-120, 40, 700, 420)
$brushGlow = New-Object System.Drawing.Drawing2D.PathGradientBrush($glow)
$brushGlow.CenterColor = [System.Drawing.Color]::FromArgb(46, 76, 141, 255)
$brushGlow.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 76, 141, 255))
$g.FillPath($brushGlow, $glow)

# --- the mark, same geometry as tool/icon.js (108 unit viewport) ---
$markX = 96.0; $markY = 172.0; $markSize = 156.0
$k = $markSize / 108.0
$bgPath = New-RoundedPath $markX $markY $markSize $markSize (24 * $k)
$g.FillPath((New-Object System.Drawing.SolidBrush($blue)), $bgPath)

$sheet = New-RoundedPath ($markX + 31 * $k) ($markY + 32 * $k) (28 * $k) (40 * $k) (3 * $k)
$g.FillPath((New-Object System.Drawing.SolidBrush($white)), $sheet)
$px1 = New-RoundedPath ($markX + 62 * $k) ($markY + 52 * $k) (10 * $k) (10 * $k) (1.5 * $k)
$g.FillPath((New-Object System.Drawing.SolidBrush($white)), $px1)
$px2 = New-RoundedPath ($markX + 74 * $k) ($markY + 65 * $k) (7 * $k) (7 * $k) (1 * $k)
$g.FillPath((New-Object System.Drawing.SolidBrush($white)), $px2)

# --- wordmark, rule and motto ---
$textX = 300.0
$fontName = 'Segoe UI'
$title = New-Object System.Drawing.Font($fontName, 62, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$sub   = New-Object System.Drawing.Font($fontName, 27, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$tag   = New-Object System.Drawing.Font($fontName, 21, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)

$g.DrawString('PixelPaper', $title, (New-Object System.Drawing.SolidBrush($white)), $textX, 168)
$titleWidth = $g.MeasureString('PixelPaper', $title).Width

# The rule from the splash screen, fading in from the left.
$ruleRect = New-Object System.Drawing.RectangleF($textX, 258, ($titleWidth - 12), 3)
$ruleBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  $ruleRect,
  [System.Drawing.Color]::FromArgb(0, 76, 141, 255),
  $blue,
  [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal)
$g.FillRectangle($ruleBrush, $ruleRect)

$g.DrawString('I tuoi dati restano con te.', $sub, (New-Object System.Drawing.SolidBrush($blue)), ($textX - 3), 276)
$g.DrawString('Scanner di documenti e archivio PDF — tutto sul dispositivo', $tag,
  (New-Object System.Drawing.SolidBrush($muted)), ($textX - 2), 322)

$out = Join-Path (Get-Location) 'store\play-feature-1024x500.png'
New-Item -ItemType Directory -Force -Path (Split-Path $out) | Out-Null
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
"{0}  {1} KB" -f $out, [math]::Round((Get-Item $out).Length / 1KB, 1)
