@echo off
setlocal
set "GODOT_EXE=Z:\soft\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  echo Godot 4.7.2 was not found at:
  echo %GODOT_EXE%
  echo Please update GODOT_EXE in this file to your existing Godot path.
  pause
  exit /b 1
)
if not exist "%~dp0tests\logs" mkdir "%~dp0tests\logs"
start "" "%GODOT_EXE%" --path "%~dp0." --log-file "%~dp0tests\logs\play.log"
