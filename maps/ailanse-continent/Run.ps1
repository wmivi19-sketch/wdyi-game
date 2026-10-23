param([switch]$Verify,[switch]$Compatibility,[switch]$Headless,[switch]$Sample)
$ErrorActionPreference = 'Stop'
$enginePath = Join-Path (Split-Path $PSScriptRoot -Parent) '.tools\godot-4.5.2\Godot_v4.5.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $enginePath)) {
    $godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($godotCommand) { $enginePath = $godotCommand.Source }
    else { throw 'Godot was not found. Add Godot 4.5.2 to PATH or import project.godot in the Godot editor.' }
}
$engineArgs = @('--path', $PSScriptRoot, '--log-file', (Join-Path $PSScriptRoot 'session.log'))
if ($Compatibility) { $engineArgs += @('--rendering-method','gl_compatibility') }
if ($Headless) { $engineArgs += '--headless' }
if ($Sample) { $engineArgs += @('--scene','res://main.tscn') }
if ($Verify) {
    $verifyFlag = if ($Sample) { '--verify' } else { '--world-verify' }
    $engineArgs += @('--quit-after','1200','--',$verifyFlag)
}
& $enginePath @engineArgs
exit $LASTEXITCODE
