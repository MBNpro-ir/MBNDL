# 📝 MBNDL Changelog

All notable user-facing and developer-facing changes are documented in this file.

## 🎉 1.0.0 — 2026-08-14

### ✨ New

- 🪟 Added a Windows close decision with **Minimize to tray**, **Exit**, and **Cancel**.
- 🖱️ Added a Windows tray icon with left-click restore/focus and right-click **Open** / **Close** actions.
- 🎨 Made Material You the default color system and kept Material 3 Expressive styling.
- 📄 Replaced the quality popup with a full-screen multi-format picker.
- 🎬 Added simultaneous selection of several complete, video-only, and audio-only formats.
- 🪄 Added Smart merge for combining exactly one separate video and audio stream.
- 🗂️ Rebuilt History with search, status/date/file filters, sorting, grid/list views, summary statistics, retry, cancel, open, share, and artifact-aware deletion.
- 🖼️ Added persistent cover, subtitle, related-file, and Android MediaStore metadata to download history.
- 🧭 Added touch swipe navigation between Home, History, and Settings.
- 🛡️ Added a blocking first-run Android access setup screen for permissions actually required by the OS version.
- 💬 Added user-friendly yt-dlp and FFmpeg error mapping with suggested recovery steps.

### 🎯 Improved

- 🏠 Redesigned Home around a clear paste → inspect → select → download flow.
- 🔗 Long links now wrap across several lines and remain visible while editing.
- 🧹 Removed redundant Video/Audio/Playlist capability tags under the link field.
- 🌗 Fixed unreadable text in the System theme preview when the active app theme is light.
- 📥 Changed the public default destination to `Downloads/MBNDL`.
- 🧾 Added unique format IDs to output filenames so multi-quality downloads cannot overwrite one another.
- 📱 Limited Android release ABIs to legacy ARM 32-bit and modern ARM 64-bit.
- 🪪 Changed the Android application ID to `com.mbn.dl` and standardized product branding as MBNDL.

### 🧰 Bundled tools

- ✅ Windows releases start offline with yt-dlp, FFmpeg, and FFprobe already packaged.
- 🔄 Internal yt-dlp and FFmpeg updates remain available.
- 📦 The FFmpeg bootstrap/update path transfers only `ffmpeg.exe` and `ffprobe.exe`, not FFplay, documentation, presets, or the full distribution bundle.

### 🚀 Delivery

- 🏷️ Set the application version to `1.0.0+1`.
- 🤖 Added an automated tagged-release workflow for Windows x64, Android ARM32, and Android ARM64 artifacts.
- 📚 Added bilingual end-user and developer documentation.
