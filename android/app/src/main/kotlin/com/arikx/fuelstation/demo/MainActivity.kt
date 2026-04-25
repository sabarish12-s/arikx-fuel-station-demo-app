package com.arikx.fuelstation.demo

import android.accounts.AccountManager
import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.google.android.gms.common.AccountPicker
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val DOWNLOADS_CHANNEL = "com.rk.fuels.rk_fuels/downloads"
        private const val NATIVE_CONFIG_CHANNEL = "com.rk.fuels.rk_fuels/native_config"
        private const val NOTIFICATIONS_CHANNEL = "com.rk.fuels.rk_fuels/notifications"
        private const val DOWNLOAD_NOTIFICATION_CHANNEL_ID = "download_reports"
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 4201
        private const val ACCOUNT_PICKER_REQUEST_CODE = 4202
    }

    private var pendingAccountPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createDownloadNotificationChannel()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NATIVE_CONFIG_CHANNEL
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
            } else if (call.method == "pickGoogleAccount") {
                pickGoogleAccount(result)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DOWNLOADS_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "saveTextFileToDownloads") {
                val fileName = call.argument<String>("fileName")?.trim().orEmpty()
                val mimeType = call.argument<String>("mimeType")?.trim().orEmpty()
                val text = call.argument<String>("text") ?: ""
                val notificationTitle = call.argument<String>("notificationTitle")?.trim().orEmpty()
                val notificationBody = call.argument<String>("notificationBody")?.trim().orEmpty()

                if (fileName.isEmpty()) {
                    result.error("invalid_args", "fileName is required", null)
                    return@setMethodCallHandler
                }

                try {
                    val savedLocation = saveTextFileToDownloads(fileName, mimeType, text)
                    if (notificationTitle.isNotEmpty()) {
                        showDownloadNotification(
                            title = notificationTitle,
                            body = notificationBody.ifEmpty { fileName },
                            openLocation = savedLocation,
                            mimeType = mimeType.ifEmpty { "text/csv" },
                        )
                    }
                    result.success(savedLocation)
                } catch (error: Exception) {
                    result.error("save_failed", error.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATIONS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> {
                    result.success(requestNotificationPermission())
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Android framework, still used by AccountPicker.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != ACCOUNT_PICKER_REQUEST_CODE) {
            return
        }

        val result = pendingAccountPickerResult ?: return
        pendingAccountPickerResult = null
        if (resultCode != RESULT_OK) {
            result.error("account_picker_cancelled", "Google account selection was cancelled.", null)
            return
        }

        val email = data?.getStringExtra(AccountManager.KEY_ACCOUNT_NAME).orEmpty()
        if (email.isBlank()) {
            result.error("account_picker_empty", "No Google account was selected.", null)
            return
        }
        result.success(email)
    }

    private fun pickGoogleAccount(result: MethodChannel.Result) {
        if (pendingAccountPickerResult != null) {
            result.error("account_picker_busy", "Google account picker is already open.", null)
            return
        }

        pendingAccountPickerResult = result
        try {
            val intent = AccountPicker.newChooseAccountIntent(
                null,
                null,
                arrayOf("com.google"),
                false,
                null,
                null,
                null,
                null
            )
            startActivityForResult(intent, ACCOUNT_PICKER_REQUEST_CODE)
        } catch (error: Exception) {
            pendingAccountPickerResult = null
            result.error("account_picker_failed", error.message, null)
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
            return uri.toString()
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

    private fun createDownloadNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            DOWNLOAD_NOTIFICATION_CHANNEL_ID,
            "Report Downloads",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Notifications for downloaded reports"
        }
        manager.createNotificationChannel(channel)
    }

    private fun requestNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            return true
        }
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_REQUEST_CODE)
        return false
    }

    private fun showDownloadNotification(
        title: String,
        body: String,
        openLocation: String,
        mimeType: String,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val pendingIntent = buildOpenFilePendingIntent(openLocation, mimeType)
        val notification = NotificationCompat.Builder(this, DOWNLOAD_NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        NotificationManagerCompat.from(this).notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), notification)
    }

    private fun buildOpenFilePendingIntent(openLocation: String, mimeType: String): PendingIntent {
        val intent = buildOpenFileIntent(openLocation, mimeType)
        return PendingIntent.getActivity(
            this,
            (System.currentTimeMillis() % Int.MAX_VALUE).toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun buildOpenFileIntent(openLocation: String, mimeType: String): Intent {
        val intent = Intent(Intent.ACTION_VIEW)
        val uri = when {
            openLocation.startsWith("content://") || openLocation.startsWith("file://") ->
                Uri.parse(openLocation)
            openLocation.startsWith("/") -> {
                FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    File(openLocation)
                )
            }
            else -> null
        }

        if (uri != null) {
            intent.setDataAndType(uri, mimeType.ifEmpty { "text/csv" })
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY) == null) {
                intent.setDataAndType(uri, "*/*")
            }
        }

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return intent
    }
}
