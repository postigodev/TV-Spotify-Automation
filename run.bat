@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Repository root directory (where this .bat lives)
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

REM Notification helper (toast)
set "NOTIFY=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\notify.ps1""

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

REM =========================
REM Screen state detection (portable)
REM sets SCREEN_ON=1 if ON/interactive, else leaves undefined
REM =========================
call :detect_screen

REM ---- If screen is OFF/unknown, try a wake-safe key first ----
if not defined SCREEN_ON (
  REM Try WAKEUP (doesn't usually toggle off if already on)
  "%ADB%" shell input keyevent 224 >nul 2>&1
  timeout /t 1 >nul

  REM Re-check
  call :detect_screen
)

REM ---- If still OFF/unknown, last-resort toggle power ----
if not defined SCREEN_ON (
  "%ADB%" shell input keyevent 26 >nul 2>&1
  timeout /t 1 >nul
)

REM Always bring Spotify to foreground (safe if already open)
"%ADB%" shell monkey -p com.spotify.tv.android 1 >nul 2>&1

REM ---- Run Spotify toggle/transfer with smart retry ----
REM Behavior:
REM  - exit 10: paused (success, no retry)
REM  - exit 0 : playing on TV (success)
REM  - exit 2 : TV device not found yet -> retry
REM  - else   : error -> notify
set "SUCCESS="
set "LAST_RC="

for /L %%i in (1,1,12) do (
  py "%ROOT%\spotify_transfer.py" >nul 2>&1
  set "LAST_RC=!errorlevel!"

  if "!LAST_RC!"=="10" (
    set "SUCCESS=1"
    goto :done
  )

  if "!LAST_RC!"=="0" (
    set "SUCCESS=1"
    goto :done
  )

  if "!LAST_RC!"=="2" (
    REM Device not visible yet, keep retrying
    timeout /t 1 >nul
  ) else (
    REM Any other error is not retryable
    goto :done
  )
)

:done
if not defined SUCCESS (
  if "%LAST_RC%"=="1" (
    %NOTIFY% -Title "Spotify credentials missing" -Message "Set SPOTIPY_CLIENT_ID / SPOTIPY_CLIENT_SECRET / SPOTIPY_REDIRECT_URI."
    exit /b 1
  )

  if "%LAST_RC%"=="2" (
    %NOTIFY% -Title "Spotify transfer failed" -Message "TV device not found in Spotify Connect after retries."
    exit /b 3
  )

  %NOTIFY% -Title "Spotify error" -Message "spotify_transfer.py failed (exit code %LAST_RC%)."
  exit /b 4
)

exit /b 0


REM =========================================================
REM FUNCTION: detect_screen
REM Tries multiple signals across dumpsys power/display/window
REM Works across many Android TV / Fire OS variants.
REM =========================================================
:detect_screen
set "SCREEN_ON="

REM 1) dumpsys power (common Android signals)
for %%P in (
  "mInteractive=true"
  "mScreenOn=true"
  "Display Power: state=ON"
  "mWakefulness=Awake"
  "mWakefulness=Dreaming"
  "WindowManager (screen-bright"
  "screen-bright"
) do (
  "%ADB%" shell dumpsys power 2>nul | findstr /I %%P >nul && (
    set "SCREEN_ON=1"
    goto :eof
  )
)

REM 2) dumpsys display (some TV builds)
for %%D in (
  "mScreenState=ON"
  "STATE_ON"
  "state=ON"
) do (
  "%ADB%" shell dumpsys display 2>nul | findstr /I %%D >nul && (
    set "SCREEN_ON=1"
    goto :eof
  )
)

REM 3) dumpsys window (often helpful on TVs)
for %%W in (
  "mAwake=true"
  "mScreenOnFully=true"
  "screenState=ON"
  "WindowManager (screen-bright"
  "screen-bright"
) do (
  "%ADB%" shell dumpsys window 2>nul | findstr /I %%W >nul && (
    set "SCREEN_ON=1"
    goto :eof
  )
)

goto :eof
