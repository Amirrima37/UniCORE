$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
$sdk = Join-Path $root '.tools/engines/gmsh-4.15.2-Windows64-sdk'
$exe = Join-Path $root '.tools/engines/gmsh_sdk_test.exe'
$evidence = Join-Path $root 'docs/architecture/evidence/gmsh'
New-Item -ItemType Directory -Force $evidence | Out-Null
& 'C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe' -std=c++17 -O2 "-I$sdk/include" "$root/native/tests/gmsh_sdk_test.cpp" -o $exe
if ($LASTEXITCODE -ne 0) { throw 'Gmsh smoke compilation failed' }
Push-Location $evidence
try {
    & $exe "$sdk/lib/gmsh-4.15.dll" 2>&1 | Tee-Object -FilePath smoke.txt
    if ($LASTEXITCODE -ne 0) { throw 'Gmsh smoke execution failed' }
    Get-FileHash block.step,block.msh -Algorithm SHA256 | ConvertTo-Json | Set-Content hashes.json
} finally { Pop-Location }
