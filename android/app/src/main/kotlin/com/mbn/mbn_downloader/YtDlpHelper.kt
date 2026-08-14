package com.mbn.dl

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.aria2c.Aria2c
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.File

object YtDlpHelper {
    private val TAG = "YtDlpHelper"
    private val downloadJobs = mutableMapOf<String, Job>()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    @Volatile
    private var initialized = false

    val progressStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
            Log.d(TAG, "Progress stream listener attached")
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
            Log.d(TAG, "Progress stream listener cancelled")
        }
    }

    @Synchronized
    fun ensureInitialized(context: android.content.Context) {
        if (!initialized) {
            try {
                val appContext = context.applicationContext
                YoutubeDL.getInstance().init(appContext)
                com.yausername.ffmpeg.FFmpeg.getInstance().init(appContext)
                Aria2c.getInstance().init(appContext)
                initialized = true
                Log.i(TAG, "YoutubeDL, FFmpeg, Aria2c and QuickJS initialized")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize YoutubeDL", e)
                throw e
            }
        }
    }

    fun isReady(): Boolean = initialized

    fun getVersion(context: android.content.Context): String? =
        YoutubeDL.getInstance().versionName(context.applicationContext)
            ?: YoutubeDL.getInstance().version(context.applicationContext)

    fun updateYtDlp(
        channelName: String,
        context: android.content.Context,
        result: MethodChannel.Result
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                ensureInitialized(context)
                val channel = when (channelName.lowercase()) {
                    "stable" -> YoutubeDL.UpdateChannel.STABLE
                    "master" -> YoutubeDL.UpdateChannel.MASTER
                    else -> YoutubeDL.UpdateChannel.NIGHTLY
                }
                val status = YoutubeDL.getInstance().updateYoutubeDL(
                    context.applicationContext,
                    channel
                )
                Log.i(TAG, "yt-dlp update result: $status ($channelName)")
                mainHandler.post { result.success(true) }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update yt-dlp", e)
                mainHandler.post { result.error("UPDATE_ERROR", e.message, null) }
            }
        }
    }

    fun getVideoInfo(
        url: String,
        options: List<String>,
        context: android.content.Context,
        result: MethodChannel.Result
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                ensureInitialized(context)

                val request = YoutubeDLRequest(url)
                request.addCommands(options)
                request.addOption("--dump-single-json")
                addInspectionScope(request, url)

                val response = YoutubeDL.getInstance().execute(request)
                val output = response.out

                val jsonObject = JSONObject(output)
                val representative = representativeEntry(jsonObject)
                val isPlaylist = jsonObject.optString("_type") == "playlist"
                val info = mapOf(
                    "title" to jsonObject.optString(
                        "title",
                        representative.optString("title", "Unknown")
                    ),
                    "id" to representative.optString("id"),
                    "thumbnail" to representative.optString("thumbnail"),
                    "duration" to representative.optInt("duration", 0),
                    "uploader" to representative.optString("uploader"),
                    "filesize" to representative.optLong("filesize", 0),
                    "isPlaylist" to isPlaylist,
                    "playlistCount" to jsonObject.optInt("playlist_count", 0),
                    "formats" to parseFormats(representative)
                )

                mainHandler.post {
                    result.success(info)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error getting video info", e)
                mainHandler.post {
                    result.error("INFO_ERROR", e.message, null)
                }
            }
        }
    }

    fun getFormats(
        url: String,
        options: List<String>,
        context: android.content.Context,
        result: MethodChannel.Result
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                ensureInitialized(context)

                val request = YoutubeDLRequest(url)
                request.addCommands(options)
                request.addOption("--dump-single-json")
                addInspectionScope(request, url)

                val response = YoutubeDL.getInstance().execute(request)
                val output = response.out

                // Parse JSON response
                val jsonObject = JSONObject(output)
                val formats = parseFormats(representativeEntry(jsonObject))

                mainHandler.post {
                    result.success(formats)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error getting formats", e)
                mainHandler.post {
                    result.error("FORMATS_ERROR", e.message, null)
                }
            }
        }
    }

    private fun addInspectionScope(request: YoutubeDLRequest, url: String) {
        val uri = try { Uri.parse(url) } catch (_: Exception) { null }
        val hasPlaylistPath = uri?.pathSegments?.any { it == "playlist" } == true
        val hasPlaylistQuery = !uri?.getQueryParameter("list").isNullOrBlank()
        if (hasPlaylistPath || hasPlaylistQuery) {
            request.addOption("--playlist-end", "1")
        } else {
            request.addOption("--no-playlist")
        }
    }

    private fun representativeEntry(root: JSONObject): JSONObject {
        val entries = root.optJSONArray("entries") ?: return root
        for (index in 0 until entries.length()) {
            entries.optJSONObject(index)?.let { return it }
        }
        return root
    }

    private fun parseFormats(jsonObject: JSONObject): List<Map<String, Any?>> {
        val formatsArray = jsonObject.optJSONArray("formats")
            ?: return emptyList()
        val formats = mutableListOf<Map<String, Any?>>()
        for (i in 0 until formatsArray.length()) {
            val format = formatsArray.getJSONObject(i)
            fun text(name: String): String? = format.optString(name)
                .trim()
                .takeIf { it.isNotEmpty() && !it.equals("null", ignoreCase = true) }
            fun positiveLong(name: String): Long? = format.optLong(name, 0)
                .takeIf { it > 0 }
            fun positiveInt(name: String): Int? = format.optInt(name, 0)
                .takeIf { it > 0 }
            fun positiveDouble(name: String): Double? = format.optDouble(name, 0.0)
                .takeIf { it > 0.0 }
            formats.add(mapOf(
                "format_id" to text("format_id"),
                "resolution" to text("resolution"),
                "ext" to text("ext"),
                "quality" to text("quality"),
                "filesize" to positiveLong("filesize"),
                "filesize_approx" to positiveLong("filesize_approx"),
                "height" to positiveInt("height"),
                "width" to positiveInt("width"),
                "fps" to positiveDouble("fps"),
                "vcodec" to text("vcodec"),
                "acodec" to text("acodec"),
                "video_ext" to text("video_ext"),
                "audio_ext" to text("audio_ext"),
                "protocol" to text("protocol"),
                "abr" to positiveDouble("abr"),
                "vbr" to positiveDouble("vbr"),
                "tbr" to positiveDouble("tbr"),
                "format_note" to text("format_note")
            ))
        }
        return formats
    }

    fun startDownload(
        url: String,
        outputPath: String,
        options: List<String>,
        downloadId: String,
        title: String,
        thumbnailUrl: String?,
        context: android.content.Context,
        result: MethodChannel.Result
    ) {
        // Cancel existing download with same ID
        downloadJobs[downloadId]?.cancel()

        // Start foreground service
        DownloadForegroundService.startService(context, downloadId, title, thumbnailUrl)

        val job = CoroutineScope(Dispatchers.IO).launch {
            try {
                ensureInitialized(context)

                val request = YoutubeDLRequest(url)

                // Add output path
                request.addOption("-P", outputPath)

                // Keep ordering and repeated options intact. The Android aria2c
                // binary is exposed to yt-dlp as a shared library.
                val nativeOptions = options.map {
                    if (it == "aria2c") "libaria2c.so" else it
                }
                request.addCommands(nativeOptions)
                request.addOption("--print", "after_move:MBN_FILE:%(filepath)j")

                // Add progress options
                request.addOption("--newline")
                request.addOption("--progress")

                Log.i(TAG, "Starting download: $url")
                Log.i(TAG, "Output path: $outputPath")
                Log.i(TAG, "Options: $options")

                val response = YoutubeDL.getInstance().execute(request, downloadId) { progress, _, line ->
                    Log.d(TAG, "Download progress: $progress% - $line")

                    // Update foreground service notification
                    DownloadForegroundService.updateProgress(context, downloadId, progress.toDouble())

                    // Send progress to Flutter
                    mainHandler.post {
                        eventSink?.success(mapOf(
                            "downloadId" to downloadId,
                            "progress" to progress.toDouble(),
                            "line" to line
                        ))
                    }
                }

                // Extract file path from output
                val outputLines = response.out.split("\n")
                var filePath: String? = null

                // Prefer a machine-readable path emitted after post-processing.
                for (line in outputLines.reversed()) {
                    if (line.startsWith("MBN_FILE:")) {
                        val rawPath = line.removePrefix("MBN_FILE:").trim()
                        filePath = try {
                            JSONObject("{\"path\":$rawPath}").getString("path")
                        } catch (_: Exception) {
                            rawPath.trim('"')
                        }
                        break
                    }
                    // Look for lines like: [download] Destination: /path/to/file.ext
                    else if (line.contains("Destination:")) {
                        val destIndex = line.indexOf("Destination:") + 12
                        filePath = line.substring(destIndex).trim()
                        break
                    }
                    // or: [Metadata] Adding metadata to "/path/to/file.ext"
                    else if (line.contains("Adding metadata to")) {
                        val startQuote = line.indexOf("\"")
                        val endQuote = line.indexOf("\"", startQuote + 1)
                        if (startQuote != -1 && endQuote != -1) {
                            filePath = line.substring(startQuote + 1, endQuote)
                            break
                        }
                    }
                }

                // If not found in logs, try to find the file in output directory
                if (filePath == null || !File(filePath).exists()) {
                    try {
                        val outputDir = File(outputPath)
                        val files = outputDir.walkTopDown().filter { file ->
                            file.isFile && !file.name.endsWith(".part") &&
                                file.extension.lowercase() in setOf(
                                    "mp4", "webm", "mkv", "m4a", "mp3", "opus"
                                )
                        }
                        filePath = files.maxByOrNull { it.lastModified() }?.absolutePath
                    } catch (e: Exception) {
                        Log.w(TAG, "Could not search output directory", e)
                    }
                }

                val downloadedFile = filePath?.let(::File)
                    ?.takeIf { it.exists() }
                val relatedFiles = if (downloadedFile != null) {
                    downloadedFile.parentFile
                        ?.listFiles()
                        ?.filter {
                            it.isFile &&
                                !it.name.endsWith(".part") &&
                                (
                                    it.nameWithoutExtension == downloadedFile.nameWithoutExtension ||
                                        it.nameWithoutExtension.startsWith(
                                            "${downloadedFile.nameWithoutExtension}."
                                        )
                                    )
                        }
                        ?: listOf(downloadedFile)
                } else {
                    emptyList()
                }
                val publicUris = relatedFiles.mapNotNull {
                    publishToDownloads(context, it)
                }

                // Notify service of completion
                DownloadForegroundService.completeDownload(context, downloadId, true)

                mainHandler.post {
                    result.success(mapOf(
                        "success" to true,
                        "filePath" to filePath,
                        "relatedFilePaths" to relatedFiles.map { it.absolutePath },
                        "publicUris" to publicUris
                    ))
                }

                Log.i(TAG, "Download completed: $url")
                Log.i(TAG, "File saved to: $filePath")
            } catch (e: CancellationException) {
                Log.i(TAG, "Download cancelled: $downloadId")
                DownloadForegroundService.completeDownload(context, downloadId, false)
                mainHandler.post {
                    result.error("DOWNLOAD_CANCELLED", "Download was cancelled", null)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Download error", e)

                // Notify service of failure
                DownloadForegroundService.completeDownload(context, downloadId, false)

                mainHandler.post {
                    result.error("DOWNLOAD_ERROR", e.message, null)
                }
            } finally {
                downloadJobs.remove(downloadId)
            }
        }

        downloadJobs[downloadId] = job
    }

    private fun publishToDownloads(
        context: android.content.Context,
        source: File
    ): String? {
        return try {
            val extension = source.extension.lowercase()
            val category = when {
                extension in setOf("jpg", "jpeg", "png", "webp", "avif") -> "Cover"
                extension in setOf("srt", "vtt", "ass", "ssa", "lrc", "ttml") -> "Subtitle"
                source.parentFile?.name?.lowercase() == "audio" -> "Audio"
                else -> "Video"
            }
            val mimeType = MimeTypeMap.getSingleton()
                .getMimeTypeFromExtension(extension)
                ?: "application/octet-stream"

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = context.contentResolver
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, source.name)
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                    put(
                        MediaStore.MediaColumns.RELATIVE_PATH,
                        "${Environment.DIRECTORY_DOWNLOADS}/MBNDL/$category"
                    )
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val uri = resolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    values
                ) ?: return null

                try {
                    resolver.openOutputStream(uri, "w")?.use { output ->
                        source.inputStream().use { input -> input.copyTo(output) }
                    } ?: throw IllegalStateException("Could not open MediaStore output")

                    values.clear()
                    values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    resolver.update(uri, values, null, null)
                    uri.toString()
                } catch (e: Exception) {
                    resolver.delete(uri, null, null)
                    throw e
                }
            } else {
                @Suppress("DEPRECATION")
                val publicRoot = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS
                )
                val destinationDir = File(publicRoot, "MBNDL/$category")
                destinationDir.mkdirs()
                val destination = uniqueDestination(destinationDir, source.name)
                source.copyTo(destination, overwrite = false)
                Uri.fromFile(destination).toString()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not publish ${source.name} to Downloads", e)
            null
        }
    }

    private fun uniqueDestination(directory: File, originalName: String): File {
        val direct = File(directory, originalName)
        if (!direct.exists()) return direct
        val extension = originalName.substringAfterLast('.', "")
        val stem = if (extension.isEmpty()) {
            originalName
        } else {
            originalName.removeSuffix(".$extension")
        }
        var copy = 2
        while (true) {
            val candidateName = if (extension.isEmpty()) {
                "$stem (copy $copy)"
            } else {
                "$stem (copy $copy).$extension"
            }
            val candidate = File(directory, candidateName)
            if (!candidate.exists()) return candidate
            copy++
        }
    }

    fun cancelDownload(downloadId: String, result: MethodChannel.Result) {
        try {
            val job = downloadJobs[downloadId]
            if (job != null) {
                job.cancel()
                downloadJobs.remove(downloadId)
                YoutubeDL.getInstance().destroyProcessById(downloadId)
                result.success(true)
                Log.i(TAG, "Download cancelled: $downloadId")
            } else {
                result.error("NOT_FOUND", "Download not found", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error cancelling download", e)
            result.error("CANCEL_ERROR", e.message, null)
        }
    }
}
