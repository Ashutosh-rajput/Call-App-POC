# Android Call Streaming Test App & Proof-of-Concept Design

Based on the **Android Open Source Project (AOSP) CTS (`CallStreamingServiceTestApp`)** implementation.

This project delivers a functional Android & Flutter test harness designed to determine whether Android 14's system call-streaming stack (`android.telecom.CallStreamingService`) and telephony audio routing can provide the GSM/PSTN call-audio path required for the two-phone calling concept.

---

## 1. System Architecture

```
PRIMARY PHONE
  SIM / PSTN Cellular Call
        |
        v
  Android Telecom Framework
        |  SYSTEM_CALL_STREAMING Role
        v
  CallStreamingService (CtsCallStreamingService)
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

## 2. Implemented Components

| Component | File / Path | Responsibility |
|---|---|---|
| **CtsCallStreamingService** | `android/app/.../CtsCallStreamingService.kt` | AOSP CTS `CallStreamingService` implementation receiving `onCallStreamingStarted(StreamingCall)`, `onCallStreamingStopped()`, `onCallStreamingStateChanged(int)`. |
| **CallStreamingServiceControl** | `android/app/.../CallStreamingServiceControl.kt` | Singleton controller coordinating streaming state, CTS CountDownLatch synchronization, and live event broadcasting. |
| **TelecomHelper** | `android/app/.../TelecomHelper.kt` | Handles `PhoneAccount` registration, `TelecomManager.addCall()` with `CallControlCallback`, and invokes `CallControl.startCallStreaming()`. |
| **AudioProbeManager** | `android/app/.../AudioProbeManager.kt` | Evaluates hardware `AudioManager` capabilities, audio devices (`TYPE_TELEPHONY`), and probes audio sources (`MIC`, `VOICE_CALL`, `VOICE_DOWNLINK`, `VOICE_UPLINK`, `VOICE_COMMUNICATION`). |
| **NetworkTransportProbe** | `android/app/.../NetworkTransportProbe.kt` | Simulates and benchmarks 20ms audio frame transport (RTT latency, jitter, packet loss %, throughput) over UDP loopback or network. |
| **Framework Stubs** | `android/framework-stubs/` | Gradle `compileOnly` module providing `CallStreamingService` and `StreamingCall` definitions for compilation while binding to real device AOSP framework at runtime. |
| **Interactive UI** | `lib/` | Flutter Material 3 application featuring 5 tabs: Dashboard, 6-Phase PoC Runner, Call Streaming Controller, ADB Toolkit, and Live Diagnostic Logs. |

---

## 3. The 6-Phase Laboratory PoC

1. **Phase 1: Component & Manifest Verification**: Validates `CtsCallStreamingService` protected by `BIND_CALL_STREAMING_SERVICE` and manifest permissions.
2. **Phase 2: Role Allocation & Qualification Bypass**: Applies `setByPassRoleQualification(true)` via ADB to assign `android.app.role.SYSTEM_CALL_STREAMING`.
3. **Phase 3: AudioManager Capability & Source Probe**: Tests `AudioRecord` allocation, permissions, and buffers across all telephony & VoIP sources.
4. **Phase 4: Cellular / PSTN Interception Assessment**: Evaluates whether active cellular call streams are interceptable or blocked by OEM modem baseband isolation.
5. **Phase 5: Audio Extraction & Level Monitor**: Captures live PCM audio buffers with real-time RMS dB and peak amplitude metering.
6. **Phase 6: Network Transport Simulator**: Benchmarks 20ms audio frame packet delivery to measure RTT latency, jitter, and packet loss.

---

## 4. Quick Start: ADB Setup

On an Android 14+ (API 34+) development device or emulator:

### Windows Batch Script
```cmd
scripts\setup_cts_streaming_role.bat
```

### Linux / macOS Script
```bash
chmod +x scripts/setup_cts_streaming_role.sh
./scripts/setup_cts_streaming_role.sh
```

### Manual ADB Commands
```bash
# 1. Assign SYSTEM_CALL_STREAMING role via qualification bypass
adb shell cmd role add-role-holder --bypass-role-qualification android.app.role.SYSTEM_CALL_STREAMING com.example.call_test

# 2. Grant permissions
adb shell pm grant com.example.call_test android.permission.CALL_AUDIO_INTERCEPTION
adb shell pm grant com.example.call_test android.permission.RECORD_AUDIO
adb shell pm grant com.example.call_test android.permission.READ_PHONE_STATE
adb shell pm grant com.example.call_test android.permission.MANAGE_OWN_CALLS

# 3. Verify active role holder
adb shell cmd role get-role-holders android.app.role.SYSTEM_CALL_STREAMING
```

---

## 5. Building & Running

```bash
# Run tests
flutter test

# Build debug APK
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk

# Install & Run on device
flutter run -d <device-id>
```
