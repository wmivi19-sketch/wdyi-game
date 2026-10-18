@echo off
setlocal
set "GODOT_EXE=D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if not exist "%GODOT_EXE%" (
  echo Godot executable was not found. Open map\project.godot with Godot 4.3 or newer.
  pause
  exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0map"
