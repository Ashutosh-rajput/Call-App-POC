package com.example.call_test

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val METHOD_CHANNEL = "com.example.call_test/telecom"
        private const val EVENT_CHANNEL = "com.example.call_test/events"
        private const val PERMISSIONS_REQUEST_CODE = 1001
        private const val ROLE_REQUEST_CODE = 1002
    }

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        CallStreamingServiceControl.initLogFile(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler(this)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(this)

        CallStreamingServiceControl.setEventListener(object : CallStreamingServiceControl.EventListener {
            override fun onEvent(eventType: String, data: Map<String, Any?>) {
                runOnUiThread {
                    eventSink?.success(mapOf(
                        "type" to eventType,
                        "data" to data
                    ))
                }
            }

            override fun onLog(logEntry: Map<String, String>) {
                runOnUiThread {
                    eventSink?.success(mapOf(
                        "type" to "LOG_ENTRY",
                        "log" to logEntry
                    ))
                }
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getSystemStatus" -> {
                result.success(getSystemStatusMap())
            }
            "requestRuntimePermissions" -> {
                requestRuntimePermissions(result)
            }
            "requestRole" -> {
                requestRole(result)
            }
            "registerPhoneAccount" -> {
                val success = TelecomHelper.registerPhoneAccount(this)
                result.success(mapOf("success" to success))
            }
            "unregisterPhoneAccount" -> {
                val success = TelecomHelper.unregisterPhoneAccount(this)
                result.success(mapOf("success" to success))
            }
            "createTestCall" -> {
                val callerName = call.argument<String>("callerName") ?: "Test Caller"
                val phoneNumber = call.argument<String>("phoneNumber") ?: "tel:5550199"
                val direction = call.argument<Int>("direction") ?: 1

                TelecomHelper.createTestCall(this, callerName, phoneNumber, direction) { success, msg ->
                    runOnUiThread {
                        result.success(mapOf(
                            "success" to success,
                            "message" to msg
                        ))
                    }
                }
            }
            "startCallStreaming" -> {
                TelecomHelper.startCallStreaming { success, msg ->
                    runOnUiThread {
                        result.success(mapOf(
                            "success" to success,
                            "message" to msg
                        ))
                    }
                }
            }
            "stopCallStreaming" -> {
                TelecomHelper.stopCallStreaming { success, msg ->
                    runOnUiThread {
                        result.success(mapOf(
                            "success" to success,
                            "message" to msg
                        ))
                    }
                }
            }
            "disconnectActiveCall" -> {
                TelecomHelper.disconnectActiveCall { success, msg ->
                    runOnUiThread {
                        result.success(mapOf(
                            "success" to success,
                            "message" to msg
                        ))
                    }
                }
            }
            "runAudioDiagnostics" -> {
                Thread {
                    val report = AudioProbeManager.runDiagnostics(this)
                    runOnUiThread {
                        result.success(report)
                    }
                }.start()
            }
            "startLiveAudioCapture" -> {
                val sourceId = call.argument<Int>("sourceId") ?: 7 // Default VOICE_COMMUNICATION
                val success = AudioProbeManager.startLiveAudioCapture(this, sourceId) { levelData ->
                    runOnUiThread {
                        eventSink?.success(mapOf(
                            "type" to "LIVE_AUDIO_LEVEL",
                            "data" to levelData
                        ))
                    }
                }
                result.success(mapOf("success" to success))
            }
            "stopLiveAudioCapture" -> {
                AudioProbeManager.stopLiveAudioCapture()
                result.success(mapOf("success" to true))
            }
            "startNetworkTransportBenchmark" -> {
                val host = call.argument<String>("host") ?: "127.0.0.1"
                val port = call.argument<Int>("port") ?: 19876
                val duration = call.argument<Int>("durationSeconds") ?: 8

                NetworkTransportProbe.startTransportBenchmark(
                    targetHost = host,
                    targetPort = port,
                    durationSeconds = duration,
                    onProgress = { stats ->
                        runOnUiThread {
                            eventSink?.success(mapOf(
                                "type" to "TRANSPORT_PROGRESS",
                                "stats" to mapOf(
                                    "sent" to stats.packetsSent,
                                    "recv" to stats.packetsReceived,
                                    "loss" to stats.packetLossPercent,
                                    "avgLatency" to stats.avgLatencyMs,
                                    "jitter" to stats.jitterMs,
                                    "bitrate" to stats.bitrateKbps,
                                    "status" to stats.status
                                )
                            ))
                        }
                    },
                    onComplete = { finalStats ->
                        runOnUiThread {
                            eventSink?.success(mapOf(
                                "type" to "TRANSPORT_COMPLETE",
                                "stats" to mapOf(
                                    "sent" to finalStats.packetsSent,
                                    "recv" to finalStats.packetsReceived,
                                    "loss" to finalStats.packetLossPercent,
                                    "avgLatency" to finalStats.avgLatencyMs,
                                    "jitter" to finalStats.jitterMs,
                                    "bitrate" to finalStats.bitrateKbps,
                                    "status" to finalStats.status
                                )
                            ))
                        }
                    }
                )
                result.success(mapOf("started" to true))
            }
            "stopNetworkTransportBenchmark" -> {
                NetworkTransportProbe.stopTransportBenchmark()
                result.success(mapOf("stopped" to true))
            }
            "getLogs" -> {
                result.success(CallStreamingServiceControl.getLogs())
            }
            "clearLogs" -> {
                CallStreamingServiceControl.clearLogs()
                result.success(mapOf("cleared" to true))
            }
            "getLogFilePath" -> {
                result.success(mapOf("path" to CallStreamingServiceControl.getLogFilePath()))
            }
            "exportLogsToFile" -> {
                val path = CallStreamingServiceControl.exportLogsToFile()
                result.success(mapOf("success" to true, "path" to path))
            }
            else -> result.notImplemented()
        }
    }

    private fun getSystemStatusMap(): Map<String, Any?> {
        val permissions = mapOf(
            "RECORD_AUDIO" to (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED),
            "CALL_AUDIO_INTERCEPTION" to (ContextCompat.checkSelfPermission(this, RoleHelper.PERM_CALL_AUDIO_INTERCEPTION) == PackageManager.PERMISSION_GRANTED),
            "READ_PHONE_STATE" to (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED),
            "MANAGE_OWN_CALLS" to (ContextCompat.checkSelfPermission(this, "android.permission.MANAGE_OWN_CALLS") == PackageManager.PERMISSION_GRANTED)
        )

        val adbCommands = mapOf(
            "addRole" to RoleHelper.getAdbAddRoleCommand(packageName),
            "removeRole" to RoleHelper.getAdbRemoveRoleCommand(packageName),
            "grantPermissions" to RoleHelper.getAdbGrantPermissionsCommand(packageName)
        )

        return mapOf(
            "sdkInt" to Build.VERSION.SDK_INT,
            "release" to Build.VERSION.RELEASE,
            "deviceModel" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "isApi34Plus" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE),
            "roleAvailable" to RoleHelper.isRoleAvailable(this),
            "roleHeld" to RoleHelper.isRoleHeld(this),
            "isPhoneAccountRegistered" to TelecomHelper.isPhoneAccountRegistered(this),
            "isPhoneAccountEnabled" to TelecomHelper.isPhoneAccountEnabled(this),
            "isServiceBound" to CallStreamingServiceControl.isServiceBound,
            "streamingState" to CallStreamingServiceControl.currentStreamingState,
            "hasActiveStreamingCall" to (CallStreamingServiceControl.activeStreamingCall != null),
            "hasActiveTelecomCall" to (TelecomHelper.activeCallControl != null),
            "activeCallId" to TelecomHelper.activeCallId,
            "permissions" to permissions,
            "adbCommands" to adbCommands
        )
    }

    private fun requestRuntimePermissions(result: MethodChannel.Result) {
        val perms = arrayOf(
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.READ_PHONE_STATE
        )
        val missing = perms.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(mapOf("allGranted" to true))
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(this, missing.toTypedArray(), PERMISSIONS_REQUEST_CODE)
    }

    private fun requestRole(result: MethodChannel.Result) {
        val intent = RoleHelper.createRequestRoleIntent(this)
        if (intent != null) {
            try {
                startActivityForResult(intent, ROLE_REQUEST_CODE)
                result.success(mapOf("requested" to true))
            } catch (e: Exception) {
                result.success(mapOf("requested" to false, "error" to e.message))
            }
        } else {
            result.success(mapOf(
                "requested" to false,
                "error" to "RoleManager intent not available for SYSTEM_CALL_STREAMING (use ADB command)"
            ))
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSIONS_REQUEST_CODE) {
            pendingPermissionResult?.success(mapOf(
                "completed" to true,
                "status" to getSystemStatusMap()
            ))
            pendingPermissionResult = null
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onDestroy() {
        super.onDestroy()
        AudioProbeManager.stopLiveAudioCapture()
        NetworkTransportProbe.stopTransportBenchmark()
        CallStreamingServiceControl.setEventListener(null)
    }
}
