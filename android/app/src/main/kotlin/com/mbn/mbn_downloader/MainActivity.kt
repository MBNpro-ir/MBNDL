package com.mbn.dl

import android.Manifest
import android.app.DownloadManager
import android.content.ContentValues
import android.content.Intent
import android.content.ClipData
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mbn.dl/ytdlp"
    private val EVENT_CHANNEL = "com.mbn.dl/ytdlp_events"
    private val UPDATE_CHANNEL = "com.mbn.dl/app_updates"
    private val TAG = "MainActivity"
    private val nativeScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val pendingPermissionResults = mutableMapOf<Int, MethodChannel.Result>()
    private var nextPermissionRequestCode = 1200
    private var pendingApkPath: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Warm up the native toolchain without blocking Flutter startup.
        nativeScope.launch {
            try {
                YtDlpHelper.ensureInitialized(applicationContext)
                Log.i(TAG, "yt-dlp toolchain initialized successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize yt-dlp", e)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup EventChannel for progress updates
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            YtDlpHelper.progressStreamHandler
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "is64BitDevice" -> {
                        result.success(Build.SUPPORTED_64_BIT_ABIS.isNotEmpty())
                    }
                    "openInstallPermission" -> {
                        try {
                            openInstallPermission()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_PERMISSION_ERROR", e.message, null)
                        }
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank() || !File(path).isFile) {
                            result.error("APK_NOT_FOUND", "The downloaded APK is missing", null)
                        } else if (!canInstallPackages()) {
                            pendingApkPath = path
                            try {
                                openInstallPermission()
                                result.success(false)
                            } catch (e: Exception) {
                                pendingApkPath = null
                                result.error("INSTALL_PERMISSION_ERROR", e.message, null)
                            }
                        } else {
                            try {
                                launchApkInstaller(path)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("APK_INSTALL_ERROR", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    nativeScope.launch {
                        try {
                            YtDlpHelper.ensureInitialized(applicationContext)
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("INIT_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "isInitialized" -> {
                    result.success(YtDlpHelper.isReady())
                }
                "updateYtDlp" -> {
                    val channel = call.argument<String>("channel") ?: "nightly"
                    YtDlpHelper.updateYtDlp(channel, applicationContext, result)
                }
                "getVersion" -> {
                    nativeScope.launch {
                        try {
                            YtDlpHelper.ensureInitialized(applicationContext)
                            val version = YtDlpHelper.getVersion(applicationContext)
                            runOnUiThread { result.success(version) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("VERSION_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "getSdkInt" -> {
                    result.success(android.os.Build.VERSION.SDK_INT)
                }
                "hasPermission" -> {
                    val permission = call.argument<String>("permission") ?: ""
                    result.success(hasNativePermission(permission))
                }
                "requestPermission" -> {
                    val permission = call.argument<String>("permission") ?: ""
                    requestNativePermission(permission, result)
                }
                "openAppSettings" -> {
                    try {
                        startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName")
                            )
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "getDownloadPath" -> {
                    val downloadDir = getWorkingDownloadDirectory()
                    if (!downloadDir.exists() && !downloadDir.mkdirs()) {
                        result.error("STORAGE_ERROR", "Could not create download directory", null)
                    } else {
                        result.success(downloadDir.absolutePath)
                    }
                }
                "verifyDownloadStorage" -> {
                    nativeScope.launch {
                        val status = verifyDownloadStorage()
                        runOnUiThread { result.success(status) }
                    }
                }
                "findExistingFormatSelectors" -> {
                    val mediaId = call.argument<String>("mediaId")?.trim().orEmpty()
                    if (mediaId.isEmpty()) {
                        result.success(emptyMap<String, Int>())
                    } else {
                        nativeScope.launch {
                            val selectors = findExistingFormatSelectors(mediaId)
                            runOnUiThread { result.success(selectors) }
                        }
                    }
                }
                "openDownloads" -> {
                    try {
                        startActivity(Intent(DownloadManager.ACTION_VIEW_DOWNLOADS))
                        result.success(true)
                    } catch (e: Exception) {
                        val fallback = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            type = "*/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        startActivity(fallback)
                        result.success(true)
                    }
                }
                "deletePublishedFiles" -> {
                    val uris = call.argument<List<String>>("uris") ?: emptyList()
                    var deleted = 0
                    uris.forEach { value ->
                        try {
                            deleted += contentResolver.delete(Uri.parse(value), null, null)
                        } catch (e: Exception) {
                            Log.w(TAG, "Could not delete published file: $value", e)
                        }
                    }
                    result.success(deleted)
                }
                "getInfo" -> {
                    val url = call.argument<String>("url")
                    val options = call.argument<List<String>>("options") ?: emptyList()
                    if (url == null) {
                        result.error("INVALID_ARGS", "URL is required", null)
                        return@setMethodCallHandler
                    }

                    // Delegate to helper class
                    YtDlpHelper.getVideoInfo(url, options, this, result)
                }
                "getFormats" -> {
                    val url = call.argument<String>("url")
                    val options = call.argument<List<String>>("options") ?: emptyList()
                    if (url == null) {
                        result.error("INVALID_ARGS", "URL is required", null)
                        return@setMethodCallHandler
                    }

                    // Delegate to helper class
                    YtDlpHelper.getFormats(url, options, this, result)
                }
                "startDownload" -> {
                    val url = call.argument<String>("url") ?: ""
                    val outputPath = call.argument<String>("outputPath") ?: ""
                    val options = call.argument<List<String>>("options") ?: emptyList()
                    val downloadId = call.argument<String>("downloadId") ?: ""
                    val title = call.argument<String>("title") ?: "Downloading..."
                    val thumbnailUrl = call.argument<String>("thumbnailUrl")

                    // Delegate to helper class
                    YtDlpHelper.startDownload(url, outputPath, options, downloadId, title, thumbnailUrl, this, result)
                }
                "cancelDownload" -> {
                    val downloadId = call.argument<String>("downloadId")
                    if (downloadId == null) {
                        result.error("INVALID_ARGS", "downloadId is required", null)
                        return@setMethodCallHandler
                    }

                    // Delegate to helper class
                    YtDlpHelper.cancelDownload(downloadId, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        val path = pendingApkPath
        if (path != null && canInstallPackages()) {
            pendingApkPath = null
            try {
                launchApkInstaller(path)
            } catch (e: Exception) {
                Log.e(TAG, "Could not resume APK installation", e)
            }
        }
    }

    private fun canInstallPackages(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()

    private fun openInstallPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            )
        )
    }

    private fun launchApkInstaller(path: String) {
        val apk = File(path)
        require(apk.isFile) { "The downloaded APK is missing" }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apk
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            clipData = ClipData.newRawUri("MBNDL update", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun permissionNames(permission: String): Array<String> = when (permission) {
        "storage" -> arrayOf(
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        )
        "notification" -> if (android.os.Build.VERSION.SDK_INT >= 33) {
            arrayOf(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            emptyArray()
        }
        else -> emptyArray()
    }

    private fun getWorkingDownloadDirectory(): File {
        val downloadsRoot = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: File(filesDir, "downloads")
        return File(downloadsRoot, "MBNDL")
    }

    private fun verifyDownloadStorage(): Map<String, Any?> {
        val workingDirectory = getWorkingDownloadDirectory()
        val publicPath = "${Environment.DIRECTORY_DOWNLOADS}/MBNDL"
        return try {
            if (!workingDirectory.exists() && !workingDirectory.mkdirs()) {
                throw IllegalStateException("Could not create the private working folder")
            }
            val workingProbe = File(workingDirectory, ".mbndl-write-check")
            workingProbe.writeText("ok")
            if (!workingProbe.delete()) workingProbe.deleteOnExit()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(
                        MediaStore.MediaColumns.DISPLAY_NAME,
                        "MBNDL-storage-check-${System.currentTimeMillis()}.tmp"
                    )
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/octet-stream")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, publicPath)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    values
                ) ?: throw IllegalStateException("Android rejected the Downloads location")
                try {
                    contentResolver.openOutputStream(uri, "w")?.use {
                        it.write(byteArrayOf(0x4d, 0x42, 0x4e, 0x44, 0x4c))
                    } ?: throw IllegalStateException("Could not write to Android Downloads")
                } finally {
                    contentResolver.delete(uri, null, null)
                }
            } else {
                if (!hasNativePermission("storage")) {
                    throw SecurityException("Legacy storage permission has not been granted")
                }
                @Suppress("DEPRECATION")
                val publicDirectory = File(
                    Environment.getExternalStoragePublicDirectory(
                        Environment.DIRECTORY_DOWNLOADS
                    ),
                    "MBNDL"
                )
                if (!publicDirectory.exists() && !publicDirectory.mkdirs()) {
                    throw IllegalStateException("Could not create Downloads/MBNDL")
                }
                val publicProbe = File(publicDirectory, ".mbndl-write-check")
                publicProbe.writeText("ok")
                if (!publicProbe.delete()) publicProbe.deleteOnExit()
            }

            mapOf(
                "ready" to true,
                "workingPath" to workingDirectory.absolutePath,
                "publicPath" to publicPath,
                "message" to "Downloads/MBNDL is writable"
            )
        } catch (e: Exception) {
            Log.w(TAG, "Download storage verification failed", e)
            mapOf(
                "ready" to false,
                "workingPath" to workingDirectory.absolutePath,
                "publicPath" to publicPath,
                "message" to (e.message ?: "Storage verification failed")
            )
        }
    }

    /**
     * Reads the user-visible Downloads/MBNDL collection instead of assuming
     * that the app-private working copy still exists. This also keeps the
     * green "downloaded before" state accurate after the working directory is
     * cleaned. Values are counts per yt-dlp format selector.
     */
    private fun findExistingFormatSelectors(mediaId: String): Map<String, Int> {
        val marker = Regex(
            "\\[${Regex.escape(mediaId)}] \\[([^]]+)]",
            RegexOption.IGNORE_CASE
        )
        val counts = mutableMapOf<String, Int>()

        fun record(name: String) {
            val selector = marker.find(name)?.groupValues?.getOrNull(1)
                ?.takeIf { it.isNotBlank() }
                ?: return
            counts[selector] = (counts[selector] ?: 0) + 1
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
                val projection = arrayOf(MediaStore.MediaColumns.DISPLAY_NAME)
                val videoPath = "${Environment.DIRECTORY_DOWNLOADS}/MBNDL/Video"
                val audioPath = "${Environment.DIRECTORY_DOWNLOADS}/MBNDL/Audio"
                contentResolver.query(
                    collection,
                    projection,
                    "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ? OR " +
                        "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?",
                    arrayOf("$videoPath%", "$audioPath%"),
                    null
                )?.use { cursor ->
                    val nameColumn = cursor.getColumnIndexOrThrow(
                        MediaStore.MediaColumns.DISPLAY_NAME
                    )
                    while (cursor.moveToNext()) record(cursor.getString(nameColumn))
                }
            } else if (hasNativePermission("storage")) {
                @Suppress("DEPRECATION")
                val publicRoot = File(
                    Environment.getExternalStoragePublicDirectory(
                        Environment.DIRECTORY_DOWNLOADS
                    ),
                    "MBNDL"
                )
                listOf("Video", "Audio").forEach { category ->
                    File(publicRoot, category).listFiles()
                        ?.filter { it.isFile && !it.name.endsWith(".part") }
                        ?.forEach { record(it.name) }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not inspect published MBNDL downloads", e)
        }
        return counts
    }

    private fun hasNativePermission(permission: String): Boolean {
        val names = permissionNames(permission)
        return names.isEmpty() || names.all {
            checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestNativePermission(
        permission: String,
        result: MethodChannel.Result
    ) {
        val names = permissionNames(permission)
        if (names.isEmpty() || hasNativePermission(permission)) {
            result.success(true)
            return
        }

        val requestCode = nextPermissionRequestCode++
        pendingPermissionResults[requestCode] = result
        requestPermissions(names, requestCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        pendingPermissionResults.remove(requestCode)?.success(
            grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        )
    }
}
