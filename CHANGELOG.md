# 📝 MBNDL Changelog

All notable user-facing and developer-facing changes are documented in this file.

## 🩹 1.0.8 — 2026-08-15

### 📱 Android format inspection

- 🩹 Fixed Android format inspection crashing when the yt-dlp bridge serializes numeric metadata such as `quality`, FPS, bitrate, sample rate, dimensions, or preference values as strings. Numeric strings are parsed safely, while labels and non-finite sentinel values are ignored.
- 🏷️ Set the application version to `1.0.8+8`.

## 🔔 1.0.7 — 2026-08-15

### 🧭 Overlays and safe navigation

- 🪟 Moved every bottom sheet to the root overlay so theme choices, filters, and download actions always open above the floating navigation.
- 👤 Lifted the YouTube account import action into the safe interactive area instead of allowing the glass capsule to cover it.
- 🫧 Set the Liquid Glass baseline to 4 px blur, 20% tint opacity, 100% vibrancy, zero refraction, chromatic edges on, and depth off; existing 1.0.6 glass users receive the corrected baseline once.
- 🧹 Removed the ineffective manual Glass Quality selector and made renderer quality automatic per platform.

### 🔔 Event notifications

- ✨ Replaced every legacy SnackBar with a unified animated in-app notification surface for information, success, warning, error, download, and update events.
- 📍 Kept notifications above the floating navigation, with Reduced Motion support, swipe-safe dismissal, event icons, concise actions, and smooth entrance/exit animation.
- 🚀 Made update notifications open and focus **Settings → App updates**; download start, completion, failure, and cancellation events now open Downloads.

### 🎞️ Rich format and file details

- 🌍 Added multilingual audio labels using yt-dlp’s stream `language` metadata, showing a flag plus the exact language/region code for YouTube tracks.
- 📊 Added exact dimensions, exact/estimated size, total bitrate, FPS, HDR/dynamic range, channel layout, sample rate, protocol, format note, raw video codec, and raw audio codec to format choices.
- 📁 Expanded downloaded-file details with output type, format ID, quality, container, resolved file size, elapsed time, file name, and folder.
- 🏷️ Set the application version to `1.0.7+7`.

## 🫧 1.0.6 — 2026-08-15

### 🎨 Liquid Glass navigation

- 🔮 Replaced the simulated global translucency with a GPU shader renderer that provides live refraction and a morphing lens on Android Impeller, plus a stable single-lens Skia fallback on Windows.
- 🧭 Limited Liquid Glass strictly to the bottom navigation controls; Home, Settings, dialogs, cards, inputs, and wide-screen navigation rails remain clear Material surfaces.
- 📐 Kept page content scrolling visibly behind the floating controls so refraction has a real backdrop, added a short transparent fade, and placed clearance only at the end of each scrollable so its final row still stops fully above the bar.
- 🌫️ Made the non-glass Material bar compact, translucent, and backdrop-aware as well, without applying the Liquid Glass shader or hiding content beneath it.
- 🪄 Added a smooth scroll-direction animation: the bottom capsule becomes compact while moving down a page and expands again when moving up.
- 💎 Added continuous Apple-style capsule geometry, optical rim lighting, content-aware tint, chromatic dispersion, magnification, and an animated refracting selection pill.
- ♿ Rebuilt Motion as clear System, Full, and Reduced choices; Full and Reduced now explicitly override the platform preference, while reduced mode removes route, theme, selection-pill, and floating-navigation animation immediately.

### 🎞️ Format selection and merging

- 🧩 Rebuilt format selection around simple resolution groups such as `720p`, with compact codec/container variants inside each group and bitrate groups for audio.
- 📱 Reduced header, cards, options, and action sizes so the complete workflow remains understandable and usable on narrow phones.
- ✅ Preserved multi-selection, downloaded-before highlighting, copy confirmation, covers, and subtitles in the new layout.
- 🧠 Made Smart Merge explicitly require one video plus one audio stream and report one final output.
- 🛠️ Replaced the legacy two-process “separate” path with one yt-dlp `video+audio` invocation; FFmpeg now produces one final file and yt-dlp is instructed to remove intermediate streams and fragments on Android and Windows.

### 🚀 Delivery

- 🏷️ Set the application version to `1.0.6+6`.
- ⚡ Changed the release workflow to run only once per `v*` tag, removed the `main` trigger and manual duplicate path, and removed the slow `flutter doctor -v` cache check.
- ♻️ Kept Flutter/pub cache restore, target-artifact validation, automatic broken-cache deletion, rebuild, and save behavior.

## ✨ 1.0.5 — 2026-08-15

### 🎵 Sources and networking

- 🎧 Added transparent Spotify smart matching for tracks, albums, playlists, artist Top tracks, episodes, and shows: public metadata is expanded into individual jobs and matched against YouTube/YouTube Music with a visible source warning.
- 🌍 Added explicit direct-source support and classification for YouTube Music, SoundCloud, Bandcamp, Audiomack, Audius, Mixcloud, Apple Podcasts, Internet Archive, and other yt-dlp extractors.
- 🪟 Added live Windows WinINet/System Proxy discovery before every inspection and download, including protocol mappings, SOCKS, bypass rules, direct fallback, and manual-proxy precedence.

### 🧾 Logging and portability

- 🧠 Replaced fragmented text logs with newline-delimited structured events so multiline errors and stack traces remain attached to the correct severity.
- 🎚️ Corrected log thresholds and all six viewer filters; yt-dlp/FFmpeg `ERROR:` output is no longer mislabeled as a warning.
- 🔒 Added automatic log redaction for cookie paths, authentication headers, and credentialed proxy URLs.
- 💾 Upgraded settings backups to schema 2 with current yt-dlp settings, custom presets, appearance, close behavior, diagnostics, and updater choices; imports are validated before writing and apply immediately.
- 🛡️ Excluded account cookies, proxy credentials, history, permissions, device-specific paths, and custom command arguments from portable backups.

### 🎨 Appearance and motion

- 🫧 Added optional **Liquid Glass (Beta)** surfaces using Flutter-native live backdrop blur, adaptive/efficient/balanced/vivid quality, opacity, vibrancy, theme-derived tint, lens-edge refraction, chromatic edging, and depth.
- 🩵 Refreshed the default fallback palette to aqua Material 3 Expressive and added floating rounded navigation, translucent large-screen rails, expressive page transitions, and a complete reduced-motion mode.
- 📱 Added a responsive Appearance page and narrow-phone regression coverage; glass controls reflow safely at 360 px while wide layouts retain compact rows.

### 🛠️ Fixed

- 📂 Removed false “folder could not be opened” messages on Android and Windows by treating an accepted system activity/shell launch as success instead of waiting for an unreliable process result.
- 🎨 Applied the new surface system to the Home download workspace, Settings sections, primary navigation, dialogs, cards, and both compact and wide layouts.

### 🚀 Delivery

- 🏷️ Set the application version to `1.0.5+5`.
- ✅ Added regression tests for semantic logging, secret redaction, WinINet proxy parsing, source classification, Spotify live resolution, backup coverage, and Liquid Glass narrow layouts.
- 🤖 Revalidated the Windows x64 and Android ARM32/ARM64 release pipeline before starting the tagged release workflow.

## 🖥️ 1.0.4 — 2026-08-15

### ✨ New

- 🧠 Added **Remember this selection** to the Windows close dialog and a persistent **Settings → Appearance & behavior → When closing the window** choice.
- ⚡ Added Quick Presets directly to Home, with one-tap Balanced, Fast, Unstable Network, Gentle YouTube, and Limited Data modes plus a shortcut to detailed yt-dlp controls.
- ☑️ Added discoverable multi-select History actions for retrying eligible downloads, cancelling active jobs, and removing several entries and their related files together.
- 📡 Connected documented yt-dlp controls for extractor retries, format URL verification, HLS MPEG-TS, live-from-start, and waiting for scheduled media.
- 🌐 Expanded subtitle language input to support yt-dlp expressions such as `en.*`, `all`, and `-live_chat`.

### 🛠️ Fixed

- 🪟 Restored the native Windows Maximize command by removing the runner code that blocked `SC_MAXIMIZE` and imposed a fixed maximum window size.
- 🎛️ Removed the unnecessary FFmpeg minimal-toolset explanation from Settings.
- 🧭 Kept primary-page swipe navigation on compact layouts while moving tablets and wide windows to more appropriate rail navigation.

### 🎨 Redesigned

- 🧩 Reordered Settings around Downloads, Appearance, Updates, Diagnostics, Engines, and Backups, using a compact two-column workspace on wide screens.
- 🖥️ Increased Home and History workspace widths, added two-column History cards on large displays, and made detailed yt-dlp sections responsive.
- 🏷️ Replaced the branded Settings slogan with the clearer **Download your way** heading.

### 🚀 Delivery

- 🏷️ Set the application version to `1.0.4+4`.
- 🔐 Regenerated desktop secure-storage plugin registration so encrypted YouTube account storage is available in packaged desktop builds.
- 🤖 Revalidated the shared-cache Windows x64 and Android ARM32/ARM64 release pipeline before starting the tagged workflow.

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
