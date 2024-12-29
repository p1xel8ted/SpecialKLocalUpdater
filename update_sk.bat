@echo off
REM Check if an argument is provided
if "%~1"=="" (
    echo Please drag and drop a folder onto this batch file.
    pause
    exit /b 1
)

REM Set the folder path and pass it to the PowerShell script
set "FolderPath=%~1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update_sk.ps1" "%FolderPath%"
pause
