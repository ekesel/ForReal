package com.forreal.app.capture

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Wakes the Dart side after messages were queued.
 *
 * App on screen: the running Flutter engine is told through the event channel.
 * Otherwise (background or killed): WorkManager starts [CaptureWorker], which runs
 * the Dart background entry point in a headless FlutterEngine. No foreground
 * service is involved.
 */
object CaptureDispatcher {
    private const val WORK_DRAIN = "forreal_capture_drain"
    private const val WORK_SYNC = "forreal_capture_sync"
    private const val WORK_PERIODIC = "forreal_capture_periodic"

    private val mainHandler = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()

    /** True between MainActivity.onStart and onStop. */
    @Volatile
    var appVisible: Boolean = false

    /** Set while the main engine's Dart code listens on the event channel. */
    @Volatile
    var liveSink: EventChannel.EventSink? = null

    fun onMessagesQueued(context: Context) {
        val sink = liveSink
        if (appVisible && sink != null) {
            // Reading and decrypting the queue is disk and crypto work: keep it off the main
            // thread. Only the hand-over to Flutter has to happen there.
            io.execute {
                val messages = try {
                    CaptureStore.get(context).peek(50)
                } catch (e: Exception) {
                    emptyList()
                }
                mainHandler.post {
                    // The app may have left the screen meanwhile; the worker then takes over.
                    val current = liveSink
                    if (appVisible && current != null) {
                        for (m in messages) current.success(m.toMap())
                    } else {
                        enqueueDrain(context)
                    }
                }
            }
        } else {
            enqueueDrain(context)
        }
    }

    /** Process the queue now, without waiting for the network. */
    fun enqueueDrain(context: Context) {
        val request = OneTimeWorkRequestBuilder<CaptureWorker>()
            .setInputData(Data.Builder().putString(CaptureWorker.KEY_REASON, "sms").build())
        // Expedited work runs as a foreground service below Android 12, which this app
        // must not use; there the request is an ordinary one.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            request.setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
        }
        WorkManager.getInstance(context)
            .enqueueUniqueWork(WORK_DRAIN, ExistingWorkPolicy.APPEND_OR_REPLACE, request.build())
    }

    /** Upload what is still pending as soon as there is a connection. */
    fun enqueueSyncWhenOnline(context: Context) {
        val request = OneTimeWorkRequestBuilder<CaptureWorker>()
            .setInputData(Data.Builder().putString(CaptureWorker.KEY_REASON, "network").build())
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .setInitialDelay(30, TimeUnit.SECONDS)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(WORK_SYNC, ExistingWorkPolicy.REPLACE, request)
    }

    fun schedulePeriodic(context: Context) {
        val request = PeriodicWorkRequestBuilder<CaptureWorker>(1, TimeUnit.HOURS)
            .setInputData(Data.Builder().putString(CaptureWorker.KEY_REASON, "periodic").build())
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork(WORK_PERIODIC, ExistingPeriodicWorkPolicy.KEEP, request)
    }

    fun cancelAll(context: Context) {
        val wm = WorkManager.getInstance(context)
        wm.cancelUniqueWork(WORK_DRAIN)
        wm.cancelUniqueWork(WORK_SYNC)
        wm.cancelUniqueWork(WORK_PERIODIC)
    }
}

internal fun QueuedMessage.toMap(): Map<String, Any> =
    mapOf("id" to id, "sender" to sender, "receivedAt" to receivedAt, "body" to body)
