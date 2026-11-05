package com.murn.downloader

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Foreground service whose only job is to keep the process (and therefore the queue in [DownloadManager])
 * alive while there is something to download, and to show progress in the notification shade.
 * It stops itself when the queue is empty.
 */
class DownloadService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var job: Job? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "التحميلات", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "murn:download").apply { setReferenceCounted(false) }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ServiceCompat.startForeground(
            this, ID, notification("جاري التحضير...", 0, 0, true),
            if (Build.VERSION.SDK_INT >= 29) ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC else 0,
        )
        runCatching { wakeLock?.acquire(6 * 60 * 60 * 1000L) }

        job?.cancel()
        job = scope.launch {
            DownloadManager.items.collect { list ->
                val active = list.count { it.active }
                val done = list.count { it.status == Status.DONE }
                val failed = list.count { it.status == Status.FAILED }
                if (active == 0) {
                    if (done + failed > 0) notifyFinished(done, failed)
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                    return@collect
                }
                val total = list.count { it.status != Status.CANCELED }
                val running = list.count { it.status == Status.RUNNING }
                val text = "تم $done من $total" + (if (running > 0) " · شغال $running" else "") +
                        (if (failed > 0) " · فشل $failed" else "")
                getSystemService(NotificationManager::class.java)
                    .notify(ID, notification(text, done, total, false))
                delay(1000) // collect() conflates, so this is the notification refresh rate
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        job?.cancel()
        scope.cancel()
        runCatching { if (wakeLock?.isHeld == true) wakeLock?.release() }
        super.onDestroy()
    }

    private fun openApp(): PendingIntent = PendingIntent.getActivity(
        this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun notification(text: String, done: Int, total: Int, indeterminate: Boolean): Notification =
        NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("مرن للتحميل")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openApp())
            .setProgress(total, done, indeterminate || total == 0)
            .build()

    private fun notifyFinished(done: Int, failed: Int) {
        val text = "تم تحميل $done" + (if (failed > 0) " · فشل $failed" else "") + " - المجلد: التنزيلات/Murn"
        val n = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle("خلص التحميل")
            .setContentText(text)
            .setAutoCancel(true)
            .setContentIntent(openApp())
            .build()
        getSystemService(NotificationManager::class.java).notify(ID + 1, n)
    }

    companion object {
        private const val CHANNEL = "downloads"
        private const val ID = 1001

        fun start(ctx: Context) {
            runCatching { ContextCompat.startForegroundService(ctx, Intent(ctx, DownloadService::class.java)) }
        }
    }
}
