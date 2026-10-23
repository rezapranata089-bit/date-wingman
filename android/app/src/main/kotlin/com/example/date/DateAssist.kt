package com.example.date

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.service.voice.VoiceInteractionService
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService
import android.speech.RecognitionService
import java.io.File
import java.io.FileOutputStream

class DateAssistService : VoiceInteractionService()

class DateRecognitionService : RecognitionService() {
    override fun onStartListening(recognizerIntent: Intent?, listener: Callback?) {}
    override fun onCancel(listener: Callback?) {}
    override fun onStopListening(listener: Callback?) {}
}

class DateAssistSessionService : VoiceInteractionSessionService() {
    override fun onNewSession(args: Bundle?): VoiceInteractionSession {
        return DateAssistSession(this)
    }
}

class DateAssistSession(ctx: Context) : VoiceInteractionSession(ctx) {
    private var launched = false
    private val handler = Handler(Looper.getMainLooper())

    override fun onShow(args: Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        launched = false
        handler.postDelayed({
            if (!launched) launchApp(null, true)
        }, 1800)
    }

    override fun onHide() {
        handler.removeCallbacksAndMessages(null)
        super.onHide()
    }

    override fun onHandleScreenshot(screenshot: Bitmap?) {
        super.onHandleScreenshot(screenshot)
        if (screenshot == null) {
            launchApp(null, true)
            return
        }
        var path: String? = null
        try {
            val maxW = 1080
            val bmp = if (screenshot.width > maxW) {
                val h = (screenshot.height * maxW.toFloat() / screenshot.width).toInt()
                Bitmap.createScaledBitmap(screenshot, maxW, h, true)
            } else {
                screenshot
            }
            val f = File(context.cacheDir, "assist_capture.jpg")
            FileOutputStream(f).use { bmp.compress(Bitmap.CompressFormat.JPEG, 85, it) }
            path = f.absolutePath
            if (bmp !== screenshot) bmp.recycle()
        } catch (e: Exception) {
            path = null
        }
        launchApp(path, path == null)
    }

    private fun launchApp(path: String?, error: Boolean) {
        if (launched) return
        launched = true
        handler.removeCallbacksAndMessages(null)
        val i = Intent(context, MainActivity::class.java)
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (path != null) i.putExtra("capture_path", path)
        if (error) i.putExtra("capture_error", true)
        try {
            startAssistantActivity(i)
        } catch (e: Exception) {
            try {
                context.startActivity(i)
            } catch (e2: Exception) {
            }
        }
        try {
            hide()
        } catch (e: Exception) {
        }
    }
}