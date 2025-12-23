@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM =========================
REM Debug flag: run.bat --debug | -d | DEBUG=1 env var
REM =========================
set "DEBUG="
if /I "%~1"=="--debug" set "DEBUG=1"
if /I "%~1"=="-d"      set "DEBUG=1"
if /I "%DEBUG%"=="1"   set "DEBUG=1"

REM Tiny logger
set "DBG_ECHO=rem"
if defined DEBUG set "DBG_ECHO=echo"

%DBG_ECHO% [!time!] BAT start

REM Repository root directory (where this .bat lives)
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

REM Notification helper (toast)
set "NOTIFY=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\notify.ps1""

REM Load env.bat (if present)
if exist "%ROOT%\env.bat" call "%ROOT%\env.bat"

REM ---- ADB location ----
set "ADB=adb"

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
    goto :after_adb_loop
  )
  "%ADB%" connect %FIRETV_IP%:5555 >nul 2>&1
  timeout /t 1 >nul
)

:after_adb_loop
if not defined CONNECTED (
  %NOTIFY% -Title "Fire TV offline" -Message "ADB could not reach %FIRETV_IP%:5555. Make sure the TV is awake and ADB debugging is authorized."
  exit /b 2
)

REM =========================
REM Screen state detection (portable)
REM sets SCREEN_ON=1 if ON/interactive, else leaves undefined
REM =========================
%DBG_ECHO% [!time!] before detect_screen
call :detect_screen
%DBG_ECHO% [!time!] after detect_screen

REM ---- If screen is OFF/unknown, try a wake-safe key first ----
if not defined SCREEN_ON (
  "%ADB%" shell input keyevent 224 >nul 2>&1
  timeout /t 1 >nul
  call :detect_screen
)

REM ---- If still OFF/unknown, last-resort toggle power ----
if not defined SCREEN_ON (
  "%ADB%" shell input keyevent 26 >nul 2>&1
  timeout /t 1 >nul
)

REM Always bring Spotify to foreground (safe if already open)
%DBG_ECHO% [!time!] before monkey (open Spotify)
"%ADB%" shell monkey -p com.spotify.tv.android 1 >nul 2>&1
%DBG_ECHO% [!time!] after monkey


REM =========================
REM Python: run once; only retry rc=2 up to 2 more times
REM =========================
set "LAST_RC="
set /a "TRY=1"

:python_run
%DBG_ECHO% [!time!] before python attempt !TRY!

if defined DEBUG (
  py "%ROOT%\spotify_transfer.py"
) else (
  py "%ROOT%\spotify_transfer.py" >nul 2>&1
)

set "LAST_RC=%errorlevel%"
%DBG_ECHO% [!time!] after python attempt !TRY! (rc=%LAST_RC%)

REM Success
if "%LAST_RC%"=="0"  goto :ok
if "%LAST_RC%"=="10" goto :ok

REM Retry only if device not found (rc=2) and tries left
if "%LAST_RC%"=="2" (
  if %TRY% LSS 3 (
    set /a "TRY+=1"
    timeout /t 1 >nul
    goto :python_run
  )
)

REM Errors -> notify
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

:ok
exit /b 0


REM =========================================================
REM FUNCTION: detect_screen
REM Tries multiple signals across dumpsys power/display/window
REM Works across many Android TV / Fire OS variants.
REM =========================================================
:detect_screen
set "SCREEN_ON="

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
