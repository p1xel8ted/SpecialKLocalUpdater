@echo off
REM Check for verbose flag and path argument
set "VERBOSE="
set "GAMEPATH="

:parse_args
if "%~1"=="" goto run
if /i "%~1"=="-verbose" (
    set "VERBOSE=-Verbose"
    shift
    goto parse_args
)
if /i "%~1"=="-v" (
    set "VERBOSE=-Verbose"
    shift
    goto parse_args
)
REM Assume anything else is a path
set "GAMEPATH=-Path "%~1""
shift
goto parse_args

:run
if "%GAMEPATH%"=="" (
    if "%VERBOSE%"=="" (
        echo No directory provided. The script will use game_paths.txt.
    ) else (
        echo No directory provided. The script will use game_paths.txt. (Verbose mode)
    )
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update_sk.ps1" %VERBOSE% %GAMEPATH%

pause
