package com.example.call_test

import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.PhoneAccountHandle

class CtsConnectionService : ConnectionService() {
    companion object {
        private const val TAG = "CtsConnectionService"
        var activeConnection: Connection? = null
            private set
    }

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        CallStreamingServiceControl.log(TAG, "onCreateIncomingConnection: $request")
        val conn = CtsTestConnection()
        conn.setInitializing()
        conn.connectionProperties = Connection.PROPERTY_SELF_MANAGED
        conn.connectionCapabilities = Connection.CAPABILITY_SUPPORT_HOLD or Connection.CAPABILITY_HOLD or Connection.CAPABILITY_MUTE
        conn.setActive()
        activeConnection = conn
        return conn
    }

    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        CallStreamingServiceControl.log(TAG, "onCreateOutgoingConnection: $request")
        val conn = CtsTestConnection()
        conn.setInitializing()
        conn.connectionProperties = Connection.PROPERTY_SELF_MANAGED
        conn.connectionCapabilities = Connection.CAPABILITY_SUPPORT_HOLD or Connection.CAPABILITY_HOLD or Connection.CAPABILITY_MUTE
        conn.setDialing()
        conn.setActive()
        activeConnection = conn
        return conn
    }

    class CtsTestConnection : Connection() {
        init {
            audioModeIsVoip = true
        }

        override fun onAnswer() {
            CallStreamingServiceControl.log("CtsConnection", "onAnswer called")
            setActive()
        }

        override fun onReject() {
            CallStreamingServiceControl.log("CtsConnection", "onReject called")
            setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
            destroy()
            activeConnection = null
        }

        override fun onDisconnect() {
            CallStreamingServiceControl.log("CtsConnection", "onDisconnect called")
            setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
            destroy()
            activeConnection = null
        }

        override fun onHold() {
            CallStreamingServiceControl.log("CtsConnection", "onHold called")
            setOnHold()
        }

        override fun onUnhold() {
            CallStreamingServiceControl.log("CtsConnection", "onUnhold called")
            setActive()
        }
    }
}
