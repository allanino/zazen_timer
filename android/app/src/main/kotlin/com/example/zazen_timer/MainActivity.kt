package com.example.zazen_timer

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val channelName = "zazen_timer/haptics"
  private val foregroundChannelName = "zazen_timer/foreground_service"

  override fun onCreate(savedInstanceState: android.os.Bundle?) {
    super.onCreate(savedInstanceState)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
        ActivityCompat.requestPermissions(this, arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 0)
      }
    }
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, foregroundChannelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "start" -> {
            val presetJson = call.argument<String>("preset_json")
            val title = call.argument<String>("title") ?: "Zazen Timer"
            if (!presetJson.isNullOrBlank()) {
              val intent = Intent(this, SessionForegroundService::class.java).apply {
                putExtra(SessionForegroundService.EXTRA_PRESET_JSON, presetJson)
                putExtra(SessionForegroundService.EXTRA_TITLE, title)
              }
              if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
              } else {
                startService(intent)
              }
            }
            result.success(null)
          }
          "stop" -> {
            stopService(Intent(this, SessionForegroundService::class.java))
            result.success(null)
          }
          "getState" -> {
            val state = SessionForegroundService.currentState
            if (state == null) {
              result.success(null)
            } else {
              result.success(mapOf(
                "preset_json" to state.presetJson,
                "step_index" to state.stepIndex,
                "remaining_seconds" to state.remainingSeconds,
                "step_duration_seconds" to state.steps[state.stepIndex].durationSeconds
              ))
            }
          }
          else -> result.notImplemented()
        }
      }

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
