package com.focuspilot.app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import android.widget.Button
import android.widget.TextView
import android.widget.LinearLayout
import android.view.Gravity
import android.graphics.Color
import android.widget.FrameLayout

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.focuspilot.app/permissions"
    private var blockingView: FrameLayout? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "checkUsagePermission") {
                result.success(hasUsageStatsPermission())
            } else if (call.method == "requestUsagePermission") {
                startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                result.success(null)
            } else if (call.method == "checkOverlayPermission") {
                result.success(Settings.canDrawOverlays(context))
            } else if (call.method == "requestOverlayPermission") {
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                result.success(null)
            } else if (call.method == "getForegroundApp") {
                result.success(getForegroundApp())
            } else if (call.method == "removeOverlay") {
                removeBlockingOverlay()
                result.success(null)
            } else if (call.method == "bringAppToFront") {
                android.util.Log.d("MindFlux", "bringAppToFront called")
                
                val launchIntent = applicationContext.packageManager.getLaunchIntentForPackage(packageName)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                    try {
                        applicationContext.startActivity(launchIntent)
                    } catch (e: Exception) {
                        android.util.Log.e("MindFlux", "Failed to start activity: ${e.message}")
                    }
                    
                    try {
                        val pendingIntent = android.app.PendingIntent.getActivity(
                            applicationContext,
                            0,
                            launchIntent,
                            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                        )
                        pendingIntent.send()
                    } catch (e: Exception) {
                         e.printStackTrace()
                    }
                }

                // Show blocking overlay if we have permission
                if (Settings.canDrawOverlays(applicationContext)) {
                    showBlockingOverlay()
                }
                
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun showBlockingOverlay() {
        if (blockingView != null) return // Already showing

        val windowManager = applicationContext.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager
        val params = android.view.WindowManager.LayoutParams(
            android.view.WindowManager.LayoutParams.MATCH_PARENT,
            android.view.WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                android.view.WindowManager.LayoutParams.TYPE_PHONE,
            android.view.WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            android.graphics.PixelFormat.TRANSLUCENT
        )

        val layout = FrameLayout(applicationContext)
        layout.setBackgroundColor(Color.parseColor("#121212")) // Dark premium background

        val content = LinearLayout(applicationContext)
        content.orientation = LinearLayout.VERTICAL
        content.gravity = Gravity.CENTER

        val title = TextView(applicationContext)
        title.text = "FOCUS MODE ACTIVE"
        title.setTextColor(Color.WHITE)
        title.textSize = 28f
        title.setPadding(0, 0, 0, 40)
        title.gravity = Gravity.CENTER
        content.addView(title)

        val subtitle = TextView(applicationContext)
        subtitle.text = "Returning you to MindFlux..."
        subtitle.setTextColor(Color.parseColor("#888888"))
        subtitle.textSize = 16f
        subtitle.setPadding(0, 0, 0, 80)
        subtitle.gravity = Gravity.CENTER
        content.addView(subtitle)

        val button = Button(applicationContext)
        button.text = "RETURN TO MINDFLUX"
        button.setBackgroundColor(Color.parseColor("#4DB6AC")) // Teal primary color
        button.setTextColor(Color.WHITE)
        button.setPadding(40, 20, 40, 20)
        button.setOnClickListener {
            val launchIntent = applicationContext.packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                applicationContext.startActivity(launchIntent)
            }
            removeBlockingOverlay()
        }
        content.addView(button)

        layout.addView(content)
        blockingView = layout

        try {
            windowManager.addView(layout, params)
        } catch (e: Exception) {
            e.printStackTrace()
            blockingView = null
        }
    }

    private fun removeBlockingOverlay() {
        if (blockingView != null) {
            try {
                val windowManager = applicationContext.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager
                windowManager.removeView(blockingView)
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                blockingView = null
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = applicationContext.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getForegroundApp(): String? {
        if (!hasUsageStatsPermission()) return null

        val usageStatsManager = applicationContext.getSystemService(Context.USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
        val endTime = System.currentTimeMillis()
        val startTime = endTime - 1000 * 60 // Look back 1 minute

        val event = android.app.usage.UsageEvents.Event()
        
        // Let's re-implement simply: iterate and keep track of the latest MOVE_TO_FOREGROUND
        val freshEvents = usageStatsManager.queryEvents(startTime, endTime)
        var latestPackage: String? = null
        var latestTime: Long = 0
        
        while (freshEvents.hasNextEvent()) {
            freshEvents.getNextEvent(event)
            if (event.eventType == android.app.usage.UsageEvents.Event.MOVE_TO_FOREGROUND) {
                if (event.timeStamp > latestTime) {
                    latestTime = event.timeStamp
                    latestPackage = event.packageName
                }
            }
        }
        
        return latestPackage
    }
}
