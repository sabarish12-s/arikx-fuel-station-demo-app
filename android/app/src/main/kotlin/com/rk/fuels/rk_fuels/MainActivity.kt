package com.rk.fuels.rk_fuels

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.rk.fuels.rk_fuels/native_config"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getDefaultWebClientId") {
                val resId = resources.getIdentifier(
                    "default_web_client_id",
                    "string",
                    packageName
                )
                if (resId != 0) {
                    result.success(getString(resId))
                } else {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.rk.fuels.rk_fuels/downloads"
        ).setMethodCallHandler { call, result ->
            if (call.method == "saveTextFileToDownloads") {
                val fileName = call.argument<String>("fileName")?.trim().orEmpty()
                val mimeType = call.argument<String>("mimeType")?.trim().orEmpty()
                val text = call.argument<String>("text") ?: ""

                if (fileName.isEmpty()) {
                    result.error("invalid_args", "fileName is required", null)
                    return@setMethodCallHandler
                }

                try {
                    val savedLocation = saveTextFileToDownloads(fileName, mimeType, text)
                    result.success(savedLocation)
                } catch (error: Exception) {
                    result.error("save_failed", error.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveTextFileToDownloads(fileName: String, mimeType: String, text: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, if (mimeType.isNotEmpty()) mimeType else "text/plain")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create download entry")

            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(text.toByteArray(Charsets.UTF_8))
                stream.flush()
            } ?: throw IllegalStateException("Could not open output stream")

            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return "Download/$fileName"
        }

        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            ?: throw IllegalStateException("Downloads directory unavailable")
        if (!downloadsDir.exists()) {
            downloadsDir.mkdirs()
        }
        val targetFile = File(downloadsDir, fileName)
        targetFile.writeText(text, Charsets.UTF_8)
        return targetFile.absolutePath
    }
}
