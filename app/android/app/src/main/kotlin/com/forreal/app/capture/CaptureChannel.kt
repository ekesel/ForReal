package com.forreal.app.capture

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * The single channel surface between Kotlin and Dart. Dart wraps it in
 * AndroidSmsSource; nothing else in the app talks to it.
 *
 * Attached to the main engine by MainActivity, and to the headless engine by
 * [CaptureWorker] (where [onBackgroundDone] ends the run and there is no activity).
 */
class CaptureChannel(
    private val context: Context,
    messenger: BinaryMessenger,
    private val activity: () -> Activity?,
    private val onBackgroundDone: ((retry: Boolean) -> Unit)? = null,
    private val backgroundReason: String? = null,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val store = CaptureStore.get(context)
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pendingPermission: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, METHODS).setMethodCallHandler(this)
        if (onBackgroundDone == null) EventChannel(messenger, EVENTS).setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setAllowedSenders" -> {
                store.allowedSenders = (call.arguments as? List<*>)?.filterIsInstance<String>()?.toSet() ?: emptySet()
                result.success(null)
            }
            "setCaptureEnabled" -> {
                val enabled = call.arguments as? Boolean ?: false
                store.captureEnabled = enabled
                if (enabled) CaptureDispatcher.schedulePeriodic(context) else CaptureDispatcher.cancelAll(context)
                result.success(null)
            }
            "registerBackgroundCallback" -> {
                store.callbackHandle = (call.arguments as Number).toLong()
                result.success(null)
            }
            "drainQueue" -> background(result) {
                store.peek(call.argument<Int>("limit") ?: 50).map { it.toMap() }
            }
            "acknowledge" -> background(result) {
                store.acknowledge((call.arguments as? List<*>)?.mapNotNull { (it as? Number)?.toLong() } ?: emptyList())
                null
            }
            "clearQueue" -> background(result) {
                store.clearQueue()
                null
            }
            "history" -> {
                if (!hasPermission(Manifest.permission.READ_SMS)) {
                    result.error("permission", "READ_SMS is not granted.", null)
                    return
                }
                val since = (call.argument<Number>("since") ?: 0).toLong()
                val page = call.argument<Int>("page") ?: 0
                val pageSize = call.argument<Int>("pageSize") ?: 100
                background(result) { SmsHistory.page(context, since, page, pageSize) }
            }
            "smsPermissionStatus" -> result.success(smsStatus())
            "requestSmsPermission" -> requestSmsPermission(result)
            "backgroundReason" -> result.success(backgroundReason)
            "backgroundDone" -> {
                result.success(null)
                onBackgroundDone?.invoke(call.argument<Boolean>("retry") ?: false)
            }
            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("capture_error", e.javaClass.simpleName, null) }
            }
        }
    }

    // --- permissions ---------------------------------------------------------

    private fun hasPermission(name: String) =
        ContextCompat.checkSelfPermission(context, name) == PackageManager.PERMISSION_GRANTED

    private fun smsStatus(): String =
        if (SMS_PERMISSIONS.all { hasPermission(it) }) "granted" else "denied"

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (smsStatus() == "granted") {
            result.success("granted")
            return
        }
        val current = activity()
        if (current == null) {
            result.success("denied")
            return
        }
        pendingPermission?.success("denied")
        pendingPermission = result
        ActivityCompat.requestPermissions(current, SMS_PERMISSIONS, REQUEST_CODE)
    }

    /** Called by MainActivity. Returns true when the result belonged to this channel. */
    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pendingPermission ?: return true
        pendingPermission = null
        val current = activity()
        val status = when {
            smsStatus() == "granted" -> "granted"
            // After a refusal Android stops showing the prompt once the rationale flag is off.
            current != null && SMS_PERMISSIONS.none {
                ActivityCompat.shouldShowRequestPermissionRationale(current, it)
            } -> "denied_forever"
            else -> "denied"
        }
        result.success(status)
        return true
    }

    // --- live messages (main engine only) ------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        CaptureDispatcher.liveSink = events
    }

    override fun onCancel(arguments: Any?) {
        CaptureDispatcher.liveSink = null
    }

    fun dispose() {
        if (onBackgroundDone == null) CaptureDispatcher.liveSink = null
        io.shutdown()
    }

    companion object {
        const val METHODS = "forreal/capture"
        const val EVENTS = "forreal/capture/messages"
        const val REQUEST_CODE = 6201
        val SMS_PERMISSIONS = arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS)
    }
}
