<div align="center">

# ⬇️ MBNDL

### A friendly yt-dlp download manager for Windows and Android

[![Release](https://img.shields.io/github/v/release/MBNpro-ir/MBNDL?display_name=tag&style=for-the-badge&logo=github)](https://github.com/MBNpro-ir/MBNDL/releases/latest)
[![Build](https://img.shields.io/github/actions/workflow/status/MBNpro-ir/MBNDL/release.yml?style=for-the-badge&logo=githubactions&label=release)](https://github.com/MBNpro-ir/MBNDL/actions/workflows/release.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.44.6-02569B?style=for-the-badge&logo=flutter)
![Platforms](https://img.shields.io/badge/Windows_x64_%7C_Android_ARM-6750A4?style=for-the-badge)

[🪟 Download for Windows x64](https://github.com/MBNpro-ir/MBNDL/releases/latest/download/MBNDL-Windows-x64.zip)
·
[📱 Android 32-bit](https://github.com/MBNpro-ir/MBNDL/releases/latest/download/MBNDL-Android-arm32.apk)
·
[📱 Android 64-bit](https://github.com/MBNpro-ir/MBNDL/releases/latest/download/MBNDL-Android-arm64.apk)

</div>

## 🚀 End-user guide

MBNDL lets you inspect a supported media link before downloading anything. You can select several complete formats, several separate video/audio streams, or ask MBNDL to intelligently merge one video stream with one audio stream.

### Windows

1. Download `MBNDL-Windows-x64.zip` from the latest release.
2. Extract the whole ZIP to a folder; do not run the executable from inside the archive.
3. Open `MBNDL.exe`.
4. Paste a link, select **Inspect formats**, choose one or more outputs, then select **Add to downloads**.
5. Find completed files in `Downloads/MBNDL` or open them from **History**.

✅ `yt-dlp`, `ffmpeg.exe`, and `ffprobe.exe` are included in the Windows release. The user never has to visit a setup/download page. Updates for yt-dlp and FFmpeg remain available inside **Settings → Download engines**.

MBNDL reads the active Windows WinINet/System Proxy immediately before every link inspection and every download. HTTP, HTTPS, SOCKS, protocol-specific proxy lists, and Windows bypass rules are understood. If the system proxy is disabled or empty, the request stays direct; a proxy entered manually in yt-dlp Settings always takes priority.

When closing MBNDL on Windows, choose **Minimize to tray**, **Exit**, or **Cancel**. Enable **Remember this selection** to reuse that choice; it can be changed later under **Settings → Appearance & behavior**. A left-click on the tray icon restores and focuses the window; right-click exposes **Open** and **Close**.

> Windows may display a SmartScreen notice for community-built unsigned releases. Verify that the file came from this repository’s Releases page before running it.

### Android

1. Choose the APK that matches the device:
   - `arm32` for older 32-bit ARM phones.
   - `arm64` for modern 64-bit ARM phones.
2. Allow installation from your browser or file manager when Android asks.
3. On first launch, complete the access setup screen.
4. Paste a link and choose the desired formats.
5. Completed media, covers, and subtitles are published under `Downloads/MBNDL`.

MBNDL uses Android’s secure MediaStore API on Android 10 and newer. It does **not** request broad “all files” access. The first-run gate performs a real write/delete probe in `Downloads/MBNDL`, so a false permission state cannot hide an unusable folder. Android 9 and older request only the legacy storage permission required by those systems.

### 🎵 Supported sources

- **Direct through yt-dlp:** YouTube, YouTube Music, SoundCloud, Bandcamp, Audiomack, Audius, Mixcloud, Apple Podcasts, Internet Archive, and the other sites covered by yt-dlp’s extractors. Because websites change, the definitive compatibility check is MBNDL’s **Inspect formats** action. See the [official yt-dlp supported-sites list](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md).
- **Spotify smart match:** tracks, albums, playlists, artists (Top tracks), episodes, and shows are read from public Spotify metadata, then matched against YouTube/YouTube Music. Collections become individual queue entries and one visible notice explains the source before download. This follows the transparent metadata-to-YouTube model used by the open-source [spotDL project](https://github.com/spotDL/spotify-downloader); MBNDL does not decrypt or copy Spotify streams.

Always verify the matched title/artist before downloading and respect copyright, service terms, and local law.

### 🎛️ Choosing formats

Choose a connection preset directly on Home before inspecting the link. Detailed retry, network, captions, live-stream, and extractor controls remain one tap away in the yt-dlp Settings page.

- **Ready to play** — formats that already contain video and audio.
- **Video** — select one or several video-only streams.
- **Audio** — select one or several audio-only streams.
- **Smart merge** — select exactly one video and one audio stream, then enable this option to create one playable file with FFmpeg.
- **Save cover / Save subtitles** — keep these artifacts with the download and expose them in History.

Formats already found in the managed download folders are highlighted in green. You can still select one, but MBNDL warns first and creates a clearly named `(copy N)` file instead of overwriting the existing download. Playlist URLs are recognized automatically; playlist switches are not exposed as manual settings.

### 🔐 YouTube accounts

When YouTube returns a **Sign in to confirm you’re not a bot** error, MBNDL opens a focused recovery prompt. Go to **Settings → YouTube Accounts** to save, switch, refresh, disable, or sign out up to three accounts. The selected account is used only for YouTube and YouTube Music links; anonymous access remains the default.

yt-dlp no longer supports YouTube OAuth. Android and Windows also prevent one app from silently reading another app’s browser session, so MBNDL never asks for a Google email/password and does not pretend that a browser login can be captured automatically. Instead it opens the official sign-in page in the external browser and accepts a YouTube-only Netscape `cookies.txt` export. Cookie contents are encrypted at rest and materialized only while yt-dlp is running. Delete the unencrypted export after importing it. See the [official yt-dlp YouTube cookie guide](https://github.com/yt-dlp/yt-dlp/wiki/Extractors#exporting-youtube-cookies).

> ⚠️ yt-dlp warns that using an account can lead to temporary or permanent YouTube restrictions. Use account cookies only when content requires them, keep request rates low, and consider a separate account. The **Gentle YouTube** preset adds the recommended 5–10 second delay but cannot remove this risk.

### 🔄 Application updates

On Android and Windows, MBNDL checks GitHub Releases after startup and can download the correct package without blocking normal use. When it is ready, MBNDL asks before installation. Both automatic checks and background downloads can be changed under **Settings → App Updates**.

- Android automatically chooses ARM32 or ARM64, then opens Android’s standard package installer.
- Windows uses the bundled `updater.exe` beside `MBNDL.exe`, safely waits for MBNDL to close, replaces the extracted bundle, and reopens the app.
- Downloaded release assets are checked against GitHub’s SHA-256 digest when available.

> Android users upgrading from `1.0.0` must uninstall that version and install `1.0.1` once because `1.0.0` was produced with an ephemeral development certificate. Releases from `1.0.1` onward use a persistent signing identity and support normal in-place updates.

### ✨ Appearance, backups, and diagnostics

**Settings → Appearance** offers the aqua Material 3 Expressive design, Material You dynamic colors, light/dark/AMOLED modes, floating navigation, and reduced-motion support. The optional **Liquid Glass (Beta)** renderer, inspired by [Apple’s Liquid Glass design language](https://developer.apple.com/documentation/technologyoverviews/liquid-glass), adds live blur, adaptive quality, theme-derived surface tint, opacity, vibrancy, lens-edge refraction, chromatic edging, and depth. It is a portable Flutter interpretation rather than Apple’s platform renderer. Efficient or Adaptive quality is recommended on older phones because live blur uses extra GPU and battery.

Settings backups now use a versioned schema and include yt-dlp settings, Quick Presets/custom presets, appearance, close behavior, log detail, and app-update preferences. YouTube cookies, proxy credentials, history, permissions, device paths, and free-form command arguments remain local for safety. Imports are validated before any value is written and take effect immediately.

Application logs are stored as one structured event per line. The selected **Log detail** is a recording threshold (for example, Warning stores Warning, Error, and Fatal), while the Logs page filters the recorded events by their exact level. yt-dlp/FFmpeg prefixes determine the displayed severity, multiline errors remain one event, and common secrets are redacted before writing.

### 🗂️ Downloads library and troubleshooting

The Downloads library uses a mobile-first grouped list with clear **All**, **Active**, **Ready**, and **Attention** views. Search, date/media/artifact filters, sorting, retry, cancel, open, share, missing-file detection, and coordinated deletion are available without crowding every card. Select one or several entries to retry, cancel, or remove them together. Tap an item for its source, codecs, cover, subtitles, related files, and full error details.

If a download fails, MBNDL translates common yt-dlp/FFmpeg output into an actionable message—for example: authentication required, rate limited, unsupported URL, missing format, storage full, network failure, or FFmpeg merge failure.

---

<div dir="rtl">

## 🇮🇷 راهنمای فارسی کاربران

MBNDL یک دانلود منیجر ساده و مدرن بر پایهٔ yt-dlp است. قبل از دانلود، لینک بررسی می‌شود و شما می‌توانید چند کیفیت کامل، چند ویدئو یا صدای جداگانه، و یا ترکیب هوشمند یک ویدئو با یک صدا را انتخاب کنید.

### 🪟 استفاده در ویندوز

1. فایل `MBNDL-Windows-x64.zip` را از آخرین Release دانلود کنید.
2. تمام ZIP را Extract کنید و سپس `MBNDL.exe` را اجرا کنید.
3. لینک را در صفحهٔ اصلی قرار دهید و دکمهٔ **Inspect formats** را بزنید.
4. کیفیت‌های موردنظر را انتخاب و با **Add to downloads** به صف دانلود اضافه کنید.
5. خروجی‌ها در پوشهٔ `Downloads/MBNDL` و صفحهٔ History در دسترس‌اند.

فایل‌های `yt-dlp`، `ffmpeg` و `ffprobe` از قبل داخل نسخهٔ ویندوز قرار دارند؛ بنابراین در اجرای اول صفحهٔ دانلود ابزار نمایش داده نمی‌شود. با این حال آپدیت داخلی هر دو ابزار از Settings همچنان فعال است.

قبل از هر بررسی لینک و هر دانلود، برنامه تنظیم فعلی **System Proxy / WinINet** ویندوز را دوباره می‌خواند. پروکسی HTTP/HTTPS/SOCKS، لیست‌های جداگانه و Bypass ویندوز پشتیبانی می‌شوند. اگر پروکسی سیستم خاموش یا خالی باشد اتصال مستقیم است و پروکسی دستی تنظیمات yt-dlp اولویت بالاتری دارد.

هنگام بستن برنامه می‌توانید یکی از گزینه‌های **Minimize to tray**، **Exit** یا **Cancel** را انتخاب کنید. با فعال‌کردن **Remember this selection** همان رفتار برای دفعات بعد ذخیره می‌شود و از بخش **Settings → Appearance & behavior** قابل تغییر است. کلیک چپ روی آیکون Tray پنجره را به جلو می‌آورد و کلیک راست گزینه‌های Open و Close را نشان می‌دهد.

### 📱 استفاده در اندروید

1. برای گوشی‌های قدیمی ۳۲ بیتی فایل `arm32` و برای گوشی‌های جدید ۶۴ بیتی فایل `arm64` را نصب کنید.
2. در اجرای اول، صفحهٔ دسترسی‌های لازم را کامل کنید.
3. فایل‌های نهایی، کاورها و زیرنویس‌ها در `Downloads/MBNDL` منتشر می‌شوند.

در اندروید ۱۰ به بالا برنامه طبق [راهنمای رسمی MediaStore اندروید](https://developer.android.com/training/data-storage/shared/media) از MediaStore استفاده می‌کند و به مجوز خطرناک دسترسی به تمام فایل‌ها نیازی ندارد. صفحهٔ راه‌اندازی با ساخت و حذف یک فایل آزمایشی، قابل‌نوشتن‌بودن واقعی `Downloads/MBNDL` را بررسی می‌کند؛ بنابراین دیگر صرفاً براساس وضعیت ظاهری Permission عبور نمی‌کند. فقط در اندروید ۹ و قدیمی‌تر مجوز قدیمی Storage درخواست می‌شود.

### 🎵 منابع قابل دانلود

- لینک‌های YouTube، YouTube Music، SoundCloud، Bandcamp، Audiomack، Audius، Mixcloud، Apple Podcasts، Internet Archive و سایت‌های پشتیبانی‌شدهٔ دیگر مستقیماً با yt-dlp پردازش می‌شوند. فهرست مرجع در [Supported sites رسمی yt-dlp](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md) قرار دارد، اما چون سایت‌ها دائماً تغییر می‌کنند دکمهٔ **Inspect formats** تست نهایی سازگاری است.
- برای Spotify، اطلاعات عمومی آهنگ/آلبوم/Playlist/Artist (آهنگ‌های برتر)/Episode/Show خوانده می‌شود و سپس مشابه پروژهٔ متن‌باز [spotDL](https://github.com/spotDL/spotify-downloader)، نسخهٔ متناظر در YouTube/YouTube Music جست‌وجو می‌شود. هر آیتم مجموعه جداگانه وارد صف می‌شود و قبل از دانلود منبع واقعی به کاربر گفته می‌شود؛ برنامه استریم رمزنگاری‌شدهٔ Spotify را استخراج نمی‌کند.

قبل از دانلود، نام خواننده و عنوان نتیجهٔ Match‌شده را بررسی کنید و قوانین کپی‌رایت و سرویس را رعایت کنید.

### 🔄 آپدیت خودکار برنامه

در ویندوز و اندروید، MBNDL بعد از اجرا Release جدید را بدون متوقف‌کردن کار شما بررسی و فایل مناسب دستگاه را در پس‌زمینه آماده می‌کند. پس از کامل‌شدن دانلود، نصب فقط با تأیید شما شروع می‌شود. این رفتار از مسیر **Settings → App Updates** قابل تغییر است.

- در اندروید نسخهٔ ARM32 یا ARM64 به‌طور خودکار انتخاب و نصب‌کنندهٔ رسمی Android باز می‌شود.
- در ویندوز فایل `updater.exe` کنار برنامه قرار دارد؛ منتظر بسته‌شدن MBNDL می‌ماند، فایل‌ها را جایگزین می‌کند و برنامه را دوباره باز می‌کند.
- در صورت وجود Digest رسمی GitHub، صحت SHA-256 فایل دانلودشده بررسی می‌شود.

> برای عبور از نسخهٔ `1.0.0` در اندروید، فقط همین یک بار باید نسخهٔ قبلی را حذف و `1.0.1` را نصب کنید؛ نسخهٔ قبلی با گواهی توسعهٔ موقت ساخته شده بود. از `1.0.1` به بعد امضای ثابت است و آپدیت مستقیم روی نسخهٔ نصب‌شده انجام می‌شود.

### 🎚️ انتخاب کیفیت و تاریخچه

- در تب **Ready to play** خروجی‌های آمادهٔ پخش را انتخاب کنید.
- در تب‌های **Video** و **Audio** می‌توانید چند گزینه را هم‌زمان انتخاب کنید.
- برای ساخت یک فایل نهایی از یک ویدئو و یک صدا، گزینهٔ **Smart merge** را فعال کنید.
- صفحهٔ Downloads دارای نمای ساده و گروه‌بندی‌شده، جست‌وجو، فیلتر تاریخ/وضعیت/نوع فایل، مرتب‌سازی، Retry، Cancel، Share، تشخیص فایل حذف‌شده و نمایش کاور و زیرنویس است.
- با حالت انتخاب چندتایی می‌توانید چند دانلود را با هم Retry، Cancel یا همراه فایل‌های وابسته حذف کنید.
- Quick Presets پیش از دانلود مستقیماً در Home در دسترس است و دکمهٔ تنظیمات ریز yt-dlp نیز کنار آن قرار دارد.
- خطاهای رایج yt-dlp و FFmpeg با متن قابل‌فهم و راه‌حل پیشنهادی نمایش داده می‌شوند.

کیفیت‌هایی که فایلشان از قبل در پوشه‌های مدیریت‌شده وجود دارد با رنگ سبز مشخص می‌شوند. انتخاب دوبارهٔ آن‌ها پس از هشدار مجاز است و برنامه به‌جای overwrite، فایل جدید را با نام `(copy N)` ذخیره می‌کند. لینک Playlist نیز به‌صورت خودکار تشخیص داده می‌شود و تنظیم دستی جداگانه‌ای ندارد.

### ✨ ظاهر، بکاپ و لاگ

در مسیر **Settings → Appearance** طراحی آبی‌آکوا Material 3 Expressive، رنگ پویا Material You، حالت روشن/تیره/AMOLED، نوار شناور و Reduced Motion در دسترس است. گزینهٔ آزمایشی **Liquid Glass** با الهام از [زبان طراحی Liquid Glass اپل](https://developer.apple.com/documentation/technologyoverviews/liquid-glass)، افکت Blur زنده، کیفیت Adaptive، Tint هماهنگ با رنگ تم، Opacity، Vibrancy، شکست لبهٔ لنزی، Chromatic edge و Depth را اضافه می‌کند. این یک پیاده‌سازی قابل‌حمل Flutter است و موتور اختصاصی اپل نیست. برای گوشی‌های قدیمی حالت Adaptive یا Efficient پیشنهاد می‌شود.

Export نسخه‌بندی‌شدهٔ تنظیمات حالا تنظیمات yt-dlp، پریست‌ها، ظاهر، رفتار بستن ویندوز، سطح لاگ و آپدیتر را همگام نگه می‌دارد. کوکی‌های YouTube، رمز پروکسی، History، Permission، مسیرهای مخصوص دستگاه و آرگومان‌های آزاد عمداً منتقل نمی‌شوند. Import پیش از نوشتن کامل بررسی می‌شود و تغییرات بلافاصله اعمال می‌شوند.

هر رخداد لاگ به‌صورت ساختاریافته و یکپارچه ذخیره می‌شود؛ Errorهای چندخطی دیگر به چند ردیف اشتباه تقسیم نمی‌شوند. گزینهٔ **Log detail** حداقل سطح ضبط را تعیین می‌کند و صفحهٔ Logs رخدادهای ضبط‌شده را براساس سطح واقعی yt-dlp/FFmpeg فیلتر می‌کند. اطلاعات حساس رایج نیز پیش از ذخیره ماسک می‌شوند.

### 🔐 حساب‌های یوتیوب

اگر یوتیوب خطای **Sign in to confirm you’re not a bot** برگرداند، برنامه یک راهنمای اختصاصی نشان می‌دهد. در مسیر **Settings → YouTube Accounts** می‌توانید تا سه حساب را ذخیره، فعال، تعویض، غیرفعال، Refresh یا Sign out کنید. حساب فعال فقط برای لینک‌های YouTube و YouTube Music استفاده می‌شود و حالت ناشناس همچنان پیش‌فرض است.

OAuth یوتیوب دیگر توسط yt-dlp پشتیبانی نمی‌شود و Android/Windows اجازه نمی‌دهند برنامه کوکی مرورگر دیگری را مخفیانه بخواند. به همین دلیل MBNDL هیچ‌وقت ایمیل یا رمز Google را درخواست نمی‌کند. صفحهٔ رسمی ورود در مرورگر خارجی باز می‌شود و سپس فقط فایل `cookies.txt` با فرمت Netscape و دامنهٔ YouTube/Google وارد می‌شود. محتوای کوکی در حالت ذخیره رمزنگاری شده و فقط هنگام اجرای yt-dlp موقتاً روی دیسک قرار می‌گیرد. فایل خروجی رمزنگاری‌نشده را پس از Import حذف کنید. جزئیات در [راهنمای رسمی کوکی یوتیوب yt-dlp](https://github.com/yt-dlp/yt-dlp/wiki/Extractors#exporting-youtube-cookies) آمده است.

> ⚠️ طبق هشدار رسمی yt-dlp، استفادهٔ خودکار از حساب ممکن است باعث محدودیت یا بن موقت/دائمی شود. فقط در صورت نیاز از حساب استفاده کنید و نرخ درخواست را پایین نگه دارید. پریست **Gentle YouTube** بین دانلودها ۵ تا ۱۰ ثانیه مکث ایجاد می‌کند، اما خطر را صفر نمی‌کند.

</div>

---

## 🧩 Developer guide

### Stack

| Area | Implementation |
|---|---|
| UI | Flutter Material 3 Expressive / Material You / native BackdropFilter Liquid Glass renderer |
| State | Riverpod |
| Navigation | GoRouter |
| Downloads library | SQLite (`sqflite` / `sqflite_common_ffi`) |
| YouTube accounts | Encrypted secure storage + temporary YouTube-only Netscape cookie materialization |
| App updates | GitHub Releases API, SHA-256 verification, Android installer, Windows sidecar |
| Source resolution | Direct yt-dlp extractors + transparent Spotify metadata-to-YouTube smart matching |
| Windows downloads | Official standalone yt-dlp + minimal FFmpeg/FFprobe bootstrap + live WinINet proxy discovery |
| Android downloads | `youtubedl-android`, foreground service, and MediaStore publication |
| Application ID | `com.mbn.dl` |

The glass renderer uses clipped Flutter [`BackdropFilter`](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html) surfaces and adaptive blur limits. Flutter documents backdrop blur as relatively expensive, which is why MBNDL exposes performance presets and keeps Material Expressive as the default.

### How a download works

1. The app classifies the URL; direct sources go to yt-dlp while Spotify public metadata is resolved into a visible YouTube/YouTube Music smart match.
2. yt-dlp extracts metadata and formats using the current manual or freshly read Windows system proxy and JavaScript-runtime settings; the active encrypted account is materialized only for classified YouTube URLs.
3. The full-screen picker returns one or more independent download jobs.
4. Each job is persisted to SQLite, then consumed by a reliable serial queue. A job always moves from Queued to Preparing or to a stored actionable failure.
5. yt-dlp downloads the selected stream; FFmpeg merges or post-processes only when required.
6. MBNDL discovers the output, cover, and subtitle files and saves those relationships in History.
7. Android copies completed artifacts into `Downloads/MBNDL` through MediaStore and queries that public collection when marking previously downloaded formats.

### Windows offline bootstrap and updates

Windows-only tools are installed by CMake under `data/tools`; they are not added to Flutter’s cross-platform asset bundle and therefore do not inflate Android APKs.

- First launch copies the packaged official `yt-dlp.exe` into the writable application-data folder.
- The packaged FFmpeg archive contains only `ffmpeg.exe`, `ffprobe.exe`, and upstream notices.
- The FFmpeg updater reads the remote ZIP directory and uses HTTP Range requests to fetch only those two executables instead of downloading the complete distribution.
- yt-dlp updates support stable, nightly, and master channels and verify the upstream digest when one is supplied.
- Windows account secrets use the upstream Dart FFI/DPAPI implementation. MBNDL keeps a Dart-only copy under `third_party/` so the obsolete ATL migration plugin is not compiled and CI does not require Visual Studio's optional ATL workload.

### Application updater and signing

`lib/services/updater/` selects assets from the latest GitHub Release and verifies their published digest. Android exposes install permission and a content URI through a dedicated platform channel and `FileProvider`. Windows builds `windows/updater/main.cpp` as `updater.exe` and installs it beside the main executable.

Android CI releases must provide `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` repository secrets. The workflow converts them into the `MBNDL_*` environment expected by Gradle; signing material is never committed.

Refresh the Windows bootstrap assets from the project root:

```powershell
dart run tool/refresh_windows_bootstrap.dart
```

### Local development

Requirements: Flutter `3.44.6`, Dart `3.12.2`, JDK 17, Visual Studio 2022 with Desktop C++, and the Android SDK for Android builds.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --release
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
```

### 📁 Important locations

```text
lib/features/home/                 Home and full-screen format selection
lib/features/history/              Searchable download library and artifact UI
lib/services/downloader/           yt-dlp, FFmpeg, native Android bridge
lib/services/network/              Per-download Windows WinINet proxy discovery
lib/services/logger/               Structured level-aware logging and redaction
lib/services/updater/              GitHub release check, download, verification, install
lib/services/permissions/          First-run permission contract
android/app/src/main/kotlin/       Foreground download and MediaStore publication
windows/updater/                   Native Windows sidecar updater
tool/refresh_windows_bootstrap.dart Minimal FFmpeg bootstrap refresher
.github/workflows/release.yml       Tagged Windows/Android release pipeline
```

### ♻️ CI cache policy

Every push to `main` builds Windows x64 and Android ARM32/ARM64 and refreshes
shared Flutter SDK and pub caches in the default-branch scope. Version tags can
restore those caches; caches created only by one tag cannot be reused by a
different tag because GitHub isolates tag cache scopes.

The workflow validates the restored Flutter version, Dart executable, target
engine artifacts, and `flutter doctor` state before compiling. If setup or the
health check fails, only the matching Flutter and pub cache keys are deleted,
the SDK is installed again, and the repaired cache is saved at job completion.
The workflow can also be run manually with `repair_cache` enabled to force a
clean cache generation.

### 🤝 Contributing

Keep platform-specific binaries out of Flutter’s shared asset list, preserve SQLite migrations, add actionable error messages for new engine failures, and run analysis plus tests before submitting changes.

MBNDL downloads only content the user asks it to access. Users are responsible for respecting copyright, website terms, and local law. yt-dlp and FFmpeg are independent upstream projects distributed under their own licenses.
