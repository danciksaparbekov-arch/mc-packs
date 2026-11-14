@echo off
chcp 65001 >nul
title Sladkiy Baklazhanchik - emotes
echo.
echo Скачиваю скрипт установки эмоций...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/danciksaparbekov-arch/mc-packs/main/client/install-emotes.ps1' -OutFile \"$env:TEMP\mc-install-emotes.ps1\" } catch { exit 1 }"
if errorlevel 1 (
  echo Не удалось скачать скрипт. Проверь интернет и попробуй ещё раз.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\mc-install-emotes.ps1"
