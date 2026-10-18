@echo off
setlocal
chcp 65001 >nul
set "GAME_ENGINE=D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
set "GAME_PROJECT=%~dp0map"
if not exist "%GAME_ENGINE%" (
  echo 找不到 Godot，请从 Godot 编辑器导入 map\project.godot 后按 F5 运行。
  pause
  exit /b 1
)
if not exist "%~dp0.validation" mkdir "%~dp0.validation"
echo 正在启动游戏，请在游戏窗口点击“新游戏”。
echo 此窗口会保留运行日志，游戏关闭后请查看末尾的错误信息。
start "" /wait "%GAME_ENGINE%" --path "%GAME_PROJECT%" --verbose --log-file "%~dp0.validation\manual-game.log"
set "GAME_EXIT=%ERRORLEVEL%"
echo.
echo 游戏已结束，退出码：%GAME_EXIT%
echo 日志：%~dp0.validation\manual-game.log
pause
exit /b %GAME_EXIT%
