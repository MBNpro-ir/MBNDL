package com.mbn.dl

import android.Manifest
import android.app.DownloadManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.util.Log
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
    private val TAG = "MainActivity"
    private val nativeScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val pendingPermissionResults = mutableMapOf<Int, MethodChannel.Result>()
    private var nextPermissionRequestCode = 1200

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
                    val downloadsRoot = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                        ?: filesDir
                    val downloadDir = File(downloadsRoot, "MBNDL")
                    if (!downloadDir.exists() && !downloadDir.mkdirs()) {
                        result.error("STORAGE_ERROR", "Could not create download directory", null)
                    } else {
                        result.success(downloadDir.absolutePath)
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
