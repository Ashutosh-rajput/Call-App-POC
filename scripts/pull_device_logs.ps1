# ==============================================================================
# Pull Call Streaming Debug Logs from Device to Workspace (PowerShell)
# ==============================================================================

$Package = "com.example.call_test"
$RemotePath = "/sdcard/Android/data/$Package/files/logs/call_streaming_debug.log"
$LocalDir = Join-Path $PSScriptRoot "..\logs"
$LocalPath = Join-Path $LocalDir "call_streaming_debug.log"

if (-not (Test-Path $LocalDir)) { New-Item -ItemType Directory -Path $LocalDir | Out-Null }

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
    Write-Host "[!] ADB was not found." -ForegroundColor Red
    exit 1
}

Write-Host "[*] Pulling debug logs from Android device..." -ForegroundColor Cyan
Write-Host "[*] Remote path: $RemotePath" -ForegroundColor Gray
Write-Host "[*] Local destination: $LocalPath" -ForegroundColor Gray

& $adbPath pull $RemotePath $LocalPath 2>$null
if ($LASTEXITCODE -eq 0 -and (Test-Path $LocalPath)) {
    Write-Host "[OK] Successfully copied logs to: $LocalPath" -ForegroundColor Green
} else {
    Write-Host "[!] Direct pull failed. Trying run-as fallback..." -ForegroundColor Yellow
    $content = & $adbPath exec-out run-as $Package cat files/logs/call_streaming_debug.log 2>$null
    if ($content) {
        $content | Out-File -FilePath $LocalPath -Encoding utf8
        Write-Host "[OK] Successfully extracted logs via run-as to: $LocalPath" -ForegroundColor Green
    } else {
        Write-Host "[!] Could not pull log file. Make sure the app has been launched on the device." -ForegroundColor Red
    }
}
