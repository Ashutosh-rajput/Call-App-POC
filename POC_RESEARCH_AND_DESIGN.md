# Android Call Streaming Test App: Research & Proof-of-Concept Design

Based on the Android Open Source Project (AOSP) CTS (`android.telecom.cts.streamingtestapp`) implementation.

---

## 1. Executive Summary

Android 14 (API level 34) introduced an official system call-streaming service stack:
- **`android.telecom.CallStreamingService`**
- **`android.telecom.StreamingCall`**
- **`android.telecom.CallControl.startCallStreaming()`**
- Protected system role: **`android.app.role.SYSTEM_CALL_STREAMING`**
- Protected permissions: **`android.permission.CALL_AUDIO_INTERCEPTION`** and **`android.permission.BIND_CALL_STREAMING_SERVICE`**

In the AOSP CTS (Compatibility Test Suite), Google maintains a dedicated test package named `CallStreamingServiceTestApp` (`android.telecom.cts.streamingtestapp`). During test execution (`CallStreamingTest.java`), the CTS test environment assigns this package the `SYSTEM_CALL_STREAMING` role using a **role-qualification bypass** (`setByPassRoleQualification(true)`), initiates a call with `SUPPORTS_STREAM`, and triggers `CallControl.startCallStreaming()`. Telecom then binds the test service and invokes `onCallStreamingStarted(StreamingCall)`.

This project implements the complete architecture and test harness to evaluate whether Android's call-streaming stack can provide the GSM/PSTN call-audio path required for the two-phone calling concept.

---

## 2. AOSP Components & Architecture

| Component | Class / Role | Finding & Responsibility |
|---|---|---|
| **CallStreamingServiceTestApp** | `com.example.call_test` / CTS APK | Holds `SYSTEM_CALL_STREAMING` role during lab testing. Declares `CALL_AUDIO_INTERCEPTION` and `RECORD_AUDIO`. |
| **CtsCallStreamingService** | `android.telecom.CallStreamingService` | Receives `onCallStreamingStarted(StreamingCall)`, `onCallStreamingStopped()`, `onCallStreamingStateChanged(int)`. |
| **CallStreamingServiceControl** | Singleton Controller | Coordinates service state, latches, event streams, and live diagnostics logging. |
| **TelecomHelper** | `android.telecom.TelecomManager` | Registers `PhoneAccount`, calls `TelecomManager.addCall()` with `CallControlCallback`, and executes `CallControl.startCallStreaming()`. |
| **AudioProbeManager** | `android.media.AudioManager` / `AudioRecord` | Evaluates audio routing, devices (`TYPE_TELEPHONY`), and probes audio sources (`VOICE_COMMUNICATION`, `VOICE_CALL`, `VOICE_DOWNLINK`, `VOICE_UPLINK`, `MIC`). |
| **NetworkTransportProbe** | UDP / Socket Benchmarker | Tests 20ms audio frame transport latency, jitter, packet loss, and throughput for secondary phone bridge. |

---

## 3. Target 2-Phone Calling Architecture

```
PRIMARY PHONE
  SIM / PSTN Cellular Call
        |
        v
  Android Telecom Framework
        |  SYSTEM_CALL_STREAMING
        v
  CallStreamingService (This App)
        +-------------------------+
        |                         |
        v                         ^
  Audio Extraction       Remote Mic Injection
  (Rx Downlink)          (Tx Uplink)
        |                         ^
        +-----------> <-----------+
               Network Transport (WebRTC / UDP)
                     |
                     v
SECONDARY PHONE
  Speaker (Rx) + Microphone (Tx)
```

---

## 4. The 6-Phase Laboratory PoC

| Phase | Objective | Execution & Verification |
|---|---|---|
| **Phase 1** | Build & Manifest Verification | Confirms `CtsCallStreamingService` declaration protected with `BIND_CALL_STREAMING_SERVICE` and permissions declared. |
| **Phase 2** | Role Qualification Bypass | Bypasses role qualification via `adb shell cmd role add-role-holder --bypass-role-qualification android.app.role.SYSTEM_CALL_STREAMING com.example.call_test`. |
| **Phase 3** | AudioManager Deep Probe | Probes hardware HAL audio devices and attempts `AudioRecord` allocation across sources: `MIC`, `VOICE_CALL`, `VOICE_DOWNLINK`, `VOICE_UPLINK`, `VOICE_COMMUNICATION`. |
| **Phase 4** | PSTN Interception Assessment | Analyzes whether carrier GSM/PSTN downlink/uplink audio is accessible via `CALL_AUDIO_INTERCEPTION` or blocked by hardware DSP baseband isolation. |
| **Phase 5** | Audio Extraction & Monitor | Real-time PCM buffer capture with live dB/RMS level metering and peak amplitude tracking. |
| **Phase 6** | Network Transport Simulation | Benchmarks 20ms audio frame delivery over local/remote UDP network, measuring RTT latency, jitter, and packet loss. |

---

## 5. ADB Commands Reference

### 1. Grant Role with Bypass
```bash
adb shell cmd role add-role-holder --bypass-role-qualification android.app.role.SYSTEM_CALL_STREAMING com.example.call_test
```

### 2. Grant Protected & Dangerous Permissions
```bash
adb shell pm grant com.example.call_test android.permission.CALL_AUDIO_INTERCEPTION
adb shell pm grant com.example.call_test android.permission.RECORD_AUDIO
adb shell pm grant com.example.call_test android.permission.READ_PHONE_STATE
adb shell pm grant com.example.call_test android.permission.MANAGE_OWN_CALLS
```

### 3. Verify Active Role Holders
```bash
adb shell cmd role get-role-holders android.app.role.SYSTEM_CALL_STREAMING
```

### 4. Remove Role
```bash
adb shell cmd role remove-role-holder --bypass-role-qualification android.app.role.SYSTEM_CALL_STREAMING com.example.call_test
```

---

## 6. What This PoC Proves vs Cannot Prove

### What It Proves:
1. Whether the AOSP call-streaming service can be registered and invoked in a controlled Android 14+ build.
2. Whether the `SYSTEM_CALL_STREAMING` role causes the expected service binding in Telecom.
3. Whether `CALL_AUDIO_INTERCEPTION` is granted and active in the test environment.
4. Whether active PSTN/GSM call audio can be exposed or if the OEM modem audio routing bypasses the application processor.
5. Whether the intercepted audio can be transported to another Android device with sub-100ms latency.

### What It Cannot Prove:
1. It does not prove that an ordinary consumer Play Store APK can obtain `SYSTEM_CALL_STREAMING` on stock Samsung/Pixel/Xiaomi devices (as consumer builds disallow the bypass).
2. It does not prove that setting the default dialer role automatically confers `CALL_AUDIO_INTERCEPTION`.
3. It does not prove identical audio HAL behavior across different OEM chipsets (Qualcomm vs Exynos vs MediaTek).
