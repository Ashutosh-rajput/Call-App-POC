@echo off
REM ==============================================================================
REM Stream Live Logcat for Call Streaming and Telecom into logs/call_streaming_live.log
REM ==============================================================================

set SCRIPT_DIR=%~dp0
set LOCAL_LOG_DIR=%SCRIPT_DIR%..\logs
set LIVE_LOG_PATH=%LOCAL_LOG_DIR%\call_streaming_live.log

if not exist "%LOCAL_LOG_DIR%" mkdir "%LOCAL_LOG_DIR%"

echo [*] Streaming real-time Android logcat for Call Streaming components...
echo [*] Writing live output to: %LIVE_LOG_PATH%
echo [*] Press Ctrl+C to stop streaming.
echo.

adb logcat -v time -s CtsCallStreamingService:V CallStreamingControl:V TelecomHelper:V AudioProbeManager:V NetworkTransportProbe:V CtsConnectionService:V Telecom:I | powershell -Command "$input | Tee-Object -FilePath '%LIVE_LOG_PATH%'"
