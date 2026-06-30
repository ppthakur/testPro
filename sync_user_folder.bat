@echo off
:: ============================================================
::  sync_user_folder.bat
::  Syncs user folder + WhatsApp/Telegram/Signal/etc to another
::  Windows 11 laptop on the same WiFi
::
::  SETUP (one-time on SOURCE laptop):
::  1. Share the Users folder:
::       Open CMD as Admin and run:
::         net share Users=C:\Users /grant:Everyone,READ
::
::  2. Get the SOURCE laptop name:
::       Open CMD and run:  hostname
::
::  3. Edit the 3 lines below, then right-click this file and
::     "Run as Administrator" on the DESTINATION laptop.
:: ============================================================

:: ---- EDIT THESE 3 LINES -----------------------------------
set SOURCE_PC=LAPTOP-ABC
set SOURCE_USER=Alice
set DEST=C:\Users\%USERNAME%\Restored_From_OldPC
:: -----------------------------------------------------------

set SOURCE=\\%SOURCE_PC%\Users\%SOURCE_USER%
set LOG=%DEST%\sync_log.txt

echo.
echo  =====================================================
echo   USER FOLDER + APPS SYNC
echo  =====================================================
echo   From : %SOURCE%
echo   To   : %DEST%
echo  =====================================================
echo.
echo  Will sync:
echo    [+] Desktop, Documents, Downloads
echo    [+] Pictures, Music, Videos
echo    [+] WhatsApp (messages + media)
echo    [+] Telegram, Signal, Discord, Skype
echo    [+] Zoom, Teams recordings
echo    [+] App settings (AppData\Roaming)
echo    [-] Temp, Cache, system files  (skipped)
echo.
echo  Press Ctrl+C to cancel, or any key to START...
pause > nul

mkdir "%DEST%" 2>nul
echo Sync started: %DATE% %TIME% >> "%LOG%"

:: ============================================================
::  1. STANDARD USER FOLDERS
:: ============================================================
echo.
echo [1/4] Syncing standard user folders...
for %%F in (Desktop Documents Downloads Pictures Music Videos Favorites Links Contacts Saved Games) do (
    if exist "%SOURCE%\%%F" (
        echo   - %%F
        robocopy "%SOURCE%\%%F" "%DEST%\%%F" ^
            /E /Z /MT:8 /R:3 /W:5 /ETA /XA:SH ^
            /LOG+:"%LOG%" > nul
    )
)

:: ============================================================
::  2. MESSAGING & SOCIAL APPS  (AppData\Roaming)
:: ============================================================
echo.
echo [2/4] Syncing messaging apps...

:: WhatsApp (Desktop) — messages, media, settings
if exist "%SOURCE%\AppData\Roaming\WhatsApp" (
    echo   - WhatsApp
    robocopy "%SOURCE%\AppData\Roaming\WhatsApp" "%DEST%\AppData\Roaming\WhatsApp" ^
        /E /Z /MT:8 /R:3 /W:5 ^
        /XD "Temp" "logs" ^
        /LOG+:"%LOG%" > nul
)

:: WhatsApp local data (profile pics, cache worth keeping)
if exist "%SOURCE%\AppData\Local\WhatsApp" (
    echo   - WhatsApp (local)
    robocopy "%SOURCE%\AppData\Local\WhatsApp" "%DEST%\AppData\Local\WhatsApp" ^
        /E /Z /MT:8 /R:3 /W:5 ^
        /XD "Cache" "temp" "squirrel-temp" ^
        /LOG+:"%LOG%" > nul
)

:: Telegram Desktop — full chat history stored locally
if exist "%SOURCE%\AppData\Roaming\Telegram Desktop" (
    echo   - Telegram Desktop
    robocopy "%SOURCE%\AppData\Roaming\Telegram Desktop" "%DEST%\AppData\Roaming\Telegram Desktop" ^
        /E /Z /MT:8 /R:3 /W:5 ^
        /XD "tdata\user_data\cache" "emoji" ^
        /LOG+:"%LOG%" > nul
)

:: Signal — encrypted message database
if exist "%SOURCE%\AppData\Roaming\Signal" (
    echo   - Signal
    robocopy "%SOURCE%\AppData\Roaming\Signal" "%DEST%\AppData\Roaming\Signal" ^
        /E /Z /MT:8 /R:3 /W:5 ^
        /XD "Cache" "Code Cache" "GPUCache" "logs" ^
        /LOG+:"%LOG%" > nul
)

:: Discord
if exist "%SOURCE%\AppData\Roaming\discord" (
    echo   - Discord
    robocopy "%SOURCE%\AppData\Roaming\discord" "%DEST%\AppData\Roaming\discord" ^
        /E /Z /MT:8 /R:3 /W:5 ^
        /XD "Cache" "Code Cache" "GPUCache" "CachedData" "logs" ^
        /LOG+:"%LOG%" > nul
)

:: Skype
if exist "%SOURCE%\AppData\Roaming\Skype" (
    echo   - Skype
    robocopy "%SOURCE%\AppData\Roaming\Skype" "%DEST%\AppData\Roaming\Skype" ^
        /E /Z /MT:8 /R:3 /W:5 ^
        /XD "Cache" "temp" ^
        /LOG+:"%LOG%" > nul
)

:: Viber
if exist "%SOURCE%\AppData\Roaming\ViberPC" (
    echo   - Viber
    robocopy "%SOURCE%\AppData\Roaming\ViberPC" "%DEST%\AppData\Roaming\ViberPC" ^
        /E /Z /MT:8 /R:3 /W:5 ^
        /XD "Cache" ^
        /LOG+:"%LOG%" > nul
)

:: ============================================================
::  3. VIDEO CALL & MEETING APPS
:: ============================================================
echo.
echo [3/4] Syncing meeting/recording apps...

:: Zoom — recordings and settings
if exist "%SOURCE%\Documents\Zoom" (
    echo   - Zoom recordings
    robocopy "%SOURCE%\Documents\Zoom" "%DEST%\Documents\Zoom" ^
        /E /Z /MT:8 /R:3 /W:5 ^
        /LOG+:"%LOG%" > nul
)
if exist "%SOURCE%\AppData\Roaming\Zoom" (
    echo   - Zoom settings
    robocopy "%SOURCE%\AppData\Roaming\Zoom" "%DEST%\AppData\Roaming\Zoom" ^
        /E /Z /MT:8 /R:3 /W:5 ^
        /XD "logs" "cache" ^
        /LOG+:"%LOG%" > nul
)

:: Microsoft Teams — recordings and chat data
if exist "%SOURCE%\AppData\Roaming\Microsoft\Teams" (
    echo   - Microsoft Teams
    robocopy "%SOURCE%\AppData\Roaming\Microsoft\Teams" "%DEST%\AppData\Roaming\Microsoft\Teams" ^
        /E /Z /MT:8 /R:3 /W:5 ^
        /XD "Cache" "Code Cache" "GPUCache" "logs" "tmp" ^
        /LOG+:"%LOG%" > nul
)

:: ============================================================
::  4. GENERAL APP SETTINGS (AppData\Roaming — minus big cache)
:: ============================================================
echo.
echo [4/4] Syncing general app settings...
robocopy "%SOURCE%\AppData\Roaming" "%DEST%\AppData\Roaming" ^
    /E /Z /MT:8 /R:3 /W:5 ^
    /XD "Temp" "Temporary Internet Files" "Cache" "CacheStorage" ^
         "Code Cache" "GPUCache" "CachedData" "crashpad" ^
         "squirrel-temp" "logs" "Log" ^
    /XA:SH ^
    /LOG+:"%LOG%" > nul

:: ============================================================
::  DONE
:: ============================================================
echo.
echo  =====================================================
if %ERRORLEVEL% LEQ 7 (
    echo   SUCCESS - All done!
) else (
    echo   DONE with warnings.
    echo   Some locked/in-use files may have been skipped.
    echo   This is normal - re-run to retry skipped files.
)
echo   Full log: %LOG%
echo  =====================================================
echo.
echo  NEXT STEPS on the new laptop:
echo   1. Install WhatsApp / Telegram / Signal etc.
echo   2. Copy the backed-up AppData folders to the right place:
echo      e.g. copy "%DEST%\AppData\Roaming\WhatsApp"
echo           to   "C:\Users\%USERNAME%\AppData\Roaming\WhatsApp"
echo   3. Launch the app - your data should appear.
echo.
pause
