#!/usr/bin/env bash
# ==============================================================================
# Stream Live Logcat for Call Streaming and Telecom into logs/call_streaming_live.log
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_LOG_DIR="$SCRIPT_DIR/../logs"
LIVE_LOG_PATH="$LOCAL_LOG_DIR/call_streaming_live.log"

mkdir -p "$LOCAL_LOG_DIR"

echo "[*] Streaming real-time Android logcat for Call Streaming components..."
echo "[*] Writing live output to: $LIVE_LOG_PATH"
echo "[*] Press Ctrl+C to stop streaming."
echo ""

adb logcat -v time -s CtsCallStreamingService:V CallStreamingControl:V TelecomHelper:V AudioProbeManager:V NetworkTransportProbe:V CtsConnectionService:V Telecom:I | tee "$LIVE_LOG_PATH"
