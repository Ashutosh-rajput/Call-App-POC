package android.telecom;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;

public abstract class CallStreamingService extends Service {
    public static final String SERVICE_INTERFACE = "android.telecom.CallStreamingService";

    public CallStreamingService() {
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    public void onCallStreamingStarted(StreamingCall streamingCall) {
    }

    public void onCallStreamingStopped() {
    }

    public void onCallStreamingStateChanged(int state) {
    }
}
