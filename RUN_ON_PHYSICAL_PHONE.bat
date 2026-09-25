@echo off
title VIGIL AI - Physical Phone USB Runner
echo ========================================================
echo   Setting up VIGIL AI on Connected Physical Android Phone
echo ========================================================
echo.
echo Step 1: Forwarding network port 5000 over USB cable...
"C:\Users\VAISHU\AppData\Local\Android\Sdk\platform-tools\adb.exe" reverse tcp:5000 tcp:5000
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] No physical Android phone detected via adb.
    echo Make sure:
    echo 1. USB debugging is ENABLED on your phone.
    echo 2. Phone is connected via USB cable and "Allow USB debugging" was accepted.
    pause
    exit /b
)
echo [SUCCESS] USB reverse tunnel active! (Phone port 5000 -^> Dell PC port 5000)
echo Note: If prompted in App Settings, set API URL to http://127.0.0.1:5000/api
echo.
echo Step 2: Launching Flutter app on your phone...
cd /d "C:\Users\VAISHU\.gemini\antigravity\scratch\vigil_ai\vigil_ai_mobile"
flutter run
pause
