@echo off
setlocal

cd /d "%~dp0"

set "PS_CMD="
where powershell >nul 2>nul
if %ERRORLEVEL%==0 set "PS_CMD=powershell"

if not defined PS_CMD (
  where pwsh >nul 2>nul
  if %ERRORLEVEL%==0 set "PS_CMD=pwsh"
)

if not defined PS_CMD (
  echo [ERROR] PowerShell was not found on this Windows computer.
  pause
  exit /b 1
)

%PS_CMD% -NoProfile -ExecutionPolicy Bypass -File "%~dp0start_server_windows.ps1"

if %ERRORLEVEL% NEQ 0 (
  echo [ERROR] Local server stopped with an error.
  pause
  exit /b 1
)

endlocal
