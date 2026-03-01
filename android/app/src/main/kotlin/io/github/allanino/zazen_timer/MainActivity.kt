package io.github.allanino.zazen_timer

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val channelName = "zazen_timer/haptics"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "hasVibrator" -> {
            val v = getVibrator()
            result.success(v?.hasVibrator() == true)
          }
          "vibrateOneShot" -> {
            val durationMs = call.argument<Int>("durationMs") ?: 0
            vibrateOneShot(durationMs.toLong())
            result.success(null)
          }
          "vibratePattern" -> {
            val pattern = call.argument<List<Int>>("pattern") ?: emptyList()
            vibratePattern(pattern.map { it.toLong() }.toLongArray())
            result.success(null)
          }
          else -> result.notImplemented()
        }
      }

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
          else -> result.notImplemented()
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

  private fun getVibrator(): Vibrator? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager?
      manager?.defaultVibrator
    } else {
      @Suppress("DEPRECATION")
      getSystemService(Context.VIBRATOR_SERVICE) as Vibrator?
    }
  }

  private fun vibrateOneShot(durationMs: Long) {
    val vibrator = getVibrator() ?: return
    if (!vibrator.hasVibrator()) return

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      vibrator.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
    } else {
      @Suppress("DEPRECATION")
      vibrator.vibrate(durationMs)
    }
  }

  private fun vibratePattern(pattern: LongArray) {
    val vibrator = getVibrator() ?: return
    if (!vibrator.hasVibrator()) return
    if (pattern.isEmpty()) return

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
    } else {
      @Suppress("DEPRECATION")
      vibrator.vibrate(pattern, -1)
    }
  }
}
