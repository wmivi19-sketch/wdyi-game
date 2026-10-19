$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotExe = 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
if (-not (Test-Path -LiteralPath $godotExe)) {
    throw 'Godot executable was not found. Update $godotExe in this script.'
}
# Explicitly run the formal menu, regardless of the editor's current scene.
& $godotExe --path $projectRoot --scene res://scenes/ui/main_menu.tscn
