package com.example.date

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "date/native")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingCapture" -> {
                    val p = pendingPath
                    pendingPath = null
                    result.success(p)
                }
                "clearCaptures" -> {
                    File(cacheDir, "assist_capture.jpg").delete()
                    File(cacheDir, "shared_capture.jpg").delete()
                    result.success(true)
                }
                "openAssistSettings" -> result.success(openAssistSettings())
                "setOverlay" -> result.success(setOverlay(call.argument<Boolean>("on") == true))
                else -> result.notImplemented()
            }
        }
        handleIntent(intent, false)
    }

    override fun onResume() {
        super.onResume()
        DateAssistService.instance?.hideBubble()
    }

    override fun onPause() {
        super.onPause()
        val on = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .getBoolean("flutter.overlayOn", false)
        if (on) DateAssistService.instance?.showBubble()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent, true)
    }

    @Suppress("DEPRECATION")
    private fun handleIntent(i: Intent?, notify: Boolean) {
        if (i == null) return
        var path: String? = null
        val extra = i.getStringExtra("capture_path")
        if (extra != null) {
            path = extra
        } else if (i.getBooleanExtra("capture_error", false)) {
            path = "ERROR"
        } else if (i.action == Intent.ACTION_SEND && i.type?.startsWith("image/") == true) {
            val uri: Uri? = if (Build.VERSION.SDK_INT >= 33) {
                i.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                i.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }
            if (uri != null) path = copyToCache(uri)
        }
        if (path != null) {
            val ch = channel
            if (notify && ch != null) {
                pendingPath = null
                ch.invokeMethod("onCapture", path)
            } else {
                pendingPath = path
            }
            setIntent(Intent())
        }
    }

    private fun copyToCache(uri: Uri): String? {
        return try {
            val f = File(cacheDir, "shared_capture.jpg")
            contentResolver.openInputStream(uri)?.use { input ->
                f.outputStream().use { out -> input.copyTo(out) }
            }
            f.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun setOverlay(on: Boolean): String {
        if (!on) {
            DateAssistService.instance?.hideBubble()
            return "ok"
        }
        if (!Settings.canDrawOverlays(this)) {
            try {
                startActivity(
                    Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            } catch (e: Exception) {
            }
            return "need_permission"
        }
        DateAssistService.instance ?: return "need_assistant"
        return "ok"
    }

    private fun openAssistSettings(): Boolean {
        val actions = listOf(
            Settings.ACTION_VOICE_INPUT_SETTINGS,
            Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS,
            Settings.ACTION_SETTINGS
        )
        for (a in actions) {
            try {
                startActivity(Intent(a).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: Exception) {
            }
        }
        return false
    }
}
