@echo off
setlocal

echo ========================================
echo MBNDL 1.0.0 release build
echo ========================================
echo Android: ARM32 + ARM64
echo Windows: x64
echo.

if not exist "releases" mkdir "releases"
if not exist "releases\android" mkdir "releases\android"
if not exist "releases\windows" mkdir "releases\windows"

echo [1/3] Compiling Android ARM APKs...
call flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
if errorlevel 1 exit /b 1

copy /Y "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "releases\android\MBNDL-Android-arm32.apk" >nul
copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "releases\android\MBNDL-Android-arm64.apk" >nul

echo [2/3] Compiling Windows x64...
call flutter build windows --release
if errorlevel 1 exit /b 1

echo [3/3] Packaging Windows bundle...
powershell -NoProfile -Command "Compress-Archive -Path 'build\windows\x64\runner\Release\*' -DestinationPath 'releases\windows\MBNDL-Windows-x64.zip' -CompressionLevel Optimal -Force"
if errorlevel 1 exit /b 1

echo.
echo Release files are ready in:
echo   releases\android\MBNDL-Android-arm32.apk
echo   releases\android\MBNDL-Android-arm64.apk
echo   releases\windows\MBNDL-Windows-x64.zip
echo.
exit /b 0
