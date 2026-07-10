param(
  [Parameter(Mandatory=$true)]
  [string]$SourceImage,

  [string]$OutputPath = "",
  [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host ""
  Write-Host "Usage: .\create_windows_app_icon.ps1 -SourceImage <path> [-OutputPath <path>]"
  Write-Host ""
  Write-Host "Generates a multi-size Windows ICO file from a PNG or JPEG source image."
  Write-Host "No external tools (ImageMagick, etc.) required - uses built-in .NET only."
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -SourceImage  Path to the source PNG or JPEG image (required)"
  Write-Host "  -OutputPath   Path for the output ICO file (default: windows\runner\resources\app_icon.ico)"
  Write-Host ""
  Write-Host "The source image should be at least 256x256 pixels for best results."
  Write-Host "PNG transparency is preserved in the ICO output."
  exit 0
}

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $projectRoot "windows\runner\resources\app_icon.ico"
}

if (-not (Test-Path -LiteralPath $SourceImage -PathType Leaf)) {
  Write-Host "FAIL: source image not found: $SourceImage" -ForegroundColor Red
  exit 1
}

$ext = [System.IO.Path]::GetExtension($SourceImage).ToLowerInvariant()
if ($ext -ne ".png" -and $ext -ne ".jpg" -and $ext -ne ".jpeg") {
  Write-Host "FAIL: source image must be PNG or JPEG (got: $ext)" -ForegroundColor Red
  exit 1
}

Add-Type -AssemblyName System.Drawing

try {
  $sourceImage = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $SourceImage).Path)
} catch {
  Write-Host "FAIL: unable to load source image: $_" -ForegroundColor Red
  exit 1
}

$sourceWidth = $sourceImage.Width
$sourceHeight = $sourceHeight = $sourceImage.Height
Write-Host "Source image: ${sourceWidth}x${sourceHeight} ($ext)"

if ($sourceWidth -lt 16 -or $sourceHeight -lt 16) {
  Write-Host "FAIL: source image is too small (minimum 16x16)" -ForegroundColor Red
  $sourceImage.Dispose()
  exit 1
}

$targetSizes = @(16, 32, 48, 64, 128, 256)

function ResizeImage {
  param(
    [System.Drawing.Image]$Image,
    [int]$TargetSize
  )
  $bitmap = New-Object System.Drawing.Bitmap($TargetSize, $TargetSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $graphics.DrawImage($Image, 0, 0, $TargetSize, $TargetSize)
  $graphics.Dispose()
  return $bitmap
}

function ImageToPngBytes {
  param(
    [System.Drawing.Image]$Image
  )
  $ms = New-Object System.IO.MemoryStream
  $Image.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $bytes = $ms.ToArray()
  $ms.Dispose()
  return $bytes
}

$icoEntries = @()

foreach ($size in $targetSizes) {
  if ($size -le $sourceWidth -and $size -le $sourceHeight) {
    $resized = ResizeImage -Image $sourceImage -TargetSize $size
    $pngBytes = ImageToPngBytes -Image $resized
    $resized.Dispose()
    $icoEntries += @{
      Size = $size
      PngData = $pngBytes
    }
    Write-Host "  Generated ${size}x${size} PNG ($($pngBytes.Length) bytes)"
  }
}

$sourceImage.Dispose()

if ($icoEntries.Count -eq 0) {
  Write-Host "FAIL: no icon entries generated" -ForegroundColor Red
  exit 1
}

$outputDir = [System.IO.Path]::GetDirectoryName($OutputPath)
if (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
  New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)

$bw.Write([System.UInt16]0)
$bw.Write([System.UInt16]1)
$bw.Write([System.UInt16]$icoEntries.Count)

$directorySize = 16 * $icoEntries.Count
$imageDataOffset = 6 + $directorySize

$currentOffset = $imageDataOffset
foreach ($entry in $icoEntries) {
  $widthByte = if ($entry.Size -eq 256) { [System.Byte]0 } else { [System.Byte]$entry.Size }
  $heightByte = if ($entry.Size -eq 256) { [System.Byte]0 } else { [System.Byte]$entry.Size }
  $bw.Write($widthByte)
  $bw.Write($heightByte)
  $bw.Write([System.Byte]0)
  $bw.Write([System.Byte]0)
  $bw.Write([System.UInt16]1)
  $bw.Write([System.UInt16]32)
  $bw.Write([System.UInt32]$entry.PngData.Length)
  $bw.Write([System.UInt32]$currentOffset)
  $currentOffset += $entry.PngData.Length
}

foreach ($entry in $icoEntries) {
  $bw.Write($entry.PngData)
}

$bw.Flush()
$icoBytes = $ms.ToArray()
$bw.Close()
$ms.Close()

[System.IO.File]::WriteAllBytes($OutputPath, $icoBytes)

Write-Host ""
Write-Host "SUCCESS: ICO file created at $OutputPath" -ForegroundColor Green
Write-Host "  Entries: $($icoEntries.Count) ($($icoEntries | ForEach-Object { "$($_.Size)x$($_.Size)" } | Join-String -Separator ', '))"
Write-Host "  File size: $($icoBytes.Length) bytes"
