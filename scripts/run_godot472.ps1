param(
    [string]$Engine = 'D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe',
    [string]$PythonExe = '',
    [switch]$VerifyOnly,
    [switch]$TestEnvironment
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path -LiteralPath $Engine -PathType Leaf)) {
    throw "Godot executable missing: $Engine"
}
$expected = 'AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424'
$actual = (Get-FileHash -LiteralPath $Engine -Algorithm SHA256).Hash
if ($actual -ne $expected) {
    throw "Godot executable hash mismatch: $actual"
}
if ($PythonExe) {
    if (-not (Test-Path -LiteralPath $PythonExe -PathType Leaf)) {
        throw "Python executable missing: $PythonExe"
    }
    $env:UNICORE_PYTHON = (Resolve-Path -LiteralPath $PythonExe).Path
}
if ($VerifyOnly) {
    Write-Output "Verified Godot 4.7.2: $actual"
    exit 0
}
if ($TestEnvironment) {
    $taskPython=$PythonExe
    if (-not $taskPython) {$taskPython='C:/Users/Victus/AppData/Local/Python/pythoncore-3.14-64/python.exe'}
    $taskProfile=& $taskPython "$root/scripts/engines/development_paths.py" godot
    $env:APPDATA=Join-Path $taskProfile 'roaming'
    $env:LOCALAPPDATA=Join-Path $taskProfile 'local'
}
& $Engine --path $root
exit $LASTEXITCODE
