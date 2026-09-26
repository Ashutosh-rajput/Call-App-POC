package android.telecom;

import android.os.Bundle;

public final class StreamingCall {
    public static final int STATE_STREAMING = 1;
    public static final int STATE_HOLDING = 2;

    public static final String EXTRA_CALL_AUTHORITY = "android.telecom.extra.CALL_AUTHORITY";

    private StreamingCall() {
        throw new RuntimeException("Stub!");
    }

    public Bundle getExtras() {
        throw new RuntimeException("Stub!");
    }

    public int getStreamingCallState() {
        throw new RuntimeException("Stub!");
    }

    public void setStreamingCallState(int state) {
        throw new RuntimeException("Stub!");
    }
}
