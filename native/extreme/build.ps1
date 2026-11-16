param([switch]$Debug,[switch]$NoOpenMP,[string]$Compiler="")
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

if (-not $Compiler) {
    $candidates = @(
        $env:CXX,
        "C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe",
        "C:/msys64/ucrt64/bin/g++.exe",
        "C:/msys64/mingw64/bin/g++.exe",
        "D:/msys64/ucrt64/bin/g++.exe",
        "D:/msys64/mingw64/bin/g++.exe",
        (Get-Command "x86_64-w64-mingw32-g++" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
        (Get-Command "g++" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    )
    foreach ($cand in $candidates) {
        if ($cand -and (Test-Path $cand) -and (Get-Item $cand).Length -gt 0) {
            $Compiler = $cand
            break
        }
    }
}

if (-not $Compiler) {
    throw "C++ compiler (x86_64-w64-mingw32-g++ / g++) not found. Please install MinGW-w64 / GCC or specify -Compiler path."
}

$binDir = Join-Path $root 'bin'
if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Force -Path $binDir | Out-Null }

$flags=@('-std=c++17','-municode','-static','-ffp-contract=off',('-I'+$root+'/native/src'))
$name='unicore_solver.exe'
if($Debug){$flags+=@('-O0','-g');$name='unicore_solver_debug.exe'}else{$flags+='-O2'}
if(-not $NoOpenMP){$flags+='-fopenmp'}else{$name=$name.Replace('.exe','_noomp.exe')}
& $Compiler @flags ($PSScriptRoot+'/main.cpp') '-lpsapi' '-lbcrypt' '-o' (Join-Path $binDir $name)
if($LASTEXITCODE -ne 0){throw 'Standalone build failed'}
