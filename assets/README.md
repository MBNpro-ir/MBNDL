# Bundled Windows download tools

Windows releases are usable offline on first launch. CMake packages these
files under `data/tools` in the Windows release (not in Flutter's shared asset
bundle), and the app copies them into the user's writable `MBNDownloader`
application-data directory:

- `yt-dlp.exe` — the official standalone yt-dlp executable.
- `ffmpeg-windows-x64.zip` — a minimal FFmpeg bootstrap containing only
  `ffmpeg.exe`, `ffprobe.exe`, the upstream license and source metadata.

The old initial-download screen is not used. After the offline bootstrap,
updates remain available inside Settings:

- yt-dlp is downloaded from the selected official stable/nightly/master
  release channel and verified with the release SHA-256 digest when supplied.
- FFmpeg reads the official Windows Essentials ZIP with HTTP byte ranges and
  transfers only `ffmpeg.exe` and `ffprobe.exe`. It does not download FFplay,
  HTML documentation or presets.

## Refreshing release assets

1. Replace `yt-dlp.exe` with the desired official Windows release binary.
2. From the Flutter project root, run:

   ```powershell
   dart run tool/refresh_windows_bootstrap.dart
   ```

The refresh tool downloads and CRC-verifies only the required entries, embeds
the upstream license/source record, and recreates
`assets/ffmpeg-windows-x64.zip`.
