package com.example.zazen_timer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import org.json.JSONArray

class SessionService : Service() {

  private val handler = Handler(Looper.getMainLooper())
  private var checkRunnable: Runnable? = null

  private var steps: List<StepSpec> = emptyList()
  private var sessionStartTimeMillis: Long = 0L
  private var currentStepIndex: Int = 0
  private var stepStartTimeMillis: Long = 0L

  private val notificationManager: NotificationManager
    get() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    val sessionJson = intent?.getStringExtra(EXTRA_SESSION) ?: "[]"
    steps = parseSessionJson(sessionJson)
    if (steps.isEmpty()) {
      stopSelf()
      return START_NOT_STICKY
    }

    ensureNotificationChannel()
    startForegroundWithType()

    sessionStartTimeMillis = System.currentTimeMillis()
    currentStepIndex = 0
    stepStartTimeMillis = sessionStartTimeMillis
    updateStateForFlutter()

    checkRunnable = Runnable {
      val now = System.currentTimeMillis()
      val step = steps.getOrNull(currentStepIndex) ?: return@Runnable
      val stepEndTime = stepStartTimeMillis + step.durationMs

      notificationManager.notify(NOTIFICATION_ID, createNotification(step.type))

      if (now >= stepEndTime) {
        val nextIndex = currentStepIndex + 1
        triggerTransitionVibration(step.type, steps.getOrNull(nextIndex)?.type)
        if (nextIndex >= steps.size) {
          triggerSessionEndVibration()
          clearStateForFlutter()
          stopSelf()
          return@Runnable
        }
        currentStepIndex = nextIndex
        stepStartTimeMillis = now
        updateStateForFlutter()
      }
      checkRunnable?.let { handler.postDelayed(it, CHECK_INTERVAL_MS) }
    }
    handler.post(checkRunnable!!)

    return START_NOT_STICKY
  }

  override fun onDestroy() {
    checkRunnable?.let { handler.removeCallbacks(it) }
    checkRunnable = null
    clearStateForFlutter()
    super.onDestroy()
  }

  private fun parseSessionJson(json: String): List<StepSpec> {
    val list = mutableListOf<StepSpec>()
    try {
      val arr = JSONArray(json)
      for (i in 0 until arr.length()) {
        val obj = arr.getJSONObject(i)
        val type = obj.optString("t", "zazen")
        val durationSeconds = obj.optInt("d", 0)
        list.add(StepSpec(type = type, durationMs = durationSeconds * 1000L))
      }
    } catch (_: Exception) {
      // ignore
    }
    return list
  }

  private fun notificationTitleFor(stepType: String): String {
    return when (stepType) {
      "preStart" -> getString(R.string.session_notification_title_waiting)
      "zazen" -> getString(R.string.session_notification_title_zazen)
      "kinhin" -> getString(R.string.session_notification_title_kinhin)
      else -> getString(R.string.session_notification_title_zazen)
    }
  }

  private fun triggerTransitionVibration(fromType: String, toType: String?) {
    val vibrator = getVibrator() ?: return
    if (!vibrator.hasVibrator()) return
    when {
      fromType == "preStart" && toType == "zazen" -> vibrateThreeMedium()
      fromType == "zazen" && toType == "kinhin" -> vibrateTwoMedium()
      fromType == "kinhin" && toType == "zazen" -> vibrateThreeMedium()
      else -> { /* no pattern */ }
    }
  }

  private fun triggerSessionEndVibration() {
    vibrateOneLong()
  }

  private fun vibrateThreeMedium() {
    vibratePattern(longArrayOf(0, 100, 200, 100, 200, 100))
  }

  private fun vibrateTwoMedium() {
    vibratePattern(longArrayOf(0, 100, 200, 100))
  }

  private fun vibrateOneLong() {
    val v = getVibrator() ?: return
    if (!v.hasVibrator()) return
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      v.vibrate(VibrationEffect.createOneShot(300, VibrationEffect.DEFAULT_AMPLITUDE))
    } else {
      @Suppress("DEPRECATION")
      v.vibrate(300)
    }
  }

  private fun vibratePattern(pattern: LongArray) {
    val v = getVibrator() ?: return
    if (!v.hasVibrator() || pattern.isEmpty()) return
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      v.vibrate(VibrationEffect.createWaveform(pattern, -1))
    } else {
      @Suppress("DEPRECATION")
      v.vibrate(pattern, -1)
    }
  }

  private fun getVibrator(): Vibrator? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
    } else {
      @Suppress("DEPRECATION")
      getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }
  }

  private fun updateStateForFlutter() {
    val step = steps.getOrNull(currentStepIndex) ?: return
    currentState = SessionState(
      stepIndex = currentStepIndex,
      stepType = step.type,
      stepStartTimeMillis = stepStartTimeMillis,
      stepDurationMs = step.durationMs,
    )
  }

  private fun clearStateForFlutter() {
    currentState = null
  }

  private fun ensureNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        CHANNEL_ID,
        getString(R.string.session_channel_name),
        NotificationManager.IMPORTANCE_LOW
      ).apply {
        setShowBadge(false)
        enableVibration(false)
        setSound(null, null)
      }
      (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
        .createNotificationChannel(channel)
    }
  }

  private fun startForegroundWithType() {
    val step = steps.firstOrNull() ?: return
    val notification = createNotification(step.type)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
      startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
    } else {
      @Suppress("DEPRECATION")
      startForeground(NOTIFICATION_ID, notification)
    }
  }

  private fun createNotification(stepType: String): Notification {
    val contentIntent = PendingIntent.getActivity(
      this,
      0,
      Intent(this, MainActivity::class.java),
      PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )
    val title = notificationTitleFor(stepType)
    val contentText = getString(R.string.session_notification_tap_to_open)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      return Notification.Builder(this, CHANNEL_ID)
        .setContentTitle(title)
        .setContentText(contentText)
        .setSmallIcon(android.R.drawable.ic_media_play)
        .setOngoing(true)
        .setCategory(Notification.CATEGORY_SERVICE)
        .setContentIntent(contentIntent)
        .setOnlyAlertOnce(true)
        .build()
    }
    @Suppress("DEPRECATION")
    return Notification.Builder(this)
      .setContentTitle(title)
      .setContentText(contentText)
      .setSmallIcon(android.R.drawable.ic_media_play)
      .setOngoing(true)
      .setCategory(Notification.CATEGORY_SERVICE)
      .setContentIntent(contentIntent)
      .build()
  }

  private data class StepSpec(val type: String, val durationMs: Long)

  companion object {
    private const val CHANNEL_ID = "zazen_session"
    private const val NOTIFICATION_ID = 1
    private const val CHECK_INTERVAL_MS = 500L
    const val EXTRA_SESSION = "session"

    var currentState: SessionState? = null
      private set

    fun intent(context: Context, sessionJson: String): Intent {
      return Intent(context, SessionService::class.java).putExtra(EXTRA_SESSION, sessionJson)
    }
  }
}

data class SessionState(
  val stepIndex: Int,
  val stepType: String,
  val stepStartTimeMillis: Long,
  val stepDurationMs: Long,
) {
  fun remainingMs(nowMillis: Long): Long =
    (stepStartTimeMillis + stepDurationMs - nowMillis).coerceAtLeast(0)
}
