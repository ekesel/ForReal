package com.forreal.app.capture

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.work.ListenableWorker
import androidx.work.WorkerParameters
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.view.FlutterCallbackInformation

/**
 * Runs the Dart background entry point in a headless FlutterEngine, so queued bank
 * messages are parsed, uploaded and turned into a notification while the app is in
 * the background or killed. Same pattern as the firebase_messaging background handler.
 *
 * The Dart side ends the run by calling `backgroundDone` on the capture channel.
 */
class CaptureWorker(context: Context, params: WorkerParameters) : ListenableWorker(context, params) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var completer: CallbackToFutureAdapter.Completer<Result>? = null
    private var finished = false

    override fun startWork(): ListenableFuture<Result> =
        CallbackToFutureAdapter.getFuture { c ->
            completer = c
            mainHandler.post { startEngine() }
            mainHandler.postDelayed({ finish(Result.retry()) }, TIMEOUT_MS)
            "ForRealCaptureWorker"
        }

    private fun startEngine() {
        val store = CaptureStore.get(applicationContext)
        val handle = store.callbackHandle
        if (handle == 0L || !store.captureEnabled) {
            finish(Result.success())
            return
        }
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            val callback = FlutterCallbackInformation.lookupCallbackInformation(handle)
            if (callback == null) {
                finish(Result.success())
                return
            }
            // Plugins register themselves on a new engine; the capture channel is app code.
            val flutterEngine = FlutterEngine(applicationContext)
            engine = flutterEngine
            CaptureChannel(
                context = applicationContext,
                messenger = flutterEngine.dartExecutor.binaryMessenger,
                activity = { null },
                onBackgroundDone = { retry ->
                    if (retry) CaptureDispatcher.enqueueSyncWhenOnline(applicationContext)
                    finish(Result.success())
                },
                backgroundReason = inputData.getString(KEY_REASON) ?: "sms",
            )
            flutterEngine.dartExecutor.executeDartCallback(
                DartExecutor.DartCallback(applicationContext.assets, loader.findAppBundlePath(), callback)
            )
        } catch (e: Exception) {
            Log.e(TAG, "Background engine failed to start: ${e.javaClass.simpleName}")
            finish(Result.retry())
        }
    }

    private fun finish(result: Result) {
        mainHandler.post {
            if (finished) return@post
            finished = true
            mainHandler.removeCallbacksAndMessages(null)
            engine?.destroy()
            engine = null
            completer?.set(result)
        }
    }

    override fun onStopped() {
        mainHandler.post {
            if (finished) return@post
            finished = true
            mainHandler.removeCallbacksAndMessages(null)
            engine?.destroy()
            engine = null
            completer?.set(Result.failure())
        }
    }

    companion object {
        const val KEY_REASON = "reason"
        private const val TAG = "ForRealCapture"
        private const val TIMEOUT_MS = 4 * 60 * 1000L
    }
}
