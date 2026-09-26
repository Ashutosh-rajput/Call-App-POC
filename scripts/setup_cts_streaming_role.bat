@echo off
REM ==============================================================================
REM AOSP CallStreamingServiceTestApp Role & Permission Automation Script (Windows)
REM Assigns SYSTEM_CALL_STREAMING role via CTS Role-Qualification Bypass
REM ==============================================================================

set PACKAGE=com.example.call_test
set ROLE=android.app.role.SYSTEM_CALL_STREAMING

set "ADB="
where adb >nul 2>&1
if not errorlevel 1 set "ADB=adb"

if not defined ADB if defined ANDROID_HOME if exist "%ANDROID_HOME%\platform-tools\adb.exe" set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
if not defined ADB if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" set "ADB=%ANDROID_SDK_ROOT%\platform-tools\adb.exe"

if not defined ADB if exist "%~dp0..\android\local.properties" (
    for /f "tokens=1,* delims==" %%A in ('findstr /b "sdk.dir=" "%~dp0..\android\local.properties"') do set "ANDROID_SDK=%%B"
    set "ANDROID_SDK=%ANDROID_SDK:\\=\%"
    if exist "%ANDROID_SDK%\platform-tools\adb.exe" set "ADB=%ANDROID_SDK%\platform-tools\adb.exe"
)

if not defined ADB (
    echo [!] ADB was not found. Add Android SDK platform-tools to PATH or set ANDROID_HOME.
    pause
    exit /b 1
)

echo [*] Checking ADB connection...
"%ADB%" devices
if %ERRORLEVEL% NEQ 0 (
    echo [!] Failed to start ADB. Check the Android SDK platform-tools installation.
    pause
    exit /b %ERRORLEVEL%
)

"%ADB%" get-state >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [!] No ADB device is connected. Enable USB debugging and authorize this computer.
    pause
    exit /b 1
)

echo.
echo [*] Step 1: Assigning %ROLE% with --bypass-role-qualification...
"%ADB%" shell cmd role add-role-holder --bypass-role-qualification %ROLE% %PACKAGE%

echo.
echo [*] Step 2: Granting protected and dangerous permissions...
"%ADB%" shell pm grant %PACKAGE% android.permission.CALL_AUDIO_INTERCEPTION
"%ADB%" shell pm grant %PACKAGE% android.permission.RECORD_AUDIO
"%ADB%" shell pm grant %PACKAGE% android.permission.READ_PHONE_STATE
"%ADB%" shell pm grant %PACKAGE% android.permission.MANAGE_OWN_CALLS

echo.
echo [*] Step 3: Verifying active role holders for %ROLE%...
"%ADB%" shell cmd role get-role-holders %ROLE%

echo.
echo [OK] Setup completed! Launch the app and verify the role status is HELD.
pause
