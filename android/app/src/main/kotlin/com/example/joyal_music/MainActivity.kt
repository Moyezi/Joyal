package com.example.joyal_music

import android.content.ContentValues
import android.app.DownloadManager
import android.content.Context
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val lastDownloadSnapshots = mutableMapOf<Long, String>()
    private var mediaSessionManager: JoyalMediaSessionManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val androidMediaChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "joyal_music/android_media",
        )
        mediaSessionManager = JoyalMediaSessionManager(this, androidMediaChannel)
        androidMediaChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updatePlaybackState" -> try {
                    val args = call.arguments as Map<*, *>
                    mediaSessionManager?.update(PlaybackSnapshot.fromMap(args))
                    result.success(null)
                } catch (error: Exception) {
                    result.error("MEDIA_UPDATE_FAILED", error.message, null)
                }
                "clearPlaybackState" -> try {
                    mediaSessionManager?.clear()
                    result.success(null)
                } catch (error: Exception) {
                    result.error("MEDIA_CLEAR_FAILED", error.message, null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "joyal_music/media_store")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "audioExists" -> try {
                        val uri = Uri.parse(call.argument<String>("uri"))
                        contentResolver.openFileDescriptor(uri, "r")?.use { }
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                    "findAudio" -> try {
                        result.success(findAudio(call.argument<String>("displayName")!!))
                    } catch (error: Exception) {
                        result.error("QUERY_FAILED", error.message, null)
                    }
                    "deleteAudio" -> try {
                        val uri = Uri.parse(call.argument<String>("uri"))
                        contentResolver.delete(uri, null, null)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("DELETE_FAILED", error.message, null)
                    }
                    "enqueueDownload" -> try {
                        result.success(enqueueDownload(call.arguments as Map<*, *>))
                    } catch (error: Exception) {
                        result.error("ENQUEUE_FAILED", error.message, null)
                    }
                    "queryDownload" -> try {
                        result.success(queryDownload(call.argument<Number>("id")!!.toLong()))
                    } catch (error: Exception) {
                        result.error("QUERY_DOWNLOAD_FAILED", error.message, null)
                    }
                    "cancelDownload" -> try {
                        downloadManager().remove(call.argument<Number>("id")!!.toLong())
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("CANCEL_DOWNLOAD_FAILED", error.message, null)
                    }
                    "publishAudio" -> try {
                        result.success(publishAudio(call.arguments as Map<*, *>))
                    } catch (error: Exception) {
                        result.error("PUBLISH_FAILED", error.message, null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun downloadManager(): DownloadManager =
        getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    private fun enqueueDownload(args: Map<*, *>): Long {
        val request = DownloadManager.Request(Uri.parse(args["url"] as String)).apply {
            setTitle(args["title"] as String)
            setDescription("Joyal Music 正在下载原始音频")
            setMimeType(args["mimeType"] as String)
            setAllowedOverMetered(true)
            setAllowedOverRoaming(true)
            setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            setDestinationInExternalPublicDir(
                Environment.DIRECTORY_MUSIC,
                "Joyal DL/${args["displayName"] as String}",
            )
        }
        return downloadManager().enqueue(request)
    }

    private fun queryDownload(id: Long): Map<String, Any?> {
        val query = DownloadManager.Query().setFilterById(id)
        downloadManager().query(query)?.use { cursor ->
            if (!cursor.moveToFirst()) {
                return mapOf("status" to "missing")
            }
            val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            val downloaded = cursor.getLong(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR),
            )
            val total = cursor.getLong(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES),
            )
            val reason = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
            val snapshot = "$status:$reason:$downloaded:$total"
            if (lastDownloadSnapshots[id] != snapshot) {
                Log.i(
                    "JoyalDownload",
                    "id=$id status=${downloadStatusName(status)} reason=$reason " +
                        "downloaded=$downloaded total=$total",
                )
                lastDownloadSnapshots[id] = snapshot
            }
            return when (status) {
                DownloadManager.STATUS_SUCCESSFUL -> mapOf(
                    "status" to "successful",
                    "rawStatus" to status,
                    "downloaded" to downloaded,
                    "total" to total,
                    "reason" to reason,
                    "uri" to downloadManager().getUriForDownloadedFile(id)?.toString(),
                )
                DownloadManager.STATUS_FAILED -> mapOf(
                    "status" to "failed",
                    "rawStatus" to status,
                    "downloaded" to downloaded,
                    "total" to total,
                    "reason" to reason,
                )
                DownloadManager.STATUS_PAUSED -> mapOf(
                    "status" to "paused",
                    "rawStatus" to status,
                    "downloaded" to downloaded,
                    "total" to total,
                    "reason" to reason,
                )
                DownloadManager.STATUS_PENDING -> mapOf(
                    "status" to "pending",
                    "rawStatus" to status,
                    "downloaded" to downloaded,
                    "total" to total,
                    "reason" to reason,
                )
                else -> mapOf(
                    "status" to "running",
                    "rawStatus" to status,
                    "downloaded" to downloaded,
                    "total" to total,
                    "reason" to reason,
                )
            }
        }
        return mapOf("status" to "missing")
    }

    private fun downloadStatusName(status: Int): String = when (status) {
        DownloadManager.STATUS_PENDING -> "pending"
        DownloadManager.STATUS_RUNNING -> "running"
        DownloadManager.STATUS_PAUSED -> "paused"
        DownloadManager.STATUS_SUCCESSFUL -> "successful"
        DownloadManager.STATUS_FAILED -> "failed"
        else -> "unknown($status)"
    }

    private fun findAudio(displayName: String): Map<String, Any>? {
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.SIZE,
        )
        val selection = "${MediaStore.Audio.Media.DISPLAY_NAME} = ?"
        contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            arrayOf(displayName),
            "${MediaStore.Audio.Media.DATE_ADDED} DESC",
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID))
                val size = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE))
                val uri = Uri.withAppendedPath(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id.toString())
                return mapOf("uri" to uri.toString(), "size" to size)
            }
        }
        return null
    }

    private fun publishAudio(args: Map<*, *>): String {
        val source = File(args["sourcePath"] as String)
        val displayName = args["displayName"] as String
        val mimeType = args["mimeType"] as String

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
                put(MediaStore.Audio.Media.MIME_TYPE, mimeType)
                put(MediaStore.Audio.Media.TITLE, args["title"] as String)
                put(MediaStore.Audio.Media.ARTIST, args["artist"] as String)
                put(MediaStore.Audio.Media.ALBUM, args["album"] as String)
                put(MediaStore.Audio.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MUSIC}/Joyal DL")
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("无法在系统音乐库中创建文件")
            try {
                resolver.openOutputStream(uri, "w")!!.use { output ->
                    FileInputStream(source).use { input -> input.copyTo(output) }
                }
                values.clear()
                values.put(MediaStore.Audio.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                return uri.toString()
            } catch (error: Exception) {
                resolver.delete(uri, null, null)
                throw error
            }
        }

        @Suppress("DEPRECATION")
        val directory = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC), "Joyal DL")
        if (!directory.exists() && !directory.mkdirs()) {
            throw IllegalStateException("无法创建公共音乐目录")
        }
        val destination = File(directory, displayName)
        FileInputStream(source).use { input ->
            FileOutputStream(destination).use { output -> input.copyTo(output) }
        }
        MediaScannerConnection.scanFile(this, arrayOf(destination.path), arrayOf(mimeType), null)
        return Uri.fromFile(destination).toString()
    }

    override fun onDestroy() {
        mediaSessionManager?.release()
        mediaSessionManager = null
        super.onDestroy()
    }
}
