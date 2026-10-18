@echo off
setlocal
set "GAME_ENGINE=D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if not exist "%~dp0.validation" mkdir "%~dp0.validation"
echo Starting game. Keep this window open.
start "" /wait "%GAME_ENGINE%" --path "%~dp0map" --verbose --log-file "%~dp0.validation\manual-game.log"
echo Game exit code: %ERRORLEVEL%
echo Log: %~dp0.validation\manual-game.log
pause
