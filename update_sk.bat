@echo off
REM Check if an argument is provided
if "%~1"=="" (
    echo No directory provided. The script will use game_paths.txt.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update_sk.ps1"
) else (
    REM Set the folder path and pass it to the PowerShell script
    set "FolderPath=%~1"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update_sk.ps1" "%FolderPath%"
)

pause
