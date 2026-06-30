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
set LOG=%TEMP%\sync_log.txt
set SUMMARY=%TEMP%\sync_summary.txt

echo.
echo  =====================================================
echo   USER FOLDER + APPS SYNC  (with logging)
echo  =====================================================
echo   From : %SOURCE%
echo   To   : %DEST%
echo  =====================================================
echo.

:: ---- Step 1: Check source PC is reachable on WiFi ----------
echo  [CHECK] Pinging %SOURCE_PC%...
ping -n 2 %SOURCE_PC% >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  =====================================================
    echo   ERROR: Cannot reach %SOURCE_PC% on the network!
    echo  =====================================================
    echo.
    echo  Possible causes:
    echo    1. SOURCE_PC name is wrong  ^(run: hostname  on source^)
    echo    2. Both laptops not on same WiFi router
    echo    3. Firewall blocking on source laptop
    echo    4. Source laptop is asleep/off
    echo.
    echo  Fix on SOURCE laptop ^(Admin CMD^):
    echo    netsh advfirewall firewall add rule name="Allow Ping" ^
    echo      protocol=icmpv4 dir=in action=allow
    echo.
    pause
    exit /b 1
)
echo  [OK]    %SOURCE_PC% is reachable.

:: ---- Step 2: Check shared folder is accessible -------------
echo  [CHECK] Accessing shared folder %SOURCE%...
if not exist "%SOURCE%" (
    echo.
    echo  =====================================================
    echo   ERROR: Cannot access %SOURCE%
    echo  =====================================================
    echo.
    echo  Fix on SOURCE laptop ^(Admin CMD^):
    echo    net share Users=C:\Users /grant:Everyone,READ
    echo.
    echo  Also check the username is correct:
    echo    Current value: SOURCE_USER=%SOURCE_USER%
    echo    Actual users on source: dir \\%SOURCE_PC%\Users
    echo.
    pause
    exit /b 1
)
echo  [OK]    Shared folder is accessible.
echo.

:: ---- Step 3: Create destination ----------------------------
mkdir "%DEST%" 2>nul
if not exist "%DEST%" (
    echo  ERROR: Cannot create destination folder: %DEST%
    pause
    exit /b 1
)

:: Move log files into DEST now that it exists
set LOG=%DEST%\sync_log.txt
set SUMMARY=%DEST%\sync_summary.txt

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
echo  Window will close in 15 seconds...
timeout /t 15 /nokey > nul
