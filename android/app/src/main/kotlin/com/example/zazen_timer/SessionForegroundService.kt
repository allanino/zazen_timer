package com.example.zazen_timer

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.wear.ongoing.OngoingActivity
import androidx.wear.ongoing.Status
import org.json.JSONObject

class SessionForegroundService : Service() {

  private val handler = Handler(Looper.getMainLooper())
  private var tickRunnable: Runnable? = null
  private var ongoingActivity: OngoingActivity? = null

  override fun onCreate() {
    super.onCreate()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        CHANNEL_ID,
        getString(R.string.notification_channel_name),
        NotificationManager.IMPORTANCE_DEFAULT
      ).apply { setShowBadge(false) }
      (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
        .createNotificationChannel(channel)
    }
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    val presetJson = intent?.getStringExtra(EXTRA_PRESET_JSON)
    val title = intent?.getStringExtra(EXTRA_TITLE) ?: getString(R.string.notification_default_title)

    if (presetJson.isNullOrBlank()) {
      stopSelf()
      return START_NOT_STICKY
    }

    val steps = parseSteps(presetJson)
    if (steps.isEmpty()) {
      stopSelf()
      return START_NOT_STICKY
    }

    tickRunnable?.let { handler.removeCallbacks(it) }
    val initialRemaining = steps[0].durationSeconds
    currentState = SessionState(
      presetJson = presetJson,
      steps = steps,
      remainingSeconds = initialRemaining
    )

    val initialStepType = steps[0].type
    val notifBuilder = createNotificationBuilder(title, initialRemaining, initialRemaining, initialStepType)
    val notification = notifBuilder.build()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
      @Suppress("WrongConstant")
      startForeground(NOTIFICATION_ID, notification, 0x40000000)
    } else {
      @Suppress("DEPRECATION")
      startForeground(NOTIFICATION_ID, notification)
    }
    attachOngoingActivity(notifBuilder, title, initialRemaining, initialStepType)
    scheduleTick(title)
    return START_NOT_STICKY
  }

  private fun parseSteps(presetJson: String): List<StepInfo> {
    return try {
      val json = JSONObject(presetJson)
      val arr = json.getJSONArray("steps")
      (0 until arr.length()).map { i ->
        val obj = arr.getJSONObject(i)
        StepInfo(
          type = obj.optString("type", "zazen"),
          durationSeconds = obj.optInt("durationSeconds", 0)
        )
      }.filter { it.durationSeconds > 0 }
    } catch (_: Exception) {
      emptyList()
    }
  }

  private fun scheduleTick(title: String) {
    val state = currentState ?: return
    val steps = state.steps
    val index = state.stepIndex
    if (index >= steps.size) return

    val step = steps[index]
    updateNotification(title, state.remainingSeconds, step.durationSeconds, step.type)

    tickRunnable = object : Runnable {
      override fun run() {
        val s = currentState ?: return
        val st = s.steps
        val i = s.stepIndex
        if (i >= st.size) return

        if (s.remainingSeconds > 1) {
          currentState = s.copy(remainingSeconds = s.remainingSeconds - 1)
          updateNotification(title, s.remainingSeconds - 1, st[i].durationSeconds, st[i].type)
          handler.postDelayed(this, 1000)
        } else {
          // Advance to next step
          val finishedType = st[i].type
          if (i + 1 < st.size) {
            val next = st[i + 1]
            currentState = s.copy(stepIndex = i + 1, remainingSeconds = next.durationSeconds)
            onStepTransition(finishedType, next.type)
            updateNotification(title, next.durationSeconds, next.durationSeconds, next.type)
            handler.postDelayed(this, 1000)
          } else {
            HapticHelper.oneLong(this@SessionForegroundService)
            currentState = null
            tickRunnable = null
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
              stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
              @Suppress("DEPRECATION")
              stopForeground(true)
            }
            stopSelf()
          }
        }
      }
    }
    handler.postDelayed(tickRunnable!!, 1000)
  }

  private fun onStepTransition(finishedType: String, nextType: String) {
    when {
      finishedType == "preStart" && nextType == "zazen" -> HapticHelper.threeMedium(this)
      finishedType == "zazen" && nextType == "kinhin" -> HapticHelper.twoMedium(this)
      finishedType == "kinhin" && nextType == "zazen" -> HapticHelper.threeMedium(this)
      else -> { }
    }
  }

  private fun getStepLabel(stepType: String): String = when (stepType) {
    "preStart" -> getString(R.string.notification_step_pre_start)
    "kinhin" -> getString(R.string.notification_step_kinhin)
    else -> getString(R.string.notification_step_zazen)
  }

  private fun attachOngoingActivity(notifBuilder: NotificationCompat.Builder, title: String, remainingSeconds: Int, stepType: String) {
    try {
      val status = buildStatus(title, remainingSeconds, stepType)
      val ongoing = OngoingActivity.Builder(this, NOTIFICATION_ID, notifBuilder)
        .setStatus(status)
        .build()
      ongoing.apply(this)
      ongoingActivity = ongoing
    } catch (_: Throwable) {
      ongoingActivity = null
    }
  }

  private fun buildStatus(title: String, remainingSeconds: Int, stepType: String): Status {
    val mins = remainingSeconds / 60
    val secs = remainingSeconds % 60
    val timeText = String.format("%d:%02d", mins, secs)
    val stepLabel = getStepLabel(stepType)
    return Status.Builder().addTemplate("$title · $stepLabel · $timeText").build()
  }

  private fun updateNotification(title: String, remainingSeconds: Int, stepDurationSeconds: Int, stepType: String) {
    val notification = createNotificationBuilder(title, remainingSeconds, stepDurationSeconds, stepType).build()
    (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
      .notify(NOTIFICATION_ID, notification)
    try {
      ongoingActivity?.update(this, buildStatus(title, remainingSeconds, stepType))
    } catch (_: Throwable) { }
  }

  private fun createNotificationBuilder(title: String, remainingSeconds: Int, stepDurationSeconds: Int, stepType: String): NotificationCompat.Builder {
    val mins = remainingSeconds / 60
    val secs = remainingSeconds % 60
    val timeText = String.format("%d:%02d", mins, secs)
    val stepLabel = getStepLabel(stepType)
    val text = getString(R.string.notification_session_step_time, stepLabel, timeText)

    val pendingIntent = PendingIntent.getActivity(
      this,
      0,
      packageManager.getLaunchIntentForPackage(packageName),
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    return NotificationCompat.Builder(this, CHANNEL_ID)
      .setContentTitle(title)
      .setContentText(text)
      .setSmallIcon(R.mipmap.ic_launcher)
      .setContentIntent(pendingIntent)
      .setOngoing(true)
      .setPriority(NotificationCompat.PRIORITY_DEFAULT)
      .setOnlyAlertOnce(true)
  }

  override fun onDestroy() {
    tickRunnable?.let { handler.removeCallbacks(it) }
    tickRunnable = null
    ongoingActivity = null
    currentState = null
    super.onDestroy()
  }

  override fun onBind(intent: Intent?): IBinder? = null

  companion object {
    private const val CHANNEL_ID = "zazen_session"
    const val NOTIFICATION_ID = 1
    const val EXTRA_TITLE = "title"
    const val EXTRA_TEXT = "text"
    const val EXTRA_PRESET_JSON = "preset_json"

    @Volatile
    var currentState: SessionState? = null
      private set
  }
}

data class StepInfo(val type: String, val durationSeconds: Int)

data class SessionState(
  val presetJson: String,
  val steps: List<StepInfo>,
  val stepIndex: Int = 0,
  val remainingSeconds: Int
)
