@echo off
:: ============================================================
::  sync_user_folder.bat
::  Syncs YOUR user folder to another Windows 11 laptop on WiFi
::
::  SETUP (one-time):
::  1. SOURCE laptop: Share your user folder
::       Open Run (Win+R) > type: \\localhost
::       OR go to C:\Users\YourName
::       Right-click > Properties > Sharing > Advanced Sharing
::       Check "Share this folder" > Permissions > Allow Everyone
::
::  2. Find SOURCE laptop name:
::       Win+R > type: cmd > run: hostname
::
::  3. Edit the 3 lines below, then double-click this file
::     on the DESTINATION laptop (run as Administrator)
:: ============================================================

:: ---- EDIT THESE 3 LINES -----------------------------------
set SOURCE_PC=LAPTOP-ABC
set SOURCE_USER=Alice
set DEST=C:\Users\%USERNAME%\Restored_From_OldPC
:: -----------------------------------------------------------

set SOURCE=\\%SOURCE_PC%\Users\%SOURCE_USER%

echo.
echo  =====================================================
echo   USER FOLDER SYNC
echo  =====================================================
echo   From : %SOURCE%
echo   To   : %DEST%
echo  =====================================================
echo.
echo  This will sync:
echo    Documents, Desktop, Downloads, Pictures,
echo    Music, Videos, Favorites, AppData\Roaming
echo.
echo  Skipping: system/temp/cache files (not needed)
echo.
echo  Press Ctrl+C to cancel, or any key to START...
pause > nul

:: Create destination
mkdir "%DEST%" 2>nul

:: ---- Sync each important folder individually ---------------
:: (safer than syncing all of C:\Users\name which has locked files)

for %%F in (Desktop Documents Downloads Pictures Music Videos Favorites Links Contacts) do (
    if exist "%SOURCE%\%%F" (
        echo.
        echo  Syncing %%F ...
        robocopy "%SOURCE%\%%F" "%DEST%\%%F" ^
            /E /Z /MT:8 /R:3 /W:5 /ETA ^
            /XA:SH ^
            /LOG+:"%DEST%\sync_log.txt" /TEE
    )
)

:: Sync AppData\Roaming (browser profiles, app settings)
echo.
echo  Syncing AppData\Roaming (app settings^) ...
robocopy "%SOURCE%\AppData\Roaming" "%DEST%\AppData\Roaming" ^
    /E /Z /MT:8 /R:3 /W:5 ^
    /XD "Temp" "Cache" "CacheStorage" "Code Cache" "GPUCache" ^
    /XA:SH ^
    /LOG+:"%DEST%\sync_log.txt" /TEE

:: ---- Done -------------------------------------------------
echo.
echo  =====================================================
if %ERRORLEVEL% LEQ 7 (
    echo   SUCCESS - Sync complete!
) else (
    echo   WARNING - Some files may have been skipped.
    echo   This is normal for files in use.
)
echo   Full log: %DEST%\sync_log.txt
echo  =====================================================
echo.
pause
