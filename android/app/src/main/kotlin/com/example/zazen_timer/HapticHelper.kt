package com.example.zazen_timer

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

object HapticHelper {
  private fun getVibrator(context: Context): Vibrator? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager?
      manager?.defaultVibrator
    } else {
      @Suppress("DEPRECATION")
      context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator?
    }
  }

  fun oneLong(context: Context) {
    val vibrator = getVibrator(context) ?: return
    if (!vibrator.hasVibrator()) return
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      vibrator.vibrate(VibrationEffect.createOneShot(800, VibrationEffect.DEFAULT_AMPLITUDE))
    } else {
      @Suppress("DEPRECATION")
      vibrator.vibrate(800)
    }
  }

  fun twoMedium(context: Context) {
    pattern(context, longArrayOf(0, 250, 200, 250))
  }

  fun threeMedium(context: Context) {
    pattern(context, longArrayOf(0, 200, 150, 200, 150, 200))
  }

  private fun pattern(context: Context, pattern: LongArray) {
    val vibrator = getVibrator(context) ?: return
    if (!vibrator.hasVibrator() || pattern.isEmpty()) return
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
    } else {
      @Suppress("DEPRECATION")
      vibrator.vibrate(pattern, -1)
    }
  }
}
