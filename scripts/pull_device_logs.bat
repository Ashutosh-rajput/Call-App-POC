@echo off
REM ==============================================================================
REM Pull Call Streaming Debug Logs from Device to Workspace
REM ==============================================================================

set PACKAGE=com.example.call_test
set REMOTE_LOG_PATH=/sdcard/Android/data/%PACKAGE%/files/logs/call_streaming_debug.log
set LOCAL_LOG_DIR=%~dp0..\logs
set LOCAL_LOG_PATH=%LOCAL_LOG_DIR%\call_streaming_debug.log

if not exist "%LOCAL_LOG_DIR%" mkdir "%LOCAL_LOG_DIR%"

echo [*] Pulling debug logs from Android device...
echo [*] Remote path: %REMOTE_LOG_PATH%
echo [*] Local destination: %LOCAL_LOG_PATH%

adb pull %REMOTE_LOG_PATH% "%LOCAL_LOG_PATH%"
if %ERRORLEVEL% EQU 0 (
    echo [OK] Successfully copied logs to: %LOCAL_LOG_PATH%
) else (
    echo [!] Direct pull failed. Trying run-as fallback...
    adb exec-out run-as %PACKAGE% cat files/logs/call_streaming_debug.log > "%LOCAL_LOG_PATH%"
    if %ERRORLEVEL% EQU 0 (
        echo [OK] Successfully extracted logs via run-as!
    ) else (
        echo [!] Could not pull log file. Make sure the app has been launched on the device.
    )
)

echo.
pause
