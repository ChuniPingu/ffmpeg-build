$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

. (Join-Path $PSScriptRoot "import-build-environment.ps1")
& (Join-Path $PSScriptRoot "prepare-vcpkg.ps1")

$triplet = "x64-windows-static"
$installedRoot = Join-Path $env:VCPKG_ROOT "installed\$triplet"
$source = Join-Path $installedRoot "tools\ffmpeg\ffmpeg.exe"
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "FFmpeg executable is missing after the vcpkg build: $source"
}

$publishRoot = Join-Path $root "bin"
$resolvedPublishRoot = [IO.Path]::GetFullPath($publishRoot)
if (-not $resolvedPublishRoot.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing cleanup outside the build repository: $resolvedPublishRoot"
}
if (Test-Path -LiteralPath $publishRoot) {
    Remove-Item -LiteralPath $publishRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $publishRoot -Force | Out-Null
Copy-Item -LiteralPath $source -Destination $publishRoot -Force

$legalOutput = Join-Path $publishRoot "legal"
New-Item -ItemType Directory -Path $legalOutput -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root "legal\NOTICE.md") -Destination $legalOutput -Force
Copy-Item -LiteralPath (Join-Path $root "legal\FFMPEG-SOURCE-OFFER.md") -Destination $legalOutput -Force

$copyright = Join-Path $installedRoot "share\ffmpeg\copyright"
if (-not (Test-Path -LiteralPath $copyright -PathType Leaf)) {
    throw "FFmpeg copyright notice is missing: $copyright"
}
Copy-Item -LiteralPath $copyright -Destination (Join-Path $legalOutput "FFMPEG-COPYRIGHT.txt") -Force
