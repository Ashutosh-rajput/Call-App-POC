# ==============================================================================
# AOSP CallStreamingServiceTestApp Role & Permission Automation Script (PowerShell)
# Assigns SYSTEM_CALL_STREAMING role via CTS Role-Qualification Bypass
# ==============================================================================

$Package = "com.example.call_test"
$Role = "android.app.role.SYSTEM_CALL_STREAMING"

# Locate adb
$adbPath = $null
if (Get-Command adb -ErrorAction SilentlyContinue) {
    $adbPath = "adb"
} elseif (Test-Path "D:\FlutterSDK\android-sdk\platform-tools\adb.exe") {
    $adbPath = "D:\FlutterSDK\android-sdk\platform-tools\adb.exe"
} elseif ($env:ANDROID_HOME -and (Test-Path "$env:ANDROID_HOME\platform-tools\adb.exe")) {
    $adbPath = "$env:ANDROID_HOME\platform-tools\adb.exe"
} elseif (Test-Path "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe") {
    $adbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
}

if (-not $adbPath) {
    Write-Host "[!] ADB was not found. Please ensure Android SDK platform-tools is installed." -ForegroundColor Red
    exit 1
}

Write-Host "[*] Checking ADB connection..." -ForegroundColor Cyan
& $adbPath devices

$deviceState = (& $adbPath get-state 2>&1).Trim()
if ($LASTEXITCODE -ne 0 -or $deviceState -ne "device") {
    Write-Host "[!] No authorized ADB device is connected." -ForegroundColor Red
    exit 1
}

$deviceSdk = [int]((& $adbPath shell getprop ro.build.version.sdk).Trim())
$deviceOs = (& $adbPath shell getprop ro.build.version.release).Trim()
$deviceModel = (& $adbPath shell getprop ro.product.model).Trim()
$deviceMfg = (& $adbPath shell getprop ro.product.manufacturer).Trim()

Write-Host "`n[*] Connected Device: $deviceMfg $deviceModel (Android $deviceOs, API $deviceSdk)" -ForegroundColor Green

if ($deviceSdk -lt 34) {
    Write-Host "`n==============================================================================" -ForegroundColor Yellow
    Write-Host "[!] SYSTEM COMPATIBILITY NOTE:" -ForegroundColor Yellow
    Write-Host "[!] Target device is running Android $deviceOs (API $deviceSdk)." -ForegroundColor Yellow
    Write-Host "[!] The AOSP SYSTEM_CALL_STREAMING role and CallStreamingService stack were" -ForegroundColor Yellow
    Write-Host "[!] introduced in Android 14 (API 34)." -ForegroundColor Yellow
    Write-Host "[!] On Android 13 and below, the SYSTEM_CALL_STREAMING role does not exist." -ForegroundColor Yellow
    Write-Host "[!]" -ForegroundColor Yellow
    Write-Host "[!] You can still test on this device:" -ForegroundColor Yellow
    Write-Host "[!]   - Phase 3: AudioManager capability and audio source probe" -ForegroundColor Yellow
    Write-Host "[!]   - Phase 5: Live audio extraction and level monitoring" -ForegroundColor Yellow
    Write-Host "[!]   - Phase 6: Network transport 2-phone bridge simulation" -ForegroundColor Yellow
    Write-Host "==============================================================================`n" -ForegroundColor Yellow
}

Write-Host "[*] Step 1: Granting runtime permissions (RECORD_AUDIO, READ_PHONE_STATE)..." -ForegroundColor Cyan
& $adbPath shell pm grant $Package android.permission.RECORD_AUDIO 2>$null
& $adbPath shell pm grant $Package android.permission.READ_PHONE_STATE 2>$null
Write-Host "[OK] Runtime permissions granted." -ForegroundColor Green

if ($deviceSdk -ge 34) {
    Write-Host "`n[*] Step 2: Assigning $Role with CTS role qualification bypass..." -ForegroundColor Cyan
    & $adbPath shell cmd role add-role-holder --bypass-role-qualification $Role $Package 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[*] Trying alternative bypass command syntax..." -ForegroundColor Gray
        & $adbPath shell cmd role set-bypassing-role-qualification true
        & $adbPath shell cmd role add-role-holder $Role $Package
    }
    Write-Host "`n[*] Step 3: Verifying active role holders for $Role..." -ForegroundColor Cyan
    & $adbPath shell cmd role get-role-holders $Role
} else {
    Write-Host "`n[*] Step 2: Skipping SYSTEM_CALL_STREAMING assignment (Requires Android 14 / API 34+)." -ForegroundColor Gray
}

Write-Host "`n[*] Step 3: Pulling on-device debug log file to local workspace..." -ForegroundColor Cyan
$logsDir = Join-Path $PSScriptRoot "..\logs"
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }
$destLog = Join-Path $logsDir "call_streaming_debug.log"
& $adbPath pull "/sdcard/Android/data/$Package/files/logs/call_streaming_debug.log" "$destLog" 2>$null
if (Test-Path $destLog) {
    Write-Host "[OK] Device logs synced to: logs\call_streaming_debug.log" -ForegroundColor Green
}

Write-Host "`n[OK] Setup completed successfully!" -ForegroundColor Green
