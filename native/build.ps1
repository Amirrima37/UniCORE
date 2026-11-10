param(
    [string]$Python = "python",
    [string]$CompilerBin = "",
    [string]$Cxx = "",
    [ValidateSet("template_debug", "template_release")][string]$Target = "template_debug",
    [int]$Jobs = 8
)
$ErrorActionPreference = "Stop"
$taskRoot = Split-Path $PSScriptRoot -Parent
if ($CompilerBin) { $env:PATH = $CompilerBin + ";" + $env:PATH }
if ($Cxx) { $env:UNICORE_CXX = $Cxx }
$env:PYTHONPATH = Join-Path $taskRoot ".tools/python-packages"
Push-Location $PSScriptRoot
try {
    & $Python -m SCons platform=windows arch=x86_64 use_mingw=yes "target=$Target" "-j$Jobs"
    if ($LASTEXITCODE -ne 0) { throw "Native build failed" }
    $debugDll = Join-Path $taskRoot "bin/windows/x86_64/unicore_native.windows.template_debug.x86_64.dll"
    $releaseDll = Join-Path $taskRoot "bin/windows/x86_64/unicore_native.windows.template_release.x86_64.dll"
    # Activate only when both configurations exist: clean script-only source checkout has no descriptor.
    if ((Test-Path $debugDll) -and (Test-Path $releaseDll)) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot "unicore_native.gdextension.in") -Destination (Join-Path $taskRoot "bin/unicore_native.gdextension")
    }
} finally { Pop-Location }
