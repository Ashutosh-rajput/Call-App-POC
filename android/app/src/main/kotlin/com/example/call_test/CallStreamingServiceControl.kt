package com.example.call_test

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

object CallStreamingServiceControl {
    private const val TAG = "CallStreamingControl"

    interface EventListener {
        fun onEvent(eventType: String, data: Map<String, Any?>)
        fun onLog(logEntry: Map<String, String>)
    }

    private var eventListener: EventListener? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val recentLogs = mutableListOf<Map<String, String>>()
    private val maxLogs = 500

    // Streaming state
    var isServiceBound: Boolean = false
        private set
    var activeStreamingCall: Any? = null // Reference to StreamingCall on API 34+
        private set
    var currentStreamingState: String = "IDLE"
        private set
    var lastCallExtras: Bundle? = null
        private set
    var streamingStartTimeMs: Long = 0
        private set

    // CTS-style CountDownLatch for testing/automation
    private var streamingStartedLatch: CountDownLatch? = null

    fun setEventListener(listener: EventListener?) {
        eventListener = listener
        // Flush recent logs if needed
    }

    fun prepareStreamingLatch(): CountDownLatch {
        val latch = CountDownLatch(1)
        streamingStartedLatch = latch
        return latch
    }

    fun awaitStreamingStarted(timeoutSec: Long = 10): Boolean {
        val latch = streamingStartedLatch ?: return false
        return try {
            latch.await(timeoutSec, TimeUnit.SECONDS)
        } catch (e: InterruptedException) {
            false
        }
    }

    private var logFile: java.io.File? = null
    private var logWriter: java.io.PrintWriter? = null

    fun initLogFile(context: android.content.Context) {
        try {
            val baseDir = context.getExternalFilesDir(null) ?: context.filesDir
            val logsDir = java.io.File(baseDir, "logs")
            if (!logsDir.exists()) logsDir.mkdirs()
            val file = java.io.File(logsDir, "call_streaming_debug.log")
            logFile = file
            logWriter = java.io.PrintWriter(java.io.FileWriter(file, true))
            log(TAG, "Log file initialized at: ${file.absolutePath}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to init log file: ${e.message}")
        }
    }

    fun getLogFilePath(): String {
        return logFile?.absolutePath ?: "Unavailable"
    }

    fun exportLogsToFile(): String {
        val file = logFile ?: return "Log file not initialized"
        return try {
            synchronized(recentLogs) {
                logWriter?.flush()
            }
            file.absolutePath
        } catch (e: Exception) {
            "Export error: ${e.message}"
        }
    }

    fun log(tag: String, message: String, level: String = "INFO") {
        val timeStr = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).format(Date())
        val entry = mapOf(
            "time" to timeStr,
            "tag" to tag,
            "message" to message,
            "level" to level
        )
        synchronized(recentLogs) {
            recentLogs.add(entry)
            if (recentLogs.size > maxLogs) {
                recentLogs.removeAt(0)
            }
            try {
                logWriter?.println("[$timeStr] [$level] [$tag] $message")
                logWriter?.flush()
            } catch (e: Exception) {
                // Ignore write error
            }
        }
        when (level) {
            "ERROR" -> Log.e(tag, message)
            "WARN" -> Log.w(tag, message)
            else -> Log.i(tag, message)
        }
        mainHandler.post {
            eventListener?.onLog(entry)
        }
    }

    fun getLogs(): List<Map<String, String>> {
        synchronized(recentLogs) {
            return recentLogs.toList()
        }
    }

    fun clearLogs() {
        synchronized(recentLogs) {
            recentLogs.clear()
            try {
                logWriter?.close()
                logFile?.writeText("")
                if (logFile != null) {
                    logWriter = java.io.PrintWriter(java.io.FileWriter(logFile, true))
                }
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    fun onServiceConnected() {
        isServiceBound = true
        log(TAG, "CallStreamingService bound by Android Telecom")
        postEvent("SERVICE_BOUND", mapOf("bound" to true))
    }

    fun onServiceDisconnected() {
        isServiceBound = false
        activeStreamingCall = null
        currentStreamingState = "IDLE"
        log(TAG, "CallStreamingService unbound / disconnected")
        postEvent("SERVICE_UNBOUND", mapOf("bound" to false))
    }

    fun onStreamingStarted(streamingCall: Any) {
        activeStreamingCall = streamingCall
        currentStreamingState = "STREAMING"
        streamingStartTimeMs = System.currentTimeMillis()

        var extrasMap = mutableMapOf<String, Any?>()
        try {
            val getExtrasMethod = streamingCall.javaClass.getMethod("getExtras")
            val extras = getExtrasMethod.invoke(streamingCall) as? Bundle
            lastCallExtras = extras
            if (extras != null) {
                for (key in extras.keySet()) {
                    extrasMap[key] = extras.get(key)?.toString()
                }
            }
        } catch (e: Exception) {
            log(TAG, "Error extracting StreamingCall extras: ${e.message}", "WARN")
        }

        log(TAG, "onCallStreamingStarted: call received! Extras=$extrasMap")
        streamingStartedLatch?.countDown()

        postEvent("STREAMING_STARTED", mapOf(
            "state" to currentStreamingState,
            "extras" to extrasMap,
            "timestamp" to streamingStartTimeMs
        ))
    }

    fun onStreamingStopped() {
        val durationMs = if (streamingStartTimeMs > 0) System.currentTimeMillis() - streamingStartTimeMs else 0
        activeStreamingCall = null
        currentStreamingState = "STOPPED"
        streamingStartTimeMs = 0
        log(TAG, "onCallStreamingStopped: Streaming session closed (Duration: ${durationMs}ms)")
        postEvent("STREAMING_STOPPED", mapOf(
            "state" to currentStreamingState,
            "durationMs" to durationMs
        ))
    }

    fun onStreamingStateChanged(state: Int) {
        val stateName = when (state) {
            1 -> "STATE_STREAMING"
            2 -> "STATE_HOLDING"
            else -> "STATE_UNKNOWN($state)"
        }
        currentStreamingState = stateName
        log(TAG, "onCallStreamingStateChanged: new state = $stateName ($state)")
        postEvent("STREAMING_STATE_CHANGED", mapOf(
            "state" to stateName,
            "rawState" to state
        ))
    }

    fun changeStreamingCallState(stateInt: Int): Boolean {
        val call = activeStreamingCall ?: return false
        return try {
            val method = call.javaClass.getMethod("setStreamingCallState", Int::class.javaPrimitiveType)
            method.invoke(call, stateInt)
            log(TAG, "Successfully changed streaming call state to $stateInt")
            true
        } catch (e: Exception) {
            log(TAG, "Failed to change streaming call state: ${e.message}", "ERROR")
            false
        }
    }

    private fun postEvent(type: String, data: Map<String, Any?>) {
        mainHandler.post {
            eventListener?.onEvent(type, data)
        }
    }
}
