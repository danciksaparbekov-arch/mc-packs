@echo off
chcp 65001 >nul
title Sladkiy Baklazhanchik - install
echo.
echo Скачиваю скрипт установки...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/danciksaparbekov-arch/mc-packs/main/client/setup-extras.ps1' -OutFile \"$env:TEMP\mc-setup-extras.ps1\" } catch { exit 1 }"
if errorlevel 1 (
  echo Не удалось скачать скрипт. Проверь интернет и попробуй ещё раз.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\mc-setup-extras.ps1" -SearchDir "%~dp0."
