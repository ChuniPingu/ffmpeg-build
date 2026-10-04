param(
    [Parameter(Mandatory = $true)][string]$ReleaseTag,
    [string]$Repository = 'ChuniPingu/ffmpeg-build'
)
$ErrorActionPreference = 'Stop'
if ($ReleaseTag -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+(?:[-.][A-Za-z0-9]+)*$') { throw 'Expected an explicit version tag.' }
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$binary = Join-Path $root 'bin/ffmpeg.exe'
$release = Join-Path $root ('artifacts/' + $ReleaseTag)
if (Test-Path -LiteralPath $release) { throw "Release output already exists: $release" }
[IO.Directory]::CreateDirectory($release) | Out-Null
& (Join-Path $PSScriptRoot 'smoke-audio.ps1') -Executable $binary
$sourceCommit = (& git -C $root rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Unable to read build source commit.' }
$baseline = (Get-Content -LiteralPath (Join-Path $root 'vcpkg-configuration.json') -Raw | ConvertFrom-Json).'default-registry'.baseline
$version = (Get-Content -LiteralPath (Join-Path $root 'vcpkg/ffmpeg/vcpkg.json') -Raw | ConvertFrom-Json).version
$vcpkgCommit = (& git -C $env:VCPKG_ROOT rev-parse HEAD).Trim()
$releaseUrl = "https://github.com/$Repository/releases/tag/$ReleaseTag"
$sourceUrl = "https://github.com/$Repository/releases/download/$ReleaseTag/ffmpeg-build-sources.zip"
$metadata = [ordered]@{
    schemaVersion = 1; release = $ReleaseTag; repository = "https://github.com/$Repository"
    sourceCommit = $sourceCommit; ffmpegVersion = $version; vcpkgBaseline = $baseline; vcpkgCommit = $vcpkgCommit
    triplet = 'x64-windows-static'; sha256 = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant()
    versionOutput = @(& $binary -version); buildConfiguration = @(& $binary -buildconf 2>&1 | ForEach-Object { "$_" })
}
$metadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $root 'bin/build-metadata.json') -Encoding utf8
@"
# FFmpeg corresponding source information

This binary is from [$ReleaseTag]($releaseUrl), built from [$sourceCommit](https://github.com/$Repository/tree/$sourceCommit).

The release includes [the build scripts, overlay, patches and pinned manifests]($sourceUrl),
the matching upstream source archive (ffmpeg-$version-sources.tar.gz), and build-metadata.json.
The source archive's SHA-512 is pinned in vcpkg/ffmpeg/portfile.cmake. Apply its listed patches
and use the included build scripts and triplet to reproduce this LGPL configuration.
All release files have SHA-256 entries in SHA256SUMS.txt.

FFmpeg is licensed under LGPL-2.1-or-later. See FFMPEG-COPYRIGHT.txt and NOTICE.md.
"@ | Set-Content -LiteralPath (Join-Path $root 'bin/legal/FFMPEG-SOURCE-OFFER.md') -Encoding utf8

# Archive the exact producer commit and retain the source tarball verified by the overlay.
& git -C $root archive --format=zip "--output=$(Join-Path $release 'ffmpeg-build-sources.zip')" $sourceCommit
if ($LASTEXITCODE -ne 0) { throw 'Unable to archive release build sources.' }
$port = Get-Content -LiteralPath (Join-Path $root 'vcpkg/ffmpeg/portfile.cmake') -Raw
$expectedSourceHash = [regex]::Match($port, 'SHA512\s+([0-9a-f]{128})').Groups[1].Value
if ($expectedSourceHash.Length -ne 128) { throw 'Missing pinned FFmpeg source hash.' }
$downloads = if ([string]::IsNullOrWhiteSpace($env:VCPKG_DOWNLOADS)) { Join-Path $env:VCPKG_ROOT 'downloads' } else { $env:VCPKG_DOWNLOADS }
$sourceArchive = Get-ChildItem -LiteralPath $downloads -File -Filter '*ffmpeg*.tar.gz' |
    Where-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA512).Hash -eq $expectedSourceHash } | Select-Object -First 1
if ($null -eq $sourceArchive) { throw 'Verified upstream FFmpeg source archive was not found in the build cache.' }
Copy-Item -LiteralPath $sourceArchive.FullName -Destination (Join-Path $release "ffmpeg-$version-sources.tar.gz")
Copy-Item -LiteralPath (Join-Path $root 'bin/build-metadata.json') -Destination $release
Compress-Archive -Path (Join-Path $root 'bin/*') -DestinationPath (Join-Path $release 'ffmpeg-win-x64.zip') -CompressionLevel Optimal
$checksums = @(Get-ChildItem -LiteralPath $release -File | Sort-Object Name | ForEach-Object {
    (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.Name
})
$checksums | Set-Content -LiteralPath (Join-Path $release 'SHA256SUMS.txt') -Encoding ascii
Write-Host "Prepared verified release: $release"
