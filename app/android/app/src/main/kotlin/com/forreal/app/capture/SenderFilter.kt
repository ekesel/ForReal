package com.forreal.app.capture

/**
 * Decides whether an SMS sender is one of the bank senders named in the downloaded
 * parser templates. This is the only gate between the SMS broadcast and the app:
 * a message whose sender does not match is dropped before its body is read.
 *
 * Indian bulk senders look like "AD-HDFCBK" or "VM-HDFCBK-S": a two-character
 * operator/circle prefix, the registered header, and an optional one-character
 * regulatory suffix. The header must equal an allowed code exactly; a code that
 * merely appears inside a longer header does not match.
 *
 * Pure Kotlin on purpose, so it is unit-tested on the JVM. The Dart side mirrors it
 * in lib/capture/sender_matcher.dart.
 */
object SenderFilter {

    fun normalizeCodes(codes: Collection<String>): Set<String> =
        codes.map { it.trim().uppercase() }.filter { it.isNotEmpty() }.toSet()

    /** The allowed code this sender carries, or null when the message must be dropped. */
    fun matchingCode(sender: String?, allowedCodes: Set<String>): String? {
        if (sender.isNullOrBlank() || allowedCodes.isEmpty()) return null
        val header = header(sender) ?: return null
        if (header in allowedCodes) return header
        // Older handsets show the operator prefix glued on: "ADHDFCBK".
        if (header.length > 2 && header[0].isLetter() && header[1].isLetter()) {
            val withoutPrefix = header.substring(2)
            if (!sender.contains('-') && withoutPrefix in allowedCodes) return withoutPrefix
        }
        return null
    }

    /** The registered header of a sender id, without operator prefix and suffix. */
    private fun header(sender: String): String? {
        var parts = sender.trim().uppercase().split('-').filter { it.isNotEmpty() }
        if (parts.size >= 2 && parts.first().length == 2) parts = parts.drop(1)
        if (parts.size >= 2 && parts.last().length == 1) parts = parts.dropLast(1)
        return parts.singleOrNull()
    }
}
