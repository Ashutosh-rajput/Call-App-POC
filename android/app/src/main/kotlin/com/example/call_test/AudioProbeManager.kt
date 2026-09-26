package com.example.call_test

import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Build
import androidx.core.content.ContextCompat
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.log10
import kotlin.math.sqrt

object AudioProbeManager {
    private const val TAG = "AudioProbeManager"

    private var activeMonitoringThread: Thread? = null
    private val isMonitoring = AtomicBoolean(false)

    fun runDiagnostics(context: Context): Map<String, Any> {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val result = mutableMapOf<String, Any>()

        // 1. Permissions status
        val permissions = mapOf(
            "CALL_AUDIO_INTERCEPTION" to hasPermission(context, "android.permission.CALL_AUDIO_INTERCEPTION"),
            "RECORD_AUDIO" to hasPermission(context, android.Manifest.permission.RECORD_AUDIO),
            "MODIFY_AUDIO_ROUTING" to hasPermission(context, "android.permission.MODIFY_AUDIO_ROUTING"),
            "CAPTURE_AUDIO_OUTPUT" to hasPermission(context, "android.permission.CAPTURE_AUDIO_OUTPUT"),
            "READ_PHONE_STATE" to hasPermission(context, android.Manifest.permission.READ_PHONE_STATE),
            "MANAGE_OWN_CALLS" to hasPermission(context, "android.permission.MANAGE_OWN_CALLS")
        )
        result["permissions"] = permissions

        if (audioManager == null) {
            result["audioManagerAvailable"] = false
            return result
        }

        // 2. AudioManager Mode & Capabilities
        val modeStr = when (audioManager.mode) {
            AudioManager.MODE_NORMAL -> "MODE_NORMAL (0)"
            AudioManager.MODE_RINGTONE -> "MODE_RINGTONE (1)"
            AudioManager.MODE_IN_CALL -> "MODE_IN_CALL (2)"
            AudioManager.MODE_IN_COMMUNICATION -> "MODE_IN_COMMUNICATION (3)"
            else -> "MODE_UNKNOWN (${audioManager.mode})"
        }

        val managerInfo = mutableMapOf<String, Any>(
            "mode" to modeStr,
            "isMicrophoneMute" to audioManager.isMicrophoneMute,
            "isSpeakerphoneOn" to audioManager.isSpeakerphoneOn,
            "isMusicActive" to audioManager.isMusicActive
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            managerInfo["isCallScreeningModeSupported"] = audioManager.isCallScreeningModeSupported
        }
        result["audioManager"] = managerInfo

        // 3. Audio Devices (Inputs & Outputs)
        val devicesList = mutableListOf<Map<String, Any>>()
        try {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_ALL)
            for (device in devices) {
                val devInfo = mapOf(
                    "id" to device.id,
                    "productName" to device.productName.toString(),
                    "isSource" to device.isSource,
                    "isSink" to device.isSink,
                    "type" to getDeviceTypeName(device.type),
                    "sampleRates" to device.sampleRates.toList(),
                    "channelCounts" to device.channelCounts.toList()
                )
                devicesList.add(devInfo)
            }
        } catch (e: Exception) {
            CallStreamingServiceControl.log(TAG, "Error enumerating audio devices: ${e.message}", "WARN")
        }
        result["audioDevices"] = devicesList

        // 4. Test Audio Sources (AudioRecord Probe)
        val sourcesToTest = listOf(
            Triple("MIC", MediaRecorder.AudioSource.MIC, "Standard device microphone"),
            Triple("VOICE_UPLINK", MediaRecorder.AudioSource.VOICE_UPLINK, "Transmit (Tx) audio from phone to remote"),
            Triple("VOICE_DOWNLINK", MediaRecorder.AudioSource.VOICE_DOWNLINK, "Receive (Rx) audio from remote PSTN/cellular"),
            Triple("VOICE_CALL", MediaRecorder.AudioSource.VOICE_CALL, "Both Tx and Rx cellular/GSM call audio"),
            Triple("VOICE_COMMUNICATION", MediaRecorder.AudioSource.VOICE_COMMUNICATION, "VoIP / communication audio source"),
            Triple("UNPROCESSED", MediaRecorder.AudioSource.UNPROCESSED, "Raw acoustic input with no DSP")
        )

        val sourcesResult = mutableListOf<Map<String, Any>>()
        for ((name, sourceId, desc) in sourcesToTest) {
            val probeResult = probeAudioSource(context, sourceId, name)
            sourcesResult.add(mapOf(
                "name" to name,
                "sourceId" to sourceId,
                "description" to desc,
                "status" to probeResult["status"] as Any,
                "message" to probeResult["message"] as Any,
                "minBufferSize" to probeResult["minBufferSize"] as Any,
                "rmsDb" to (probeResult["rmsDb"] ?: 0.0)
            ))
        }
        result["sourcesProbe"] = sourcesResult

        CallStreamingServiceControl.log(TAG, "Audio diagnostics completed. Found ${devicesList.size} devices and probed ${sourcesResult.size} sources.")
        return result
    }

    private fun probeAudioSource(context: Context, sourceId: Int, sourceName: String): Map<String, Any> {
        val sampleRate = 16000
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT

        val minBuf = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
        if (minBuf <= 0) {
            return mapOf(
                "status" to "UNSUPPORTED_FORMAT",
                "message" to "AudioRecord minBufferSize returned $minBuf",
                "minBufferSize" to minBuf
            )
        }

        var record: AudioRecord? = null
        try {
            if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                return mapOf(
                    "status" to "PERMISSION_MISSING",
                    "message" to "RECORD_AUDIO runtime permission not granted",
                    "minBufferSize" to minBuf
                )
            }

            record = AudioRecord(sourceId, sampleRate, channelConfig, audioFormat, minBuf * 2)
            if (record.state != AudioRecord.STATE_INITIALIZED) {
                return mapOf(
                    "status" to "INIT_FAILED",
                    "message" to "AudioRecord state was STATE_UNINITIALIZED (likely restricted by OS/OEM)",
                    "minBufferSize" to minBuf
                )
            }

            record.startRecording()
            val shortBuffer = ShortArray(1600) // 100ms
            val readCount = record.read(shortBuffer, 0, shortBuffer.size)

            if (readCount > 0) {
                var sumSquare = 0.0
                var maxAbs = 0
                for (i in 0 until readCount) {
                    val sample = shortBuffer[i].toInt()
                    sumSquare += (sample * sample)
                    val abs = kotlin.math.abs(sample)
                    if (abs > maxAbs) maxAbs = abs
                }
                val rms = sqrt(sumSquare / readCount)
                val db = if (rms > 0) 20 * log10(rms / 32768.0) else -100.0

                return mapOf(
                    "status" to "SUCCESS",
                    "message" to "Recorded $readCount samples (Max Amp: $maxAbs, RMS: ${String.format("%.1f", db)} dB)",
                    "minBufferSize" to minBuf,
                    "rmsDb" to db
                )
            } else {
                return mapOf(
                    "status" to "READ_ERROR",
                    "message" to "AudioRecord.read returned error code: $readCount",
                    "minBufferSize" to minBuf
                )
            }
        } catch (se: SecurityException) {
            return mapOf(
                "status" to "SECURITY_EXCEPTION",
                "message" to (se.message ?: "SecurityException: Requires privileged permission (e.g. CAPTURE_AUDIO_OUTPUT or role)"),
                "minBufferSize" to minBuf
            )
        } catch (e: Exception) {
            return mapOf(
                "status" to "EXCEPTION",
                "message" to "${e.javaClass.simpleName}: ${e.message}",
                "minBufferSize" to minBuf
            )
        } finally {
            try {
                record?.stop()
                record?.release()
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    fun startLiveAudioCapture(
        context: Context,
        sourceId: Int,
        onLevelUpdate: (Map<String, Any>) -> Unit
    ): Boolean {
        stopLiveAudioCapture()

        if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            CallStreamingServiceControl.log(TAG, "Cannot start live audio capture: RECORD_AUDIO permission missing", "ERROR")
            return false
        }

        isMonitoring.set(true)
        val thread = Thread({
            val sampleRate = 16000
            val channelConfig = AudioFormat.CHANNEL_IN_MONO
            val audioFormat = AudioFormat.ENCODING_PCM_16BIT
            val minBuf = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
            val bufferSize = minBuf.coerceAtLeast(3200)

            var record: AudioRecord? = null
            try {
                record = AudioRecord(sourceId, sampleRate, channelConfig, audioFormat, bufferSize)
                if (record.state != AudioRecord.STATE_INITIALIZED) {
                    CallStreamingServiceControl.log(TAG, "AudioRecord init failed for source $sourceId", "ERROR")
                    return@Thread
                }
                record.startRecording()
                CallStreamingServiceControl.log(TAG, "Live AudioRecord started for source $sourceId")

                val shortBuffer = ShortArray(640) // 40ms frames at 16kHz
                var frameIndex = 0L

                while (isMonitoring.get()) {
                    val read = record.read(shortBuffer, 0, shortBuffer.size)
                    if (read > 0) {
                        var sumSquare = 0.0
                        var maxAbs = 0
                        for (i in 0 until read) {
                            val sample = shortBuffer[i].toInt()
                            sumSquare += (sample * sample)
                            val abs = kotlin.math.abs(sample)
                            if (abs > maxAbs) maxAbs = abs
                        }
                        val rms = sqrt(sumSquare / read)
                        val db = if (rms > 0) 20 * log10(rms / 32768.0) else -100.0

                        frameIndex++
                        if (frameIndex % 5L == 0L) { // Post every ~200ms
                            onLevelUpdate(mapOf(
                                "frame" to frameIndex,
                                "samples" to read,
                                "maxAmp" to maxAbs,
                                "rmsDb" to db
                            ))
                        }
                    } else {
                        Thread.sleep(20)
                    }
                }
            } catch (e: Exception) {
                CallStreamingServiceControl.log(TAG, "Exception in live audio capture: ${e.message}", "ERROR")
            } finally {
                try {
                    record?.stop()
                    record?.release()
                } catch (e: Exception) {
                    // Ignore
                }
                CallStreamingServiceControl.log(TAG, "Live AudioRecord stopped")
            }
        }, "AudioCaptureWorker")

        activeMonitoringThread = thread
        thread.start()
        return true
    }

    fun stopLiveAudioCapture() {
        isMonitoring.set(false)
        activeMonitoringThread?.interrupt()
        activeMonitoringThread = null
    }

    private fun hasPermission(context: Context, permission: String): Boolean {
        return ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun getDeviceTypeName(type: Int): String {
        return when (type) {
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "TYPE_BUILTIN_EARPIECE (1)"
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "TYPE_BUILTIN_SPEAKER (2)"
            AudioDeviceInfo.TYPE_WIRED_HEADSET -> "TYPE_WIRED_HEADSET (3)"
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "TYPE_WIRED_HEADPHONES (4)"
            AudioDeviceInfo.TYPE_TELEPHONY -> "TYPE_TELEPHONY (18) [GSM/PSTN Path]"
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "TYPE_BLUETOOTH_SCO (7)"
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "TYPE_BLUETOOTH_A2DP (8)"
            AudioDeviceInfo.TYPE_USB_DEVICE -> "TYPE_USB_DEVICE (11)"
            AudioDeviceInfo.TYPE_USB_HEADSET -> "TYPE_USB_HEADSET (22)"
            AudioDeviceInfo.TYPE_BUILTIN_MIC -> "TYPE_BUILTIN_MIC (15)"
            else -> "TYPE_ID_$type"
        }
    }
}
