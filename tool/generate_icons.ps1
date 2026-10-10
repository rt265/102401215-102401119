<#
.SYNOPSIS
    生成应用图标与启动页图片（UI 事项 9）。

.DESCRIPTION
    以 assets/Appicon.svg 为唯一图源，用本机安装的 ImageMagick 7 生成：

      * Android 传统启动图标      android/app/src/main/res/mipmap-*/ic_launcher.png
      * Android 自适应图标前景    android/app/src/main/res/mipmap-*/ic_launcher_foreground.png
      * Android 启动页图形        android/app/src/main/res/drawable-*/launch_image.png
      * iOS 应用图标             ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png
      * iOS 启动页图形           ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage*.png

    图源 SVG 的描边写的是 currentColor（librsvg 会当成黑色渲染），脚本渲染前先把它替换成
    $GlyphColor，所以 assets/Appicon.svg 本身保持原样——换图标只要换这个文件再重跑脚本。
    背景色不带进 SVG，是脚本用 ImageMagick 画上去的（圆角方块 / 纯色满幅两种）。

    脚本是可重入的：重复运行会就地覆盖同名文件，不需要手工清理。

.PARAMETER BrandColor
    背景色，默认 #00695C，与 lib/theme/app_theme.dart 里的默认主题种子色保持一致。

.PARAMETER GlyphColor
    图形颜色，默认 #FFFFFF。

.PARAMETER MagickPath
    magick.exe 的绝对路径。默认先在 PATH 里找，再扫常见安装目录。

.PARAMETER SvgPath
    图源 SVG 路径，默认 assets/Appicon.svg。

.EXAMPLE
    pwsh -File tool/generate_icons.ps1

.EXAMPLE
    pwsh -File tool/generate_icons.ps1 -BrandColor '#0B6E4F' -GlyphColor '#FFFFFF'
#>
[CmdletBinding()]
param(
    [string] $BrandColor = '#00695C',
    [string] $GlyphColor = '#FFFFFF',
    [string] $MagickPath,
    [string] $SvgPath
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- 比例常量
# 图形在 24×24 视框里只占中间约 19 个单位（加描边约 21），所以「图形框 / 画布」的比值
# 要放大一点，成品看上去才不至于缩在中间。
#
# 传统图标（Android 旧版 + iOS）：图形框占画布的 70%，实际着墨约 61%。
$IconGlyphRatio = 0.70
# 自适应图标：前景必须落在中央安全区内——108dp 画布里只有中间 66dp 的圆（半径 33dp）
# 是「任何遮罩下都不被裁」的。图形着墨最远端在图形框的 (23,23) 处，换算到画布中心是
# 0.648×图形框边长，于是 0.648 × (108 × r) ≤ 33 → r ≤ 0.4715，取 0.47。
# 这个值不是随手定的：遮罩区 72dp 里图形框占 50.8/72 ≈ 70%，与传统图标的 70% 正好一致，
# 自适应图标和旧图标看起来才会一样大。（试过 0.54，放大镜柄的圆头会被圆形遮罩切平。）
$AdaptiveGlyphRatio = 0.47
# 自适应图标前景画布相对显示尺寸的倍率：108dp / 48dp。
$AdaptiveCanvasRatio = 2.25
# 传统图标的圆角半径占边长的比例（iOS 会被系统再次裁切，只有 Android 旧版看得见这个圆角）。
$CornerRatio = 0.22

# ---------------------------------------------------------------- 前置检查
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $SvgPath) { $SvgPath = Join-Path $repoRoot 'assets\Appicon.svg' }
if (-not (Test-Path -LiteralPath $SvgPath)) { throw "找不到图源 SVG：$SvgPath" }
$SvgPath = (Resolve-Path -LiteralPath $SvgPath).Path

function Resolve-Magick {
    param([string] $Explicit)
    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit)) { throw "指定的 magick.exe 不存在：$Explicit" }
        return (Resolve-Path -LiteralPath $Explicit).Path
    }
    # 注意：不能写成 `convert`——C:\Windows\system32\convert.exe 是 Windows 的磁盘转换工具，
    # 会顶掉 ImageMagick 6 时代的同名命令。ImageMagick 7 的入口是 magick.exe。
    $onPath = Get-Command magick.exe -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA 'Programs')) |
        Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    $found = foreach ($root in $roots) {
        Get-ChildItem -LiteralPath $root -Filter 'ImageMagick*' -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'magick.exe' }
    }
    $hit = $found | Where-Object { Test-Path -LiteralPath $_ } | Sort-Object -Descending | Select-Object -First 1
    if ($hit) { return (Resolve-Path -LiteralPath $hit).Path }
    throw '没找到 ImageMagick 7 的 magick.exe。请安装 ImageMagick，或用 -MagickPath 指定绝对路径。'
}

$magick = Resolve-Magick -Explicit $MagickPath
Write-Host "ImageMagick : $magick" -ForegroundColor Cyan

# 工作目录放临时区，跑完删掉；生成物都是从这里拷进仓库的。
$work = Join-Path ([System.IO.Path]::GetTempPath()) 'lost-and-found-icons'
if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Path $work -Force | Out-Null

# 把 currentColor 换成实色，写一份临时 SVG——改的只是描边取值，几何原封不动。
$coloredSvg = Join-Path $work 'Appicon-colored.svg'
$svgText = Get-Content -LiteralPath $SvgPath -Raw
if ($svgText -notmatch 'currentColor') {
    Write-Host "提示：图源里没有 currentColor，颜色可能由 SVG 自己决定。" -ForegroundColor Yellow
}
$svgText.Replace('currentColor', $GlyphColor) | Set-Content -LiteralPath $coloredSvg -Encoding UTF8 -NoNewline

# ---------------------------------------------------------------- 渲染原语
$glyphCache = @{}

function Get-GlyphFile {
    <# 把图源渲染成边长 $Box 的透明 PNG，返回文件路径。 #>
    param([int] $Box)
    if ($Box -lt 1) { throw "图形边长不合法：$Box" }
    if ($glyphCache.ContainsKey($Box)) { return $glyphCache[$Box] }

    $out = Join-Path $work "glyph-$Box.png"
    # SVG 声明宽 32px，density 96 就是 32px；这里按目标的 4 倍栅格化再缩回来，
    # 比直接按目标尺寸栅格化干净得多（尤其 20~48px 这种很小的图标）。
    $density = 12 * $Box
    & $magick -background none -density $density $coloredSvg -resize "${Box}x${Box}" ("PNG32:" + $out)
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $out)) {
        throw "ImageMagick 渲染图形失败（边长 $Box）"
    }
    $glyphCache[$Box] = $out
    return $out
}

function New-BackgroundFile {
    <# 画一张纯色底图：square = 满幅方块（iOS 用系统遮罩），rounded = 自身带圆角（Android 旧版）。 #>
    param([int] $Size, [ValidateSet('square', 'rounded')] [string] $Shape)
    $out = Join-Path $work "bg-$Size-$Shape.png"
    if ($Shape -eq 'square') {
        & $magick -size "${Size}x${Size}" ("xc:$BrandColor") ("PNG32:" + $out)
    }
    else {
        $corner = [Math]::Max(2, [int][Math]::Round(2 * $Size * $CornerRatio))
        $last = $Size - 1
        & $magick -size "${Size}x${Size}" xc:none -fill $BrandColor `
            -draw "roundrectangle 0,0,$last,$last,$corner,$corner" ("PNG32:" + $out)
    }
    if ($LASTEXITCODE -ne 0) { throw "ImageMagick 画底图失败（$Size / $Shape）" }
    return $out
}

function Write-Icon {
    <# 应用图标：底图 + 居中图形。#>
    param(
        [int] $Size,
        [double] $GlyphRatio,
        [ValidateSet('square', 'rounded')] [string] $Shape,
        [switch] $NoAlpha,   # iOS 图标不允许带 alpha 通道
        [string] $Out
    )
    $box = [Math]::Max(1, [int][Math]::Round($Size * $GlyphRatio))
    $bg = New-BackgroundFile -Size $Size -Shape $Shape
    $prefix = if ($NoAlpha) { 'PNG24:' } else { 'PNG32:' }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null
    & $magick $bg (Get-GlyphFile -Box $box) -gravity center -composite ($prefix + $Out)
    if ($LASTEXITCODE -ne 0) { throw "ImageMagick 合成图标失败：$Out" }
    Write-Host ("  {0,-62} {1}px" -f ($Out.Replace("$repoRoot\", '')), $Size)
}

function Write-TransparentPng {
    <# 透明 PNG：只放图形（启动页用，底色由 Android layer-list / iOS storyboard 给）。 #>
    param([int] $Size, [string] $Out)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null
    Copy-Item -LiteralPath (Get-GlyphFile -Box $Size) -Destination $Out -Force
    Write-Host ("  {0,-62} {1}px" -f ($Out.Replace("$repoRoot\", '')), $Size)
}

# ---------------------------------------------------------------- Android 图标
$androidRes = Join-Path $repoRoot 'android\app\src\main\res'
# 传统图标：mdpi 48dp 起，每档 ×1.5。
$launcherSizes = [ordered]@{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }

Write-Host "`nAndroid 传统图标（ic_launcher.png）" -ForegroundColor Cyan
foreach ($density in $launcherSizes.Keys) {
    $size = $launcherSizes[$density]
    Write-Icon -Size $size -GlyphRatio $IconGlyphRatio -Shape rounded `
        -Out (Join-Path $androidRes "mipmap-$density\ic_launcher.png")
}

Write-Host "`nAndroid 自适应图标前景（ic_launcher_foreground.png）" -ForegroundColor Cyan
foreach ($density in $launcherSizes.Keys) {
    $canvas = [int][Math]::Round($launcherSizes[$density] * $AdaptiveCanvasRatio)
    $box = [Math]::Max(1, [int][Math]::Round($canvas * $AdaptiveGlyphRatio))
    $out = Join-Path $androidRes "mipmap-$density\ic_launcher_foreground.png"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out) | Out-Null
    & $magick (Get-GlyphFile -Box $box) -background none -gravity center `
        -extent "${canvas}x${canvas}" ("PNG32:" + $out)
    if ($LASTEXITCODE -ne 0) { throw "ImageMagick 生成自适应前景失败：$out" }
    Write-Host ("  {0,-62} {1}px（图形 {2}px）" -f ($out.Replace("$repoRoot\", '')), $canvas, $box)
}

# ---------------------------------------------------------------- Android 启动页图形
$splashSizes = [ordered]@{ mdpi = 128; hdpi = 192; xhdpi = 256; xxhdpi = 384; xxxhdpi = 512 }
Write-Host "`nAndroid 启动页图形（launch_image.png）" -ForegroundColor Cyan
foreach ($density in $splashSizes.Keys) {
    Write-TransparentPng -Size $splashSizes[$density] `
        -Out (Join-Path $androidRes "drawable-$density\launch_image.png")
}

# ---------------------------------------------------------------- iOS 图标
$iosIconDir = Join-Path $repoRoot 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
# 文件名 → 像素边长，与 AppIcon.appiconset/Contents.json 一一对应。
$iosIcons = [ordered]@{
    'Icon-App-20x20@1x.png'    = 20
    'Icon-App-20x20@2x.png'    = 40
    'Icon-App-20x20@3x.png'    = 60
    'Icon-App-29x29@1x.png'    = 29
    'Icon-App-29x29@2x.png'    = 58
    'Icon-App-29x29@3x.png'    = 87
    'Icon-App-40x40@1x.png'    = 40
    'Icon-App-40x40@2x.png'    = 80
    'Icon-App-40x40@3x.png'    = 120
    'Icon-App-60x60@2x.png'    = 120
    'Icon-App-60x60@3x.png'    = 180
    'Icon-App-76x76@1x.png'    = 76
    'Icon-App-76x76@2x.png'    = 152
    'Icon-App-83.5x83.5@2x.png' = 167
    'Icon-App-1024x1024@1x.png' = 1024
}
Write-Host "`niOS 应用图标（AppIcon.appiconset）" -ForegroundColor Cyan
foreach ($name in $iosIcons.Keys) {
    # 满幅方块、不带 alpha：圆角由 iOS 自己裁，带透明通道会被 App Store 打回。
    Write-Icon -Size $iosIcons[$name] -GlyphRatio $IconGlyphRatio -Shape square -NoAlpha `
        -Out (Join-Path $iosIconDir $name)
}

# ---------------------------------------------------------------- iOS 启动页图形
$iosLaunchDir = Join-Path $repoRoot 'ios\Runner\Assets.xcassets\LaunchImage.imageset'
# LaunchScreen.storyboard 里是 contentMode="center"，图片按 1x 的点数原样居中显示，
# 所以 1x 的 120px 就是屏幕上的 120pt。
$iosLaunch = [ordered]@{ 'LaunchImage.png' = 120; 'LaunchImage@2x.png' = 240; 'LaunchImage@3x.png' = 360 }
Write-Host "`niOS 启动页图形（LaunchImage.imageset）" -ForegroundColor Cyan
foreach ($name in $iosLaunch.Keys) {
    Write-TransparentPng -Size $iosLaunch[$name] -Out (Join-Path $iosLaunchDir $name)
}

Remove-Item -LiteralPath $work -Recurse -Force
Write-Host "`n完成。图标底色 $BrandColor，图形色 $GlyphColor，图源 $SvgPath" -ForegroundColor Green
