@echo off

SETLOCAL ENABLEEXTENSIONS

REM Check if the script is running as admin.
openfiles >nul 2>&1

REM Restart script as admin.
if '%errorlevel%' neq '0' (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

set "work=%~dp0"
set "scriptPath=%work%8mb.ps1"
set "baseKey=HKEY_CLASSES_ROOT\SystemFileAssociations\.mp4\shell\Compress"
set "shellKey=%baseKey%\shell"

reg add "%baseKey%" /ve /d "" /f
reg add "%baseKey%" /v SubCommands /d "" /f
reg add "%baseKey%" /v MUIVerb /d "Compress" /f

reg add "%shellKey%\a_8MB" /ve /d "8 MB" /f
reg add "%shellKey%\a_8MB\command" /ve /d "powershell -ExecutionPolicy Bypass -File \"%scriptPath%\" \"%%1\" 8 MB 0.5 24 -Shell" /f

reg add "%shellKey%\b_25MB" /ve /d "25 MB" /f
reg add "%shellKey%\b_25MB\command" /ve /d "powershell -ExecutionPolicy Bypass -File \"%scriptPath%\" \"%%1\" 25 MB 0.75 30 -Shell" /f

reg add "%shellKey%\c_50MB" /ve /d "50 MB" /f
reg add "%shellKey%\c_50MB\command" /ve /d "powershell -ExecutionPolicy Bypass -File \"%scriptPath%\" \"%%1\" 50 MB 0.75 30 -Shell" /f

reg add "%shellKey%\d_100MB" /ve /d "100 MB" /f
reg add "%shellKey%\d_100MB\command" /ve /d "powershell -ExecutionPolicy Bypass -File \"%scriptPath%\" \"%%1\" 100 MB -Shell" /f

reg add "%shellKey%\e_Custom" /ve /d "Custom" /f
reg add "%shellKey%\e_Custom\command" /ve /d "powershell -ExecutionPolicy Bypass -File \"%scriptPath%\" \"%%1\" -Prompt" /f

ENDLOCAL