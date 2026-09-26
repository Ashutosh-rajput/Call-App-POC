@echo off
REM ==============================================================================
REM AOSP CallStreamingServiceTestApp Role & Permission Automation Script (Windows)
REM ==============================================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_cts_streaming_role.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo [!] Script encountered an error.
)
pause
