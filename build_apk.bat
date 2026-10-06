@echo off
REM Usage:  build_apk.bat http://10.29.80.74:8000
if "%~1"=="" (
  echo.
  echo Please give the API address, for example:
  echo    build_apk.bat http://10.29.80.74:8000
  exit /b 1
)
set "API_URL=%~1"
cd /d "%~dp0frontend" || exit /b 1

if not exist android (
  echo === Creating the Android project folder (one time) ===
  call flutter create --platforms=android --org com.kopragrade --project-name kopragrade .
  if errorlevel 1 exit /b 1
)

python "%~dp0tools\prepare_android.py" "%API_URL%"
if errorlevel 1 exit /b 1

call flutter clean
call flutter pub get
if errorlevel 1 exit /b 1
call flutter analyze --no-fatal-infos --no-fatal-warnings
if errorlevel 1 (
  echo Fix the errors shown above, then run this file again.
  exit /b 1
)
call flutter build apk --release --dart-define=API_BASE_URL=%API_URL%
if errorlevel 1 exit /b 1

echo.
echo DONE. Your APK is here:
echo   %~dp0frontend\build\app\outputs\flutter-apk\app-release.apk