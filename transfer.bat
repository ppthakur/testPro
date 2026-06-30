@echo off
:: ============================================================
::  transfer.bat  —  Copy large files between Windows laptops
::  on the same WiFi using Robocopy (built into Windows 11)
::
::  HOW TO USE:
::  1. On the SOURCE laptop:
::       Right-click the folder > Properties > Sharing > Share
::       Share with "Everyone" and note the network path shown
::       e.g.  \\LAPTOP-ABC\MyFolder
::
::  2. Edit SOURCE and DEST below, then double-click this file
::     on the DESTINATION laptop.
:: ============================================================

:: ---- EDIT THESE TWO LINES ---------------------------------
set SOURCE=\\SOURCE-PC-NAME\SharedFolderName
set DEST=C:\Users\YourName\Downloads\TransferredFiles
:: -----------------------------------------------------------

echo.
echo  Copying from: %SOURCE%
echo  Copying to  : %DEST%
echo.
echo  Press Ctrl+C to cancel, or
pause

robocopy "%SOURCE%" "%DEST%" ^
  /E ^        & rem  copy all subfolders including empty ones
  /Z ^        & rem  resume-able mode (safe for large files)
  /MT:8 ^     & rem  8 parallel threads (faster on WiFi)
  /R:3 ^      & rem  retry 3 times on error
  /W:5 ^      & rem  wait 5 seconds between retries
  /ETA ^      & rem  show estimated time remaining
  /LOG:"%DEST%\transfer_log.txt" ^
  /TEE        & rem  show progress AND write log

echo.
if %ERRORLEVEL% LEQ 7 (
    echo  SUCCESS - Transfer complete!
    echo  Log saved to: %DEST%\transfer_log.txt
) else (
    echo  ERROR - Something went wrong. Check transfer_log.txt
)
echo.
pause
