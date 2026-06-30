@echo off
:: ============================================================
::  sync_user_folder.bat
::  Syncs user folder + WhatsApp/Telegram/Signal/etc to another
::  Windows 11 laptop on the same WiFi — with detailed logging
::
::  SETUP (one-time on SOURCE laptop):
::  1. Open CMD as Admin and run:
::       net share Users=C:\Users /grant:Everyone,READ
::  2. Get the source laptop name:
::       hostname
::  3. Edit the 3 lines below, right-click this file and
::     "Run as Administrator" on the DESTINATION laptop.
:: ============================================================

:: ---- EDIT THESE 3 LINES -----------------------------------
set SOURCE_PC=LAPTOP-ABC
set SOURCE_USER=Alice
set DEST=C:\Users\%USERNAME%\Restored_From_OldPC
:: -----------------------------------------------------------

set SOURCE=\\%SOURCE_PC%\Users\%SOURCE_USER%
set LOG=%DEST%\sync_log.txt
set SUMMARY=%DEST%\sync_summary.txt

echo.
echo  =====================================================
echo   USER FOLDER + APPS SYNC  (with logging)
echo  =====================================================
echo   From : %SOURCE%
echo   To   : %DEST%
echo   Log  : %LOG%
echo  =====================================================
echo.
echo  Will sync:
echo    [+] Desktop, Documents, Downloads
echo    [+] Pictures, Music, Videos
echo    [+] WhatsApp, Telegram, Signal, Discord, Skype, Viber
echo    [+] Zoom, Microsoft Teams
echo    [+] General app settings (AppData\Roaming)
echo    [-] Temp, Cache, system files  (skipped)
echo.
echo  Press Ctrl+C to cancel, or any key to START...
pause > nul

mkdir "%DEST%" 2>nul

:: ---- Logger function (writes timestamped line to log) ------
:: Usage: call :LOG "message"
goto :MAIN

:LOG
    set MSG=%~1
    echo [%DATE% %TIME%]  %MSG%
    echo [%DATE% %TIME%]  %MSG% >> "%LOG%"
    goto :EOF

:ROBOSYNC
    :: %1 = label  %2 = source dir  %3 = dest dir  %4 = extra /XD args (optional)
    call :LOG "START: %~1"
    robocopy "%~2" "%~3" ^
        /E /Z /MT:8 /R:3 /W:5 /NP /BYTES ^
        /XD "Temp" "temp" "Cache" "cache" "CacheStorage" "Code Cache" ^
             "GPUCache" "CachedData" "crashpad" "squirrel-temp" ^
             "logs" "Log" %~4 ^
        /XA:SH ^
        /LOG+:"%LOG%"
    set RC=%ERRORLEVEL%
    if %RC% LEQ 7 (
        call :LOG "OK:    %~1  (exit code %RC%)"
        echo   [OK] %~1 >> "%SUMMARY%"
    ) else (
        call :LOG "WARN:  %~1  (exit code %RC% - some files may be skipped)"
        echo   [WARN] %~1  exit code %RC% >> "%SUMMARY%"
    )
    goto :EOF

:MAIN
:: ---- Init log files ----------------------------------------
echo. > "%LOG%"
echo. > "%SUMMARY%"
call :LOG "======================================================"
call :LOG "SYNC SESSION STARTED"
call :LOG "Source : %SOURCE%"
call :LOG "Dest   : %DEST%"
call :LOG "======================================================"
echo ====================================================== >> "%SUMMARY%"
echo  SYNC SUMMARY  %DATE% %TIME% >> "%SUMMARY%"
echo  From: %SOURCE% >> "%SUMMARY%"
echo  To  : %DEST% >> "%SUMMARY%"
echo ====================================================== >> "%SUMMARY%"

:: ============================================================
::  1. STANDARD USER FOLDERS
:: ============================================================
call :LOG "------ [1/4] Standard User Folders ------"
echo. >> "%SUMMARY%"
echo [1/4] Standard User Folders >> "%SUMMARY%"

for %%F in (Desktop Documents Downloads Pictures Music Videos Favorites Links Contacts Saved Games) do (
    if exist "%SOURCE%\%%F" (
        echo   Syncing %%F...
        call :ROBOSYNC "%%F" "%SOURCE%\%%F" "%DEST%\%%F"
    )
)

:: ============================================================
::  2. MESSAGING & SOCIAL APPS
:: ============================================================
call :LOG "------ [2/4] Messaging Apps ------"
echo. >> "%SUMMARY%"
echo [2/4] Messaging Apps >> "%SUMMARY%"

if exist "%SOURCE%\AppData\Roaming\WhatsApp" (
    echo   Syncing WhatsApp...
    call :ROBOSYNC "WhatsApp" "%SOURCE%\AppData\Roaming\WhatsApp" "%DEST%\AppData\Roaming\WhatsApp"
)
if exist "%SOURCE%\AppData\Local\WhatsApp" (
    echo   Syncing WhatsApp (local)...
    call :ROBOSYNC "WhatsApp-local" "%SOURCE%\AppData\Local\WhatsApp" "%DEST%\AppData\Local\WhatsApp"
)
if exist "%SOURCE%\AppData\Roaming\Telegram Desktop" (
    echo   Syncing Telegram...
    call :ROBOSYNC "Telegram" "%SOURCE%\AppData\Roaming\Telegram Desktop" "%DEST%\AppData\Roaming\Telegram Desktop" "\"emoji\""
)
if exist "%SOURCE%\AppData\Roaming\Signal" (
    echo   Syncing Signal...
    call :ROBOSYNC "Signal" "%SOURCE%\AppData\Roaming\Signal" "%DEST%\AppData\Roaming\Signal"
)
if exist "%SOURCE%\AppData\Roaming\discord" (
    echo   Syncing Discord...
    call :ROBOSYNC "Discord" "%SOURCE%\AppData\Roaming\discord" "%DEST%\AppData\Roaming\discord"
)
if exist "%SOURCE%\AppData\Roaming\Skype" (
    echo   Syncing Skype...
    call :ROBOSYNC "Skype" "%SOURCE%\AppData\Roaming\Skype" "%DEST%\AppData\Roaming\Skype"
)
if exist "%SOURCE%\AppData\Roaming\ViberPC" (
    echo   Syncing Viber...
    call :ROBOSYNC "Viber" "%SOURCE%\AppData\Roaming\ViberPC" "%DEST%\AppData\Roaming\ViberPC"
)

:: ============================================================
::  3. MEETING & RECORDING APPS
:: ============================================================
call :LOG "------ [3/4] Meeting Apps ------"
echo. >> "%SUMMARY%"
echo [3/4] Meeting Apps >> "%SUMMARY%"

if exist "%SOURCE%\Documents\Zoom" (
    echo   Syncing Zoom recordings...
    call :ROBOSYNC "Zoom-recordings" "%SOURCE%\Documents\Zoom" "%DEST%\Documents\Zoom"
)
if exist "%SOURCE%\AppData\Roaming\Zoom" (
    echo   Syncing Zoom settings...
    call :ROBOSYNC "Zoom-settings" "%SOURCE%\AppData\Roaming\Zoom" "%DEST%\AppData\Roaming\Zoom"
)
if exist "%SOURCE%\AppData\Roaming\Microsoft\Teams" (
    echo   Syncing Microsoft Teams...
    call :ROBOSYNC "Teams" "%SOURCE%\AppData\Roaming\Microsoft\Teams" "%DEST%\AppData\Roaming\Microsoft\Teams"
)

:: ============================================================
::  4. GENERAL APP SETTINGS
:: ============================================================
call :LOG "------ [4/4] General AppData\Roaming ------"
echo. >> "%SUMMARY%"
echo [4/4] General AppData\Roaming >> "%SUMMARY%"
echo   Syncing general app settings...
robocopy "%SOURCE%\AppData\Roaming" "%DEST%\AppData\Roaming" ^
    /E /Z /MT:8 /R:3 /W:5 /NP /BYTES ^
    /XD "Temp" "temp" "Cache" "cache" "CacheStorage" "Code Cache" ^
         "GPUCache" "CachedData" "crashpad" "squirrel-temp" ^
         "logs" "Log" "Temporary Internet Files" ^
    /XA:SH ^
    /LOG+:"%LOG%"
if %ERRORLEVEL% LEQ 7 (
    echo   [OK] AppData\Roaming >> "%SUMMARY%"
    call :LOG "OK:   AppData\Roaming"
) else (
    echo   [WARN] AppData\Roaming >> "%SUMMARY%"
    call :LOG "WARN: AppData\Roaming"
)

:: ============================================================
::  DONE
:: ============================================================
call :LOG "======================================================"
call :LOG "SYNC SESSION COMPLETE"
call :LOG "======================================================"
echo. >> "%SUMMARY%"
echo ====================================================== >> "%SUMMARY%"
echo  SYNC COMPLETE  %DATE% %TIME% >> "%SUMMARY%"
echo ====================================================== >> "%SUMMARY%"

echo.
echo  =====================================================
echo   SYNC COMPLETE
echo  =====================================================
echo   Full log    : %LOG%
echo   Summary     : %SUMMARY%
echo  =====================================================
echo.
echo  --- SUMMARY PREVIEW ---
type "%SUMMARY%"
echo.
echo  NEXT STEPS on the new laptop:
echo   1. Install WhatsApp / Telegram / Signal / Discord etc.
echo   2. Copy backed-up AppData folders to:
echo      C:\Users\%USERNAME%\AppData\Roaming\
echo   3. Launch each app - your data will appear.
echo.
timeout /t 10 /nokey > nul
