@echo off
setlocal EnableDelayedExpansion

cd /d "%~dp0"
set "START_PORT=5500"
set "MAX_TRIES=50"

set "PY_CMD="
where py >nul 2>nul
if %ERRORLEVEL%==0 set "PY_CMD=py -3"
if not defined PY_CMD (
  where python >nul 2>nul
  if %ERRORLEVEL%==0 set "PY_CMD=python"
)
if not defined PY_CMD (
  where python3 >nul 2>nul
  if %ERRORLEVEL%==0 set "PY_CMD=python3"
)
if not defined PY_CMD (
  echo [ERROR] Python не найден. Установите Python 3 и добавьте его в PATH.
  pause
  exit /b 1
)

echo [INFO] Использую: %PY_CMD%

set /a TRY=0
:TRY_PORT
set /a PORT=%START_PORT%+%TRY%

netstat -ano | findstr /R /C:":!PORT! .*LISTENING" >nul 2>nul
if !ERRORLEVEL! EQU 0 (
  set /a TRY+=1
  if !TRY! GEQ %MAX_TRIES% (
    echo [ERROR] Не найден свободный порт в диапазоне %START_PORT%..%START_PORT%+%MAX_TRIES%-1.
    pause
    exit /b 1
  )
  goto TRY_PORT
)

echo [INFO] Запуск на порту !PORT!
start "" "http://localhost:!PORT!/index.html"
%PY_CMD% -m http.server !PORT!

if %ERRORLEVEL% NEQ 0 (
  echo [ERROR] Сервер завершился с ошибкой.
  pause
  exit /b 1
)

endlocal
