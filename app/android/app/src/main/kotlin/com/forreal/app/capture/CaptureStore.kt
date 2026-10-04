package com.forreal.app.capture

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** One bank SMS waiting for the Dart side. */
data class QueuedMessage(val id: Long, val sender: String, val receivedAt: Long, val body: String)

/**
 * Native state of the capture module:
 *  - whether capture is switched on (only after the private-analytics consent),
 *  - the allowed bank sender codes (written by Dart from the parser templates),
 *  - the Dart callback handle for background processing,
 *  - the queue of bank messages not yet handed to Dart.
 *
 * The queue survives process death. Message bodies are encrypted with a key held in
 * the Android Keystore, so they are never on disk in the clear.
 */
class CaptureStore private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val prefs = appContext.getSharedPreferences("forreal_capture", Context.MODE_PRIVATE)
    private val db = QueueDb(appContext)

    var captureEnabled: Boolean
        get() = prefs.getBoolean(KEY_ENABLED, false)
        set(value) = prefs.edit().putBoolean(KEY_ENABLED, value).apply()

    var allowedSenders: Set<String>
        get() = prefs.getStringSet(KEY_SENDERS, emptySet())?.toSet() ?: emptySet()
        set(value) = prefs.edit().putStringSet(KEY_SENDERS, SenderFilter.normalizeCodes(value)).apply()

    /** Raw handle of the Dart entry point run by [CaptureWorker]; 0 until Dart registers it. */
    var callbackHandle: Long
        get() = prefs.getLong(KEY_CALLBACK, 0L)
        set(value) = prefs.edit().putLong(KEY_CALLBACK, value).apply()

    @Synchronized
    fun enqueue(sender: String, receivedAt: Long, body: String): Long {
        val sealed = QueueCipher.encrypt(body)
        val values = ContentValues().apply {
            put("sender", sender)
            put("received_at", receivedAt)
            put("iv", sealed.iv)
            put("body", sealed.data)
        }
        return db.writableDatabase.insertOrThrow(TABLE, null, values)
    }

    /** Oldest messages first. They stay queued until [acknowledge] is called. */
    @Synchronized
    fun peek(limit: Int): List<QueuedMessage> {
        val out = ArrayList<QueuedMessage>()
        val undecryptable = ArrayList<Long>()
        db.readableDatabase.query(
            TABLE, arrayOf("id", "sender", "received_at", "iv", "body"),
            null, null, null, null, "id ASC", limit.toString(),
        ).use { c ->
            while (c.moveToNext()) {
                val id = c.getLong(0)
                try {
                    val body = QueueCipher.decrypt(c.getBlob(3), c.getBlob(4))
                    out.add(QueuedMessage(id, c.getString(1), c.getLong(2), body))
                } catch (e: Exception) {
                    // The Keystore key is gone (for example after a backup restore).
                    undecryptable.add(id)
                }
            }
        }
        if (undecryptable.isNotEmpty()) acknowledge(undecryptable)
        return out
    }

    @Synchronized
    fun acknowledge(ids: List<Long>) {
        if (ids.isEmpty()) return
        val w = db.writableDatabase
        w.beginTransaction()
        try {
            for (id in ids) w.delete(TABLE, "id = ?", arrayOf(id.toString()))
            w.setTransactionSuccessful()
        } finally {
            w.endTransaction()
        }
    }

    @Synchronized
    fun size(): Int =
        db.readableDatabase.rawQuery("SELECT COUNT(*) FROM $TABLE", null).use { c ->
            if (c.moveToFirst()) c.getInt(0) else 0
        }

    @Synchronized
    fun clearQueue() {
        db.writableDatabase.delete(TABLE, null, null)
    }

    private class QueueDb(context: Context) : SQLiteOpenHelper(context, "capture_queue.db", null, 1) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL(
                "CREATE TABLE $TABLE (" +
                    "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                    "sender TEXT NOT NULL, " +
                    "received_at INTEGER NOT NULL, " +
                    "iv BLOB NOT NULL, " +
                    "body BLOB NOT NULL)"
            )
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
    }

    companion object {
        private const val TABLE = "queue"
        private const val KEY_ENABLED = "capture_enabled"
        private const val KEY_SENDERS = "allowed_senders"
        private const val KEY_CALLBACK = "callback_handle"

        @Volatile
        private var instance: CaptureStore? = null

        fun get(context: Context): CaptureStore =
            instance ?: synchronized(this) {
                instance ?: CaptureStore(context).also { instance = it }
            }
    }
}

/** AES-256-GCM with a key that never leaves the Android Keystore. */
internal object QueueCipher {
    private const val ALIAS = "forreal_capture_queue"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"

    class Sealed(val iv: ByteArray, val data: ByteArray)

    private fun key(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return generator.generateKey()
    }

    fun encrypt(plain: String): Sealed {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key())
        return Sealed(cipher.iv, cipher.doFinal(plain.toByteArray(Charsets.UTF_8)))
    }

    fun decrypt(iv: ByteArray, data: ByteArray): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, iv))
        return String(cipher.doFinal(data), Charsets.UTF_8)
    }
}
