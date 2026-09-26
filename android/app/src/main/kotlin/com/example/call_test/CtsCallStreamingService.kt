package com.example.call_test

import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.telecom.CallStreamingService
import android.telecom.StreamingCall
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
class CtsCallStreamingService : CallStreamingService() {
    companion object {
        private const val TAG = "CtsCallStreamingService"
    }

    override fun onCreate() {
        super.onCreate()
        CallStreamingServiceControl.log(TAG, "Service onCreate")
    }

    override fun onBind(intent: Intent?): IBinder? {
        CallStreamingServiceControl.log(TAG, "onBind action=${intent?.action}")
        CallStreamingServiceControl.onServiceConnected()
        return super.onBind(intent)
    }

    override fun onUnbind(intent: Intent?): Boolean {
        CallStreamingServiceControl.log(TAG, "onUnbind")
        CallStreamingServiceControl.onServiceDisconnected()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        CallStreamingServiceControl.log(TAG, "Service onDestroy")
        CallStreamingServiceControl.onServiceDisconnected()
    }

    override fun onCallStreamingStarted(streamingCall: StreamingCall) {
        CallStreamingServiceControl.log(TAG, "onCallStreamingStarted: streamingCall=$streamingCall")
        CallStreamingServiceControl.onStreamingStarted(streamingCall)
    }

    override fun onCallStreamingStopped() {
        CallStreamingServiceControl.log(TAG, "onCallStreamingStopped")
        CallStreamingServiceControl.onStreamingStopped()
    }

    override fun onCallStreamingStateChanged(state: Int) {
        CallStreamingServiceControl.log(TAG, "onCallStreamingStateChanged: state=$state")
        CallStreamingServiceControl.onStreamingStateChanged(state)
    }
}
