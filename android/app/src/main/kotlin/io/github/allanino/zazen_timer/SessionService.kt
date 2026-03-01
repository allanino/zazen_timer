package io.github.allanino.zazen_timer

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import org.json.JSONArray

class SessionService : Service() {

  private var steps: List<StepSpec> = emptyList()
  private var sessionStartTimeMillis: Long = 0L
  private val transitionPendingIntents = mutableListOf<PendingIntent>()

  private val notificationManager: NotificationManager
    get() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

  private val alarmManager: AlarmManager
    get() = getSystemService(Context.ALARM_SERVICE) as AlarmManager

  private val prefs: SharedPreferences
    get() = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when {
      intent?.action == ACTION_TRANSITION || intent?.hasExtra(EXTRA_STEP_INDEX) == true -> {
        handleTransition(intent.getIntExtra(EXTRA_STEP_INDEX, -1))
      }
      intent?.hasExtra(EXTRA_SESSION) == true -> {
        handleStartSession(intent.getStringExtra(EXTRA_SESSION) ?: "[]")
      }
      else -> {
        stopSelf()
        return START_NOT_STICKY
      }
    }
    return START_NOT_STICKY
  }

  private fun handleStartSession(sessionJson: String) {
    steps = parseSessionJson(sessionJson)
    if (steps.isEmpty()) {
      stopSelf()
      return
    }

    sessionStartTimeMillis = System.currentTimeMillis()
    persistSession(sessionJson, sessionStartTimeMillis)
    companionSteps = steps
    companionSessionStartTimeMillis = sessionStartTimeMillis

    ensureNotificationChannel()
    startForegroundWithType()

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
      companionSteps = emptyList()
      companionSessionStartTimeMillis = 0L
      clearPersistedSession()
      stopSelf()
      return
    }
    scheduleTransitionAlarms()
  }

  private fun handleTransition(stepIndex: Int) {
    if (steps.isEmpty()) {
      restoreFromPrefs()
    }
    if (steps.isEmpty() || stepIndex < 0 || stepIndex >= steps.size) return

    val fromType = steps[stepIndex].type
    val nextIndex = stepIndex + 1
    val toType = steps.getOrNull(nextIndex)?.type

    triggerTransitionVibration(fromType, toType)
    if (nextIndex >= steps.size) {
      triggerSessionEndVibration()
      clearPersistedSession()
      companionSteps = emptyList()
      companionSessionStartTimeMillis = 0L
      cancelAllScheduledAlarms()
      stopSelf()
      return
    }
    notificationManager.notify(NOTIFICATION_ID, createNotification(toType!!))
  }

  private fun scheduleTransitionAlarms() {
    transitionPendingIntents.clear()
    val nowWall = System.currentTimeMillis()
    val nowElapsed = SystemClock.elapsedRealtime()
    var cumulativeMs = 0L
    for (i in steps.indices) {
      cumulativeMs += steps[i].durationMs
      val triggerAtWall = sessionStartTimeMillis + cumulativeMs
      val triggerAtElapsed = nowElapsed + (triggerAtWall - nowWall)
      val intent = Intent(this, SessionService::class.java).apply {
        action = ACTION_TRANSITION
        putExtra(EXTRA_STEP_INDEX, i)
      }
      val pending = PendingIntent.getService(
        this,
        i,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      )
      transitionPendingIntents.add(pending)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        alarmManager.setExactAndAllowWhileIdle(
          AlarmManager.ELAPSED_REALTIME_WAKEUP,
          triggerAtElapsed,
          pending
        )
      } else {
        @Suppress("DEPRECATION")
        alarmManager.setExact(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtElapsed, pending)
      }
    }
  }

  private fun cancelAllScheduledAlarms() {
    for (pending in transitionPendingIntents) {
      alarmManager.cancel(pending)
    }
    transitionPendingIntents.clear()
  }

  private fun persistSession(sessionJson: String, startTimeMillis: Long) {
    prefs.edit()
      .putString(KEY_SESSION_JSON, sessionJson)
      .putLong(KEY_SESSION_START, startTimeMillis)
      .apply()
  }

  private fun clearPersistedSession() {
    prefs.edit()
      .remove(KEY_SESSION_JSON)
      .remove(KEY_SESSION_START)
      .apply()
  }

  private fun restoreFromPrefs() {
    val json = prefs.getString(KEY_SESSION_JSON, null) ?: return
    val startTime = prefs.getLong(KEY_SESSION_START, 0L)
    if (startTime == 0L) return
    steps = parseSessionJson(json)
    sessionStartTimeMillis = startTime
    companionSteps = steps
    companionSessionStartTimeMillis = sessionStartTimeMillis
  }

  override fun onDestroy() {
    cancelAllScheduledAlarms()
    companionSteps = emptyList()
    companionSessionStartTimeMillis = 0L
    clearPersistedSession()
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
    const val EXTRA_SESSION = "session"
    private const val ACTION_TRANSITION = "io.github.allanino.zazen_timer.TRANSITION"
    private const val EXTRA_STEP_INDEX = "step_index"
    private const val PREFS_NAME = "zazen_session"
    private const val KEY_SESSION_JSON = "session_json"
    private const val KEY_SESSION_START = "session_start_millis"

    private var companionSteps: List<StepSpec> = emptyList()

    private var companionSessionStartTimeMillis: Long = 0L

    fun getCurrentState(nowMillis: Long): SessionState? {
      val steps = companionSteps
      val sessionStart = companionSessionStartTimeMillis
      if (steps.isEmpty() || sessionStart == 0L) return null
      var cumulativeMs = 0L
      for (i in steps.indices) {
        val step = steps[i]
        val stepEndMs = cumulativeMs + step.durationMs
        val stepStartWall = sessionStart + cumulativeMs
        if (nowMillis < sessionStart + stepEndMs) {
          return SessionState(
            stepIndex = i,
            stepType = step.type,
            stepStartTimeMillis = stepStartWall,
            stepDurationMs = step.durationMs,
          )
        }
        cumulativeMs = stepEndMs
      }
      return null
    }

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
