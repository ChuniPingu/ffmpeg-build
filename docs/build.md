# Build configuration

The repository supplies a custom vcpkg FFmpeg port for PenguinTools. It enables the audio protocols, codecs, parsers, filters, and WAV/null muxers needed by the application.

## Configuration

| Path                                                            | Purpose                                               |
| --------------------------------------------------------------- | ----------------------------------------------------- |
| [vcpkg-configuration.json](../vcpkg-configuration.json)         | Registry baseline and overlay directory               |
| [vcpkg.json](../vcpkg.json)                                     | FFmpeg dependency with `custom` and `ffmpeg` features |
| [vcpkg/ffmpeg/](../vcpkg/ffmpeg/)                               | Port configuration, source selection, and patches     |
| [scripts/ffmpeg-port-overlay/](../scripts/ffmpeg-port-overlay/) | Project patches reapplied when refreshing the port    |

The custom port starts with `--disable-everything` and explicitly enables the selected audio components. Inspect the port and project patch for the exact selection; keep version and baseline changes in configuration.

## Build and output

[build.ps1](../scripts/build.ps1) imports the Visual Studio x64 environment, installs the configured port for `x64-windows-static`, and copies the executable and notices into `bin/`. `VCPKG_ROOT` selects the vcpkg checkout and is retained when the Visual Studio environment is imported.

The executable is read from `<VCPKG_ROOT>/installed/x64-windows-static/tools/ffmpeg/`. Each build recreates the publish directory:

```text
bin/
  ffmpeg.exe
  legal/
    NOTICE.md
    FFMPEG-SOURCE-OFFER.md
    FFMPEG-COPYRIGHT.txt
```

The copyright file is copied from the installed FFmpeg port. Distribute the applicable notices with the executable; see [source information](../legal/FFMPEG-SOURCE-OFFER.md).

## Refresh the overlay

The selected vcpkg checkout must contain the registry baseline commit. When updating the baseline or refreshing the port, run:

```powershell
./scripts/refresh-ffmpeg-port.ps1
```

The script exports `ports/ffmpeg` from that baseline, replaces the local overlay, and reapplies the project patches. Review the resulting port changes and rebuild before distributing the output.
