@echo off
REM ==============================================================================
REM Pull Call Streaming Debug Logs from Device to Workspace (Windows)
REM ==============================================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pull_device_logs.ps1"
pause
