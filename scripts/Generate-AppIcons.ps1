[CmdletBinding()]
param(
    [string]$OutputDirectory = "ChatGPTLegacy/Resources/Assets.xcassets/AppIcon.appiconset"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$target = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputDirectory))
if (-not $target.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Icon output must stay inside the repository."
}
[System.IO.Directory]::CreateDirectory($target) | Out-Null

function New-LegacyIcon {
    param([int]$Size, [string]$Path)

    $bitmap = [System.Drawing.Bitmap]::new(
        $Size,
        $Size,
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        $bounds = [System.Drawing.Rectangle]::new(0, 0, $Size, $Size)
        $gradient = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            $bounds,
            [System.Drawing.Color]::FromArgb(24, 42, 37),
            [System.Drawing.Color]::FromArgb(8, 19, 16),
            42.0
        )
        $graphics.FillRectangle($gradient, $bounds)
        $gradient.Dispose()

        $haloPen = [System.Drawing.Pen]::new(
            [System.Drawing.Color]::FromArgb(38, 74, 204, 176),
            [Math]::Max(1.0, $Size * 0.006)
        )
        $graphics.DrawEllipse(
            $haloPen,
            [single]($Size * 0.13),
            [single]($Size * 0.13),
            [single]($Size * 0.74),
            [single]($Size * 0.74)
        )
        $haloPen.Dispose()

        $railPen = [System.Drawing.Pen]::new(
            [System.Drawing.Color]::FromArgb(74, 204, 176),
            [single][Math]::Max(2.0, $Size * 0.066)
        )
        $railPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $railPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $railPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        [System.Drawing.PointF[]]$points = @(
            [System.Drawing.PointF]::new([single]($Size * 0.31), [single]($Size * 0.25)),
            [System.Drawing.PointF]::new([single]($Size * 0.31), [single]($Size * 0.69)),
            [System.Drawing.PointF]::new([single]($Size * 0.70), [single]($Size * 0.69))
        )
        $graphics.DrawLines($railPen, $points)
        $railPen.Dispose()

        $dotSize = [single]($Size * 0.105)
        $dotBrush = [System.Drawing.SolidBrush]::new(
            [System.Drawing.Color]::FromArgb(74, 204, 176)
        )
        $graphics.FillEllipse(
            $dotBrush,
            [single]($Size * 0.69 - $dotSize / 2),
            [single]($Size * 0.28 - $dotSize / 2),
            $dotSize,
            $dotSize
        )
        $dotBrush.Dispose()

        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

foreach ($size in @(40, 58, 60, 80, 87, 120, 180, 1024)) {
    New-LegacyIcon -Size $size -Path (Join-Path $target "icon-$size.png")
}

Write-Host "Generated opaque app icons in $target"
