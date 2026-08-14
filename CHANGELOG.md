# 📝 MBNDL Changelog

All notable user-facing and developer-facing changes are documented in this file.

## 🔐 1.0.3 — 2026-08-14

### ✨ New

- 👤 Added **Settings → YouTube Accounts** with encrypted storage for up to three YouTube/YouTube Music cookie profiles, account switching, refresh, disable, and secure sign-out.
- 🧠 Added an automatic recovery prompt for YouTube bot-check and sign-in-required errors.
- 🌐 Added the safe yt-dlp-supported sign-in flow: external official browser login, YouTube-only Netscape cookie validation, and just-in-time cookie materialization only for YouTube URLs.
- ⚠️ Added prominent account restriction/ban and sensitive-cookie warnings based on yt-dlp’s official guidance.
- 🎚️ Added Balanced, Fast Download, Unstable Connection, Gentle YouTube, and Limited Bandwidth transport presets.
- ✅ Added filesystem and Android MediaStore detection for previously downloaded format IDs; matching qualities are highlighted green before selection.
- 📋 Added explicit `(copy N)` duplicate names and confirmation instead of overwriting an existing quality.

### 🛠️ Fixed

- 📂 Replaced Android’s optimistic permission check with real private-folder and public `MediaStore.Downloads` write probes on Android 10+, plus legacy public-folder verification on Android 7–9.
- 📱 Restored a non-empty app-owned working path while keeping completed files visible in `Downloads/MBNDL` on modern Android, including Android 16.
- 🔎 Added public MediaStore queries so existing-quality detection does not depend only on app history or a private working copy.
- 🔒 Removed plaintext cookie content from settings JSON, disabled Android backup for authentication material, and delete temporary cookie files after each yt-dlp operation.
- 🧩 Made playlist handling automatic during inspection/download and removed manual playlist controls.
- 🧹 Removed workflow-owned file, overwrite, thumbnail, post-processing, archive, live, and generic browser-cookie controls from yt-dlp Settings.
- 💾 Fixed Quick Presets and custom presets so they no longer erase the selected download path or unrelated settings.
- 💬 Improved YouTube authentication error mapping and preserved raw yt-dlp failures for intelligent recovery.

### 🎨 Refined

- 🪪 Changed the Settings hero from **Make MBN yours** to **Make MBNDL yours**.
- 🧰 Reduced yt-dlp Settings to focused Presets, Connection, Captions, and Advanced tabs.
- 📝 Made subtitle language, generated-caption, and output-format choices effective only when **Save subtitles** is selected in the format screen.

### 🚀 Delivery

- 🏷️ Set the application version to `1.0.3+3`.
- 🤖 Revalidated Windows x64 and Android ARM release paths before starting the tagged release workflow.

## 🚀 1.0.1 — 2026-08-14

### 🛠️ Fixed

- 🧭 Limited horizontal page gestures to the exact Home, Downloads, and Settings routes. Swiping inside nested yt-dlp settings no longer jumps to History.
- 📥 Replaced fire-and-forget download starts with a persistent serial queue that moves every item to Preparing and records early initialization failures instead of leaving it on Queued.
- 🔁 Routed retry and cancellation through the same queue and restored interrupted previous-session items with a clear retry message.

### ✨ New

- 🔄 Added automatic application update checks and optional background downloads on Android and Windows.
- 📱 Added automatic ARM32/ARM64 APK selection, Android 7+ compatible secure APK sharing, unknown-source permission handling, and the system package installer.
- 🪟 Added a bundled `updater.exe` sidecar that waits for MBNDL to close, installs the new Windows bundle, and reopens the app.
- 🛡️ Added GitHub release-asset SHA-256 verification and persistent Android release signing for future in-place upgrades.
- ⚙️ Added **Settings → App Updates** controls for automatic checks, background downloads, manual checks, download progress, and installation.

### 🎨 Redesigned

- 🗂️ Rebuilt History again as a mobile-first Downloads library with grouped dates, clear status views, focused filters, logical primary actions, missing-file detection, and an artifact-rich details sheet.
- 🖼️ Made main media, covers, subtitles, related files, published Android copies, codecs, source links, and full failure text easier to discover.

### 🚀 Delivery

- 🏷️ Set the application version to `1.0.1+2`.
- 🔐 Added CI-only Android signing secrets so releases from 1.0.1 onward keep one upgrade-compatible certificate.
- ⚠️ Android 1.0.0 users need one uninstall/reinstall because that earlier artifact used an ephemeral development key.

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
