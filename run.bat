@echo off
setlocal EnableExtensions

REM Repository root directory (where this .bat lives)
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

REM Notification helper (toast)
set "NOTIFY=powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\notify.ps1""

REM Load env.bat (if present)
if exist "%ROOT%\env.bat" call "%ROOT%\env.bat"

REM ---- ADB location ----
set "ADB=adb"

REM If adb is not in PATH, fall back to repo-bundled adb
where adb >nul 2>nul
if errorlevel 1 (
  if not exist "%ROOT%\tools\platform-tools\adb.exe" (
    %NOTIFY% -Title "ADB not found" -Message "Install Android platform-tools (adb) or place them under tools\platform-tools."
    exit /b 1
  )
  set "ADB=%ROOT%\tools\platform-tools\adb.exe"
)

REM ---- Fire TV IP ----
if "%FIRETV_IP%"=="" (
  %NOTIFY% -Title "Missing FIRETV_IP" -Message "Create env.bat from env.example.bat and set FIRETV_IP."
  exit /b 1
)

REM ---- Ensure ADB connection (retry; TV may be asleep) ----
set "CONNECTED="
for /L %%i in (1,1,8) do (
  "%ADB%" devices 2>nul | findstr /I "%FIRETV_IP%:5555" >nul
  if not errorlevel 1 (
    set "CONNECTED=1"
    goto :adb_ok
  )
  "%ADB%" connect %FIRETV_IP%:5555 >nul 2>&1
  timeout /t 1 >nul
)

:adb_ok
if not defined CONNECTED (
  %NOTIFY% -Title "Fire TV offline" -Message "ADB could not reach %FIRETV_IP%:5555. Make sure the TV is awake and ADB debugging is authorized."
  exit /b 2
)

REM ---- Toggle: if screen is ON, turn OFF and exit ----
"%ADB%" shell dumpsys power | findstr /I "mScreenOn=true" >nul
if not errorlevel 1 (
  REM Screen is ON -> turn OFF
  "%ADB%" shell input keyevent 26 >nul 2>&1
  exit /b 0
)

REM Wake + launch Spotify TV
"%ADB%" shell input keyevent 26 >nul 2>&1
"%ADB%" shell monkey -p com.spotify.tv.android 1 >nul 2>&1

REM ---- Retry Spotify transfer until device appears (up to 12 seconds) ----
set "SUCCESS="
for /L %%i in (1,1,12) do (
  py "%ROOT%\spotify_transfer.py" >nul 2>&1
  if not errorlevel 1 (
    set "SUCCESS=1"
    goto :done
  )
  timeout /t 1 >nul
)

:done
if not defined SUCCESS (
  %NOTIFY% -Title "Spotify transfer failed" -Message "TV device not found in Spotify Connect after retries. Try reopening Spotify on the TV."
  exit /b 3
)

exit /b 0
