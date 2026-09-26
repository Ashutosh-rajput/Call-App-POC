@echo off
REM ==============================================================================
REM AOSP CallStreamingServiceTestApp Role & Permission Automation Script (Windows)
REM Assigns SYSTEM_CALL_STREAMING role via CTS Role-Qualification Bypass
REM ==============================================================================

set PACKAGE=com.example.call_test
set ROLE=android.app.role.SYSTEM_CALL_STREAMING

echo [*] Checking ADB connection...
adb devices
if %ERRORLEVEL% NEQ 0 (
    echo [!] ADB is not running or no devices connected.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [*] Step 1: Assigning %ROLE% with --bypass-role-qualification...
adb shell cmd role add-role-holder --bypass-role-qualification %ROLE% %PACKAGE%

echo.
echo [*] Step 2: Granting protected and dangerous permissions...
adb shell pm grant %PACKAGE% android.permission.CALL_AUDIO_INTERCEPTION
adb shell pm grant %PACKAGE% android.permission.RECORD_AUDIO
adb shell pm grant %PACKAGE% android.permission.READ_PHONE_STATE
adb shell pm grant %PACKAGE% android.permission.MANAGE_OWN_CALLS

echo.
echo [*] Step 3: Verifying active role holders for %ROLE%...
adb shell cmd role get-role-holders %ROLE%

echo.
echo [OK] Setup completed! Launch the app and verify the role status is HELD.
pause
