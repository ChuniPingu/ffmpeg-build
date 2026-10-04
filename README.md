# PenguinTools FFmpeg

## Prerequisites

- Windows with Visual Studio C++ x64 build tools
- PowerShell
- A Microsoft vcpkg checkout containing `vcpkg.exe`

The vcpkg baseline and build configuration are recorded in [vcpkg-configuration.json](vcpkg-configuration.json) and [vcpkg.json](vcpkg.json).

## Quick start

From the repository root:

```powershell
$env:VCPKG_ROOT = 'C:\path\to\vcpkg'
./scripts/build.ps1
./bin/ffmpeg.exe -version
```

The build publishes `bin/ffmpeg.exe` and its notices under `bin/legal/`.

See [build configuration and maintenance](docs/build.md) for the custom overlay, output layout, and port refresh workflow.

## License

Build scripts and the overlay use the [MIT license](LICENSE). FFmpeg retains its LGPL license; see the [notice](legal/NOTICE.md) and [corresponding-source information](legal/FFMPEG-SOURCE-OFFER.md).
