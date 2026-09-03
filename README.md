# PenguinTools FFmpeg

This directory owns the minimal standalone FFmpeg build used for audio validation and conversion.
The build enables only the protocols, demuxers, decoders, filters, WAV encoder, and muxers required
by PenguinTools.

## Requirements

- Visual Studio C++ x64 build tools
- A Microsoft vcpkg checkout selected by `VCPKG_ROOT`

## Build

```powershell
./scripts/build.ps1
```

The script installs the pinned custom vcpkg port for `x64-windows-static` and publishes
`bin/ffmpeg.exe` with the applicable notices in `bin/legal/`.

The build scripts and overlay are licensed under the [MIT License](LICENSE). FFmpeg retains
its own LGPL license; redistribution details are in [`legal/`](legal/).
