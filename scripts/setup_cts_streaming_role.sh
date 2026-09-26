#!/usr/bin/env bash
# ==============================================================================
# AOSP CallStreamingServiceTestApp Role & Permission Automation Script (POSIX)
# Assigns SYSTEM_CALL_STREAMING role via CTS Role-Qualification Bypass
# ==============================================================================

PACKAGE="com.example.call_test"
ROLE="android.app.role.SYSTEM_CALL_STREAMING"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Checking ADB connection..."
adb devices

DEVICE_SDK=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
DEVICE_OS=$(adb shell getprop ro.build.version.release | tr -d '\r')
DEVICE_MODEL=$(adb shell getprop ro.product.model | tr -d '\r')
DEVICE_MFG=$(adb shell getprop ro.product.manufacturer | tr -d '\r')

echo ""
echo "[*] Connected Device: $DEVICE_MFG $DEVICE_MODEL (Android $DEVICE_OS, API $DEVICE_SDK)"

if [ "$DEVICE_SDK" -lt 34 ]; then
    echo ""
    echo "=============================================================================="
    echo "[!] SYSTEM COMPATIBILITY NOTE:"
    echo "[!] Target device is running Android $DEVICE_OS (API $DEVICE_SDK)."
    echo "[!] The AOSP SYSTEM_CALL_STREAMING role and CallStreamingService stack were"
    echo "[!] introduced in Android 14 (API 34)."
    echo "[!] On Android 13 and below, the SYSTEM_CALL_STREAMING role does not exist."
    echo "[!]"
    echo "[!] You can still test on this device:"
    echo "[!]   - Phase 3: AudioManager capability & audio source probe"
    echo "[!]   - Phase 5: Live audio extraction & level monitoring"
    echo "[!]   - Phase 6: Network transport 2-phone bridge simulation"
    echo "=============================================================================="
    echo ""
fi

echo "[*] Step 1: Granting runtime permissions (RECORD_AUDIO, READ_PHONE_STATE)..."
adb shell pm grant "$PACKAGE" android.permission.RECORD_AUDIO 2>/dev/null
adb shell pm grant "$PACKAGE" android.permission.READ_PHONE_STATE 2>/dev/null
echo "[OK] Runtime permissions granted."

if [ "$DEVICE_SDK" -ge 34 ]; then
    echo ""
    echo "[*] Step 2: Assigning $ROLE with CTS role qualification bypass..."
    adb shell cmd role add-role-holder --bypass-role-qualification "$ROLE" "$PACKAGE" 2>/dev/null || {
        echo "[*] Trying alternative bypass command syntax..."
        adb shell cmd role set-bypassing-role-qualification true
        adb shell cmd role add-role-holder "$ROLE" "$PACKAGE"
    }
    echo ""
    echo "[*] Step 3: Verifying active role holders for $ROLE..."
    adb shell cmd role get-role-holders "$ROLE"
else
    echo ""
    echo "[*] Step 2: Skipping SYSTEM_CALL_STREAMING assignment (Requires API 34+ device)."
fi

echo ""
echo "[*] Step 3: Pulling on-device debug log file to local workspace..."
mkdir -p "$SCRIPT_DIR/../logs"
adb pull "/sdcard/Android/data/$PACKAGE/files/logs/call_streaming_debug.log" "$SCRIPT_DIR/../logs/call_streaming_debug.log" 2>/dev/null
if [ -f "$SCRIPT_DIR/../logs/call_streaming_debug.log" ]; then
    echo "[OK] Device logs synced to: logs/call_streaming_debug.log"
fi

echo ""
echo "[OK] Setup script finished."
