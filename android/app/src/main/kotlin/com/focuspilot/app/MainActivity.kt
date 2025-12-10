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

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.focusflow/permissions"

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
            } else if (call.method == "bringAppToFront") {
                android.util.Log.d("FocusFlow", "bringAppToFront called")
                android.widget.Toast.makeText(applicationContext, "FocusFlow: Blocking App!", android.widget.Toast.LENGTH_SHORT).show()
                
                // Try to launch activity first
                val launchIntent = applicationContext.packageManager.getLaunchIntentForPackage(packageName)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    try {
                        applicationContext.startActivity(launchIntent)
                    } catch (e: Exception) {
                        android.util.Log.e("FocusFlow", "Failed to start activity: ${e.message}")
                        // Fallback to PendingIntent
                         val pendingIntent = android.app.PendingIntent.getActivity(
                            applicationContext,
                            0,
                            launchIntent,
                            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                        )
                        try {
                            pendingIntent.send()
                        } catch (e2: Exception) {
                            e2.printStackTrace()
                        }
                    }
                }

                // Force blocking using Overlay if permission is granted
                if (Settings.canDrawOverlays(applicationContext)) {
                    val windowManager = applicationContext.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager
                    val params = android.view.WindowManager.LayoutParams(
                        android.view.WindowManager.LayoutParams.MATCH_PARENT,
                        android.view.WindowManager.LayoutParams.MATCH_PARENT,
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                            android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                        else
                            android.view.WindowManager.LayoutParams.TYPE_PHONE,
                        android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                                android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                                android.view.WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                        android.graphics.PixelFormat.TRANSLUCENT
                    )
                    
                    val view = android.widget.FrameLayout(applicationContext)
                    view.setBackgroundColor(android.graphics.Color.BLACK) // Black screen block
                    
                    // Add a text view to explain
                    val textView = android.widget.TextView(applicationContext)
                    textView.text = "Focus Mode Active"
                    textView.setTextColor(android.graphics.Color.WHITE)
                    textView.textSize = 24f
                    textView.gravity = android.view.Gravity.CENTER
                    view.addView(textView)

                    try {
                        windowManager.addView(view, params)
                        // Remove view after a short delay to allow app to launch
                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            try {
                                windowManager.removeView(view)
                            } catch (e: Exception) {}
                        }, 2000)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
                result.success(null)
            } else {
                result.notImplemented()
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

        val stats = usageStatsManager.queryUsageStats(android.app.usage.UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
        if (stats != null && stats.isNotEmpty()) {
            val sortedStats = stats.sortedByDescending { it.lastTimeUsed }
            return sortedStats[0].packageName
        }
        return null
    }
}
