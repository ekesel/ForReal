package com.forreal.app.capture

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log

/**
 * Receives every incoming SMS broadcast and keeps only bank messages.
 *
 * It does three things and nothing else: filter by sender, queue, wake Dart.
 * There is no parsing here. A message whose sender is not an allowed bank code is
 * dropped without its body being read or stored.
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val store = CaptureStore.get(context)
        if (!store.captureEnabled) return
        val allowed = store.allowedSenders
        if (allowed.isEmpty()) return

        val parts: Array<SmsMessage> = try {
            Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        } catch (e: Exception) {
            return
        }

        // A long SMS arrives as several parts from the same sender: join them in order.
        val bySender = LinkedHashMap<String, MutableList<SmsMessage>>()
        for (part in parts) {
            val sender = part.originatingAddress ?: continue
            if (SenderFilter.matchingCode(sender, allowed) == null) continue // dropped, body untouched
            bySender.getOrPut(sender) { ArrayList() }.add(part)
        }
        if (bySender.isEmpty()) return

        var queued = 0
        for ((sender, list) in bySender) {
            val body = list.joinToString(separator = "") { it.messageBody ?: "" }
            if (body.isEmpty()) continue
            try {
                store.enqueue(sender, list.first().timestampMillis, body)
                queued++
            } catch (e: Exception) {
                // Never log message content.
                Log.e(TAG, "Could not queue a bank message: ${e.javaClass.simpleName}")
            }
        }
        if (queued > 0) CaptureDispatcher.onMessagesQueued(context)
    }

    private companion object {
        const val TAG = "ForRealCapture"
    }
}
