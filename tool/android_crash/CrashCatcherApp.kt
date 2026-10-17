package com.cyan.voice_realtime_translater

import android.app.Activity
import android.app.Application
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.os.Process
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.io.PrintWriter
import java.io.StringWriter
import kotlin.system.exitProcess

/**
 * Test-build helper: if the app crashes on the Java/Kotlin side (for example
 * while a plugin starts), show the stack trace in a separate screen instead of
 * the app silently closing, so testers can copy it to the developer.
 */
class CrashCatcherApp : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                val sw = StringWriter()
                error.printStackTrace(PrintWriter(sw))
                val text = "Thread: ${thread.name}\n" +
                    "Android ${android.os.Build.VERSION.RELEASE} (API ${android.os.Build.VERSION.SDK_INT}), " +
                    "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}\n\n$sw"
                val intent = Intent(base, CrashActivity::class.java)
                    .putExtra("trace", text)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                base.startActivity(intent)
                Process.killProcess(Process.myPid())
                exitProcess(10)
            } catch (_: Throwable) {
                previous?.uncaughtException(thread, error)
            }
        }
    }
}

class CrashActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val trace = intent.getStringExtra("trace") ?: "No details"
        val pad = (16 * resources.displayMetrics.density).toInt()
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#0E141B"))
            setPadding(pad, pad * 2, pad, pad)
        }
        root.addView(TextView(this).apply {
            text = "Voice Realtime Translater stopped.\nPlease send this to the developer:"
            setTextColor(Color.WHITE)
            textSize = 17f
        })
        root.addView(Button(this).apply {
            text = "Copy error"
            setOnClickListener {
                val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                cm.setPrimaryClip(ClipData.newPlainText("crash", trace))
                text = "Copied"
            }
        })
        val scroll = ScrollView(this)
        scroll.addView(TextView(this).apply {
            text = trace
            setTextColor(Color.parseColor("#FFB4B4"))
            textSize = 11f
            setTextIsSelectable(true)
        })
        root.addView(scroll, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        setContentView(root)
    }
}
