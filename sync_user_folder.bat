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
set SOURCE_PC=10.5.48.96
set SOURCE_USER=Admin
set DEST=C:\Users\Astha\Documents\Backup0726
:: -----------------------------------------------------------

:: Map source drive using credentials (avoids network share access issues)
net use Z: \\%SOURCE_PC%\Users /user:%SOURCE_USER% /persistent:no 2>nul
if %ERRORLEVEL% NEQ 0 (
    :: Already mapped or needs password — try with empty password
    net use Z: \\%SOURCE_PC%\Users /user:%SOURCE_USER% "" /persistent:no 2>nul
)
set SOURCE=Z:\%SOURCE_USER%
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
echo    [+] AppData\Roaming  (ALL apps: WhatsApp, Telegram, Signal, etc.)
echo    [+] AppData\Local    (WhatsApp local, browser profiles, etc.)
echo    [+] AppData\LocalLow (browser data, other apps)
echo    [-] Temp, Cache, GPUCache, crashpad  (skipped to save space)
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
    :: %1 = label  %2 = source dir  %3 = dest dir
    call :LOG "START: %~1"
    robocopy "%~2" "%~3" /E /Z /MT:8 /R:3 /W:5 /NP /BYTES /XD "Temp" "temp" "Cache" "cache" "CacheStorage" "Code Cache" "GPUCache" "CachedData" "crashpad" "squirrel-temp" "logs" "Log" /XA:SH /LOG+:"%LOG%"
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
::  2. APPDATA\ROAMING  (all apps — WhatsApp, Telegram, etc.)
:: ============================================================
call :LOG "------ [2/4] AppData\Roaming (all apps) ------"
echo. >> "%SUMMARY%"
echo [2/4] AppData\Roaming >> "%SUMMARY%"
echo   Syncing AppData\Roaming (all apps including WhatsApp, Telegram, Signal...)
call :ROBOSYNC "AppData-Roaming" "%SOURCE%\AppData\Roaming" "%DEST%\AppData\Roaming"

:: ============================================================
::  3. APPDATA\LOCAL  (WhatsApp local, other local app data)
:: ============================================================
call :LOG "------ [3/4] AppData\Local ------"
echo. >> "%SUMMARY%"
echo [3/4] AppData\Local >> "%SUMMARY%"
echo   Syncing AppData\Local...
call :ROBOSYNC "AppData-Local" "%SOURCE%\AppData\Local" "%DEST%\AppData\Local"

:: WhatsApp UWP (Microsoft Store version) — stored in Packages
echo   Syncing WhatsApp UWP (Store version)...
call :ROBOSYNC "WhatsApp-UWP" "%SOURCE%\AppData\Local\Packages\5319275A.WhatsAppDesktop_cv1g1gvanyjgm\LocalState" "%DEST%\AppData\Local\Packages\5319275A.WhatsAppDesktop_cv1g1gvanyjgm\LocalState"

:: ============================================================
::  4. APPDATA\LOCALLOW  (browser data, other low-integrity apps)
:: ============================================================
call :LOG "------ [4/4] AppData\LocalLow ------"
echo. >> "%SUMMARY%"
echo [4/4] AppData\LocalLow >> "%SUMMARY%"
echo   Syncing AppData\LocalLow...
call :ROBOSYNC "AppData-LocalLow" "%SOURCE%\AppData\LocalLow" "%DEST%\AppData\LocalLow"

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
echo.
echo  *** SYNC FINISHED - window closes in 30 seconds ***
timeout /t 30 /nokey > nul
