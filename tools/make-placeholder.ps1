param(
  [Parameter(Mandatory = $true)][string]$Label,
  [Parameter(Mandatory = $true)][string]$OutFile
)

Add-Type -AssemblyName System.Drawing

# --- matches the existing assets/images/*.png style exactly ---
$W = 400
$H = 300
$TopLeft  = [System.Drawing.Color]::FromArgb(255, 162, 32, 54)   # #A22036
$BottomRt = [System.Drawing.Color]::FromArgb(255, 86, 17, 31)    # #56111F

$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.TextRenderingHint = 'AntiAlias'
$g.PixelOffsetMode = 'HighQuality'

# diagonal gradient, top-left -> bottom-right
$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  (New-Object System.Drawing.Point(0, 0)),
  (New-Object System.Drawing.Point($W, $H)),
  $TopLeft, $BottomRt
)
$g.FillRectangle($brush, 0, 0, $W, $H)

# white bold text, auto-shrunk so it always fits
$size = 44.0
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = 'Center'
$fmt.LineAlignment = 'Center'
$fmt.Trimming = 'Word'
$fmt.FormatFlags = 0

$area = New-Object System.Drawing.RectangleF(30, 20, ($W - 60), ($H - 40))
$limit = New-Object System.Drawing.SizeF(($W - 60), ($H - 40))

# shrink the font until the label fits inside the box
$font = $null
while ($true) {
  $font = New-Object System.Drawing.Font('Segoe UI', $size, [System.Drawing.FontStyle]::Bold)
  $sz = $g.MeasureString($Label, $font, $limit, $fmt)
  if ($sz.Width -le $limit.Width -and $sz.Height -le $limit.Height) { break }
  if ($size -le 16) { break }
  $font.Dispose()
  $size = $size - 2
}

$g.DrawString($Label, $font, [System.Drawing.Brushes]::White, $area, $fmt)

$dir = Split-Path -Parent $OutFile
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
$bmp.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose(); $brush.Dispose(); $font.Dispose(); $bmp.Dispose()
Write-Output "created: $OutFile"
