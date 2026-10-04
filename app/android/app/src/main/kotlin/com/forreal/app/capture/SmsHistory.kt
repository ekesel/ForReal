package com.forreal.app.capture

import android.content.Context
import android.provider.Telephony

/**
 * History import: bank messages already in the inbox.
 *
 * Works in two passes so that nothing but bank messages is read: the first pass
 * looks only at sender and date, the second fetches bodies for the matching ids.
 */
object SmsHistory {
    fun page(context: Context, sinceMillis: Long, page: Int, pageSize: Int): List<Map<String, Any>> {
        val allowed = CaptureStore.get(context).allowedSenders
        if (allowed.isEmpty()) return emptyList()
        val resolver = context.contentResolver
        val uri = Telephony.Sms.Inbox.CONTENT_URI

        // Let the SMS provider narrow the scan to senders containing a bank code; the exact
        // match is still decided by SenderFilter below. Codes are plain letters and digits.
        val codes = allowed.filter { it.matches(Regex("[A-Z0-9]+")) }
        val senderClause = if (codes.size == allowed.size) {
            codes.joinToString(" OR ", prefix = " AND (", postfix = ")") { "${Telephony.Sms.ADDRESS} LIKE ?" }
        } else {
            ""
        }
        val senderArgs = if (senderClause.isEmpty()) emptyList() else codes.map { "%$it%" }

        val ids = ArrayList<Long>()
        resolver.query(
            uri,
            arrayOf(Telephony.Sms._ID, Telephony.Sms.ADDRESS),
            "${Telephony.Sms.DATE} >= ?$senderClause",
            (listOf(sinceMillis.toString()) + senderArgs).toTypedArray(),
            "${Telephony.Sms.DATE} ASC, ${Telephony.Sms._ID} ASC",
        )?.use { c ->
            while (c.moveToNext()) {
                if (SenderFilter.matchingCode(c.getString(1), allowed) != null) ids.add(c.getLong(0))
            }
        }

        val from = page * pageSize
        if (from >= ids.size) return emptyList()
        val wanted = ids.subList(from, minOf(from + pageSize, ids.size))

        val out = ArrayList<Map<String, Any>>()
        resolver.query(
            uri,
            arrayOf(
                Telephony.Sms._ID, Telephony.Sms.ADDRESS, Telephony.Sms.DATE,
                Telephony.Sms.DATE_SENT, Telephony.Sms.BODY,
            ),
            "${Telephony.Sms._ID} IN (${wanted.joinToString(",")})",
            null,
            "${Telephony.Sms.DATE} ASC, ${Telephony.Sms._ID} ASC",
        )?.use { c ->
            while (c.moveToNext()) {
                val sender = c.getString(1) ?: continue
                if (SenderFilter.matchingCode(sender, allowed) == null) continue
                val received = c.getLong(2)
                val sent = c.getLong(3)
                out.add(
                    mapOf(
                        "id" to -1L,
                        "sender" to sender,
                        // The live receiver sees the service-centre timestamp, which the inbox
                        // keeps as date_sent. Using it here gives a re-imported message the same
                        // identity as when it was captured live.
                        "receivedAt" to (if (sent > 0) sent else received),
                        "body" to (c.getString(4) ?: ""),
                    )
                )
            }
        }
        return out
    }
}
