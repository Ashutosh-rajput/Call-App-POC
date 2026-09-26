package com.example.call_test

import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.OutcomeReceiver
import android.telecom.CallAttributes
import android.telecom.CallControl
import android.telecom.CallControlCallback
import android.telecom.CallEndpoint
import android.telecom.CallEventCallback
import android.telecom.CallException
import android.telecom.DisconnectCause
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import androidx.annotation.RequiresApi
import java.util.concurrent.Executors
import java.util.function.Consumer

object TelecomHelper {
    private const val TAG = "TelecomHelper"
    const val ACCOUNT_ID = "cts_call_streaming_account"
    private val executor = Executors.newSingleThreadExecutor()

    var activeCallControl: Any? = null // CallControl on API 34+
        private set
    var activeCallId: String? = null
        private set

    fun getPhoneAccountHandle(context: Context): PhoneAccountHandle {
        val componentName = ComponentName(context, CtsConnectionService::class.java)
        return PhoneAccountHandle(componentName, ACCOUNT_ID)
    }

    fun isPhoneAccountRegistered(context: Context): Boolean {
        val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager ?: return false
        val handle = getPhoneAccountHandle(context)
        return try {
            val account = telecomManager.getPhoneAccount(handle)
            account != null
        } catch (e: Exception) {
            false
        }
    }

    fun isPhoneAccountEnabled(context: Context): Boolean {
        val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager ?: return false
        val handle = getPhoneAccountHandle(context)
        return try {
            val account = telecomManager.getPhoneAccount(handle)
            account?.isEnabled == true
        } catch (e: Exception) {
            false
        }
    }

    fun registerPhoneAccount(context: Context): Boolean {
        val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager ?: return false
        return try {
            val handle = getPhoneAccountHandle(context)
            val builder = PhoneAccount.builder(handle, "CTS Call Streaming Account")
                .setCapabilities(
                    PhoneAccount.CAPABILITY_SELF_MANAGED or
                    PhoneAccount.CAPABILITY_SUPPORTS_VIDEO_CALLING
                )
                .setShortDescription("PoC Call Streaming Account")
                .addSupportedUriScheme(PhoneAccount.SCHEME_TEL)

            telecomManager.registerPhoneAccount(builder.build())
            CallStreamingServiceControl.log(TAG, "PhoneAccount registered: $handle")
            true
        } catch (e: Exception) {
            CallStreamingServiceControl.log(TAG, "Failed to register PhoneAccount: ${e.message}", "ERROR")
            false
        }
    }

    fun unregisterPhoneAccount(context: Context): Boolean {
        val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager ?: return false
        return try {
            val handle = getPhoneAccountHandle(context)
            telecomManager.unregisterPhoneAccount(handle)
            CallStreamingServiceControl.log(TAG, "PhoneAccount unregistered: $handle")
            true
        } catch (e: Exception) {
            CallStreamingServiceControl.log(TAG, "Failed to unregister PhoneAccount: ${e.message}", "ERROR")
            false
        }
    }

    /**
     * Creates a test call using Android 14+ TelecomManager.addCall() API
     */
    fun createTestCall(
        context: Context,
        callerName: String = "Test Caller",
        phoneNumber: String = "tel:5550199",
        direction: Int = CallAttributes.DIRECTION_INCOMING,
        callback: (Boolean, String) -> Unit
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            callback(false, "Android 14+ (API 34) required for Telecom CallControl APIs. Current SDK: ${Build.VERSION.SDK_INT}")
            return
        }

        try {
            createTestCallApi34(context, callerName, phoneNumber, direction, callback)
        } catch (e: Throwable) {
            CallStreamingServiceControl.log(TAG, "Exception creating test call: ${e.message}", "ERROR")
            callback(false, "Error: ${e.message}")
        }
    }

    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun createTestCallApi34(
        context: Context,
        callerName: String,
        phoneNumber: String,
        direction: Int,
        callback: (Boolean, String) -> Unit
    ) {
        val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
        if (telecomManager == null) {
            callback(false, "TelecomManager unavailable")
            return
        }

        val handle = getPhoneAccountHandle(context)
        if (!isPhoneAccountRegistered(context)) {
            registerPhoneAccount(context)
        }

        val addressUri = Uri.parse(phoneNumber)
        val callAttributes = CallAttributes.Builder(handle, direction, callerName, addressUri)
            .setCallType(CallAttributes.AUDIO_CALL)
            .setCallCapabilities(CallAttributes.SUPPORTS_STREAM)
            .build()

        val callControlCallback = object : CallControlCallback {
            override fun onSetActive(wasCompleted: Consumer<Boolean>) {
                CallStreamingServiceControl.log(TAG, "CallControlCallback.onSetActive")
                wasCompleted.accept(true)
            }

            override fun onSetInactive(wasCompleted: Consumer<Boolean>) {
                CallStreamingServiceControl.log(TAG, "CallControlCallback.onSetInactive")
                wasCompleted.accept(true)
            }

            override fun onAnswer(videoState: Int, wasCompleted: Consumer<Boolean>) {
                CallStreamingServiceControl.log(TAG, "CallControlCallback.onAnswer (videoState=$videoState)")
                wasCompleted.accept(true)
            }

            override fun onDisconnect(disconnectCause: DisconnectCause, wasCompleted: Consumer<Boolean>) {
                CallStreamingServiceControl.log(TAG, "CallControlCallback.onDisconnect ($disconnectCause)")
                activeCallControl = null
                activeCallId = null
                wasCompleted.accept(true)
            }

            override fun onCallStreamingStarted(wasCompleted: Consumer<Boolean>) {
                CallStreamingServiceControl.log(TAG, "CallControlCallback.onCallStreamingStarted!")
                wasCompleted.accept(true)
            }
        }

        val callEventCallback = object : CallEventCallback {
            override fun onCallEndpointChanged(newCallEndpoint: CallEndpoint) {
                CallStreamingServiceControl.log(TAG, "CallEndpoint changed: ${newCallEndpoint.endpointName} (${newCallEndpoint.endpointType})")
            }

            override fun onAvailableCallEndpointsChanged(availableEndpoints: List<CallEndpoint>) {
                CallStreamingServiceControl.log(TAG, "Available CallEndpoints: ${availableEndpoints.map { it.endpointName.toString() }}")
            }

            override fun onMuteStateChanged(isMuted: Boolean) {
                CallStreamingServiceControl.log(TAG, "Mute state changed: $isMuted")
            }

            override fun onCallStreamingFailed(reason: Int) {
                CallStreamingServiceControl.log(TAG, "CallEventCallback.onCallStreamingFailed! Reason code: $reason", "ERROR")
            }

            override fun onEvent(event: String, extras: Bundle) {
                CallStreamingServiceControl.log(TAG, "CallEventCallback event: $event")
            }
        }

        CallStreamingServiceControl.log(TAG, "Invoking telecomManager.addCall()...")

        telecomManager.addCall(
            callAttributes,
            executor,
            object : OutcomeReceiver<CallControl, CallException> {
                override fun onResult(control: CallControl) {
                    activeCallControl = control
                    activeCallId = control.callId.toString()
                    CallStreamingServiceControl.log(TAG, "Call created successfully! CallId: ${control.callId}")

                    // Activate call
                    control.setActive(executor, object : OutcomeReceiver<Void, CallException> {
                        override fun onResult(result: Void?) {
                            CallStreamingServiceControl.log(TAG, "Call set to ACTIVE state")
                        }

                        override fun onError(error: CallException) {
                            CallStreamingServiceControl.log(TAG, "Failed to set call active: ${error.message}", "WARN")
                        }
                    })

                    callback(true, "Call created with ID: ${control.callId}")
                }

                override fun onError(error: CallException) {
                    CallStreamingServiceControl.log(TAG, "addCall failed: code=${error.code}, message=${error.message}", "ERROR")
                    callback(false, "Failed to add call: ${error.message} (code: ${error.code})")
                }
            },
            callControlCallback,
            callEventCallback
        )
    }

    /**
     * Triggers startCallStreaming() on active CallControl (exact method used in CTS test)
     */
    fun startCallStreaming(callback: (Boolean, String) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            callback(false, "API 34+ required")
            return
        }

        val control = activeCallControl as? CallControl
        if (control == null) {
            callback(false, "No active call found. Please create or answer a call first.")
            return
        }

        CallStreamingServiceControl.log(TAG, "Calling CallControl.startCallStreaming()...")
        try {
            control.startCallStreaming(
                executor,
                object : OutcomeReceiver<Void, CallException> {
                    override fun onResult(result: Void?) {
                        CallStreamingServiceControl.log(TAG, "CallControl.startCallStreaming SUCCESS!")
                        callback(true, "Call streaming started successfully by Telecom stack")
                    }

                    override fun onError(error: CallException) {
                        CallStreamingServiceControl.log(TAG, "startCallStreaming failed: ${error.message} (code: ${error.code})", "ERROR")
                        callback(false, "Streaming request rejected: ${error.message} (code: ${error.code})")
                    }
                }
            )
        } catch (e: Exception) {
            CallStreamingServiceControl.log(TAG, "Exception starting call streaming: ${e.message}", "ERROR")
            callback(false, "Exception: ${e.message}")
        }
    }

    fun stopCallStreaming(callback: (Boolean, String) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            callback(false, "API 34+ required")
            return
        }

        val control = activeCallControl as? CallControl
        if (control == null) {
            callback(false, "No active call found")
            return
        }

        CallStreamingServiceControl.log(TAG, "Stopping call streaming...")
        try {
            // Can request streaming call control disconnect or set streaming call state
            val success = CallStreamingServiceControl.changeStreamingCallState(2 /* HOLD */)
            CallStreamingServiceControl.onStreamingStopped()
            callback(true, "Call streaming stopped")
        } catch (e: Exception) {
            callback(false, "Error stopping streaming: ${e.message}")
        }
    }

    fun disconnectActiveCall(callback: (Boolean, String) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            callback(false, "API 34+ required")
            return
        }

        val control = activeCallControl as? CallControl
        if (control == null) {
            callback(false, "No active call to disconnect")
            return
        }

        try {
            val cause = DisconnectCause(DisconnectCause.LOCAL)
            control.disconnect(cause, executor, object : OutcomeReceiver<Void, CallException> {
                override fun onResult(result: Void?) {
                    CallStreamingServiceControl.log(TAG, "Call disconnected successfully")
                    activeCallControl = null
                    activeCallId = null
                    callback(true, "Call disconnected")
                }

                override fun onError(error: CallException) {
                    CallStreamingServiceControl.log(TAG, "Error disconnecting call: ${error.message}", "WARN")
                    callback(false, "Error disconnecting: ${error.message}")
                }
            })
        } catch (e: Exception) {
            callback(false, "Exception: ${e.message}")
        }
    }
}
