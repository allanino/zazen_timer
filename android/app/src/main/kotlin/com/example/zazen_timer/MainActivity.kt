package com.example.zazen_timer

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
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
            val state = SessionService.currentState
            if (state == null) {
              result.success(null)
            } else {
              val now = System.currentTimeMillis()
              result.success(mapOf(
                "stepIndex" to state.stepIndex,
                "stepType" to state.stepType,
                "remainingMs" to state.remainingMs(now),
                "stepTotalMs" to state.stepDurationMs,
              ))
            }
          }
          else -> result.notImplemented()
        }
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
