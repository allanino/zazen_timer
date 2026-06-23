package io.github.allanino.zazen_timer

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.wear.remote.interactions.RemoteActivityHelper
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "session_service")
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "startSession" -> {
            val sessionJson = call.argument<String>("session") ?: "[]"
            startForegroundService(SessionService.intent(this, sessionJson))
            result.success(null)
          }
          "stopSession" -> {
            stopService(Intent(this, SessionService::class.java))
            result.success(null)
          }
          "getSessionState" -> {
            val now = System.currentTimeMillis()
            val state = SessionService.getCurrentState(now)
            if (state == null) {
              result.success(null)
            } else {
              result.success(mapOf(
                "stepIndex" to state.stepIndex,
                "stepType" to state.stepType,
                "remainingMs" to state.remainingMs(now),
                "stepTotalMs" to state.stepDurationMs,
              ))
            }
          }
          "canScheduleExactAlarms" -> {
            result.success(canScheduleExactAlarms())
          }
          "openExactAlarmSettings" -> {
            openExactAlarmSettings()
            result.success(null)
          }
          "installOnWatch" -> {
            val apkUrl = call.argument<String>("apkUrl")
            if (apkUrl != null) {
              installOnWatch(apkUrl)
              result.success(null)
            } else {
              result.error("INVALID_ARGUMENT", "apkUrl is required", null)
            }
          }
          else -> result.notImplemented()
        }
      }
  }

  private fun installOnWatch(apkPath: String) {
    val fileUri = Uri.fromFile(java.io.File(apkPath))
    val channelClient = Wearable.getChannelClient(this)
    Wearable.getNodeClient(this).connectedNodes.addOnSuccessListener { nodes ->
      for (node in nodes) {
        channelClient.openChannel(node.id, "/install_apk").addOnSuccessListener { channel ->
            channelClient.sendFile(channel, fileUri)
        }
      }
    }
  }

  private fun canScheduleExactAlarms(): Boolean {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      (getSystemService(Context.ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms()
    } else {
      true
    }
  }

  private fun openExactAlarmSettings() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
        data = Uri.parse("package:$packageName")
      }
      startActivity(intent)
    }
  }
}
