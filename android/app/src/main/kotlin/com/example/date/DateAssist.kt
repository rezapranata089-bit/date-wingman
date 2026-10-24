package com.example.date

import android.animation.ValueAnimator
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import android.os.Handler
import android.os.Looper
import android.service.voice.VoiceInteractionService
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService
import android.speech.RecognitionService
import java.io.File
import java.io.FileOutputStream

class DateAssistService : VoiceInteractionService() {
    companion object {
        @Volatile
        var instance: DateAssistService? = null
    }

    private var bubble: View? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onReady() {
        super.onReady()
        instance = this
        val on = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.overlayOn", false)
        if (on) showBubble()
    }

    override fun onShutdown() {
        hideBubble()
        instance = null
        super.onShutdown()
    }

    @Suppress("DEPRECATION")
    fun showBubble() {
        if (bubble != null) return
        if (!Settings.canDrawOverlays(this)) return
        try {
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val dm = resources.displayMetrics
            val density = dm.density
            val size = (46 * density).toInt()
            val v = TextView(this)
            v.text = "✦"
            v.gravity = Gravity.CENTER
            v.setTextColor(Color.WHITE)
            v.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            val bg = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(Color.parseColor("#FF4081"), Color.parseColor("#7C4DFF"))
            )
            bg.shape = GradientDrawable.OVAL
            bg.setStroke((2 * density).toInt(), Color.argb(200, 255, 255, 255))
            v.background = bg
            v.alpha = 0.8f
            val type = if (Build.VERSION.SDK_INT >= 26) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            }
            val lp = WindowManager.LayoutParams(
                size, size, type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            )
            lp.gravity = Gravity.TOP or Gravity.START
            lp.x = -size / 3
            lp.y = (200 * density).toInt()
            v.setOnTouchListener(object : View.OnTouchListener {
                var sx = 0
                var sy = 0
                var tx = 0f
                var ty = 0f
                var moved = false
                var longDone = false
                val longRun = Runnable {
                    longDone = true
                    getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        .edit().putBoolean("flutter.overlayOn", false).apply()
                    hideBubble()
                }

                override fun onTouch(view: View, e: MotionEvent): Boolean {
                    when (e.action) {
                        MotionEvent.ACTION_DOWN -> {
                            sx = lp.x
                            sy = lp.y
                            tx = e.rawX
                            ty = e.rawY
                            moved = false
                            longDone = false
                            view.alpha = 1f
                            mainHandler.postDelayed(longRun, 700)
                        }
                        MotionEvent.ACTION_MOVE -> {
                            val dx = (e.rawX - tx).toInt()
                            val dy = (e.rawY - ty).toInt()
                            if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                                moved = true
                                mainHandler.removeCallbacks(longRun)
                            }
                            if (moved) {
                                lp.x = sx + dx
                                lp.y = sy + dy
                                try {
                                    wm.updateViewLayout(view, lp)
                                } catch (ex: Exception) {
                                }
                            }
                        }
                        MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                            mainHandler.removeCallbacks(longRun)
                            if (longDone) return true
                            view.alpha = 0.8f
                            if (moved) {
                                val edge = if (e.rawX < dm.widthPixels / 2) {
                                    -size / 3
                                } else {
                                    dm.widthPixels - size * 2 / 3
                                }
                                val a = ValueAnimator.ofInt(lp.x, edge)
                                a.duration = 160
                                a.addUpdateListener {
                                    lp.x = it.animatedValue as Int
                                    try {
                                        wm.updateViewLayout(view, lp)
                                    } catch (ex: Exception) {
                                    }
                                }
                                a.start()
                            } else if (e.action == MotionEvent.ACTION_UP) {
                                trigger()
                            }
                        }
                    }
                    return true
                }
            })
            wm.addView(v, lp)
            bubble = v
        } catch (e: Exception) {
            bubble = null
        }
    }

    fun hideBubble() {
        val v = bubble ?: return
        try {
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(v)
        } catch (e: Exception) {
        }
        bubble = null
    }

    private fun trigger() {
        val v = bubble ?: return
        v.visibility = View.INVISIBLE
        mainHandler.postDelayed({
            try {
                showSession(
                    Bundle(),
                    VoiceInteractionSession.SHOW_WITH_ASSIST or
                        VoiceInteractionSession.SHOW_WITH_SCREENSHOT
                )
            } catch (e: Exception) {
            }
        }, 500)
        mainHandler.postDelayed({ bubble?.visibility = View.VISIBLE }, 3500)
    }
}

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