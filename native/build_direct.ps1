param(
    [ValidateSet('template_debug','template_release')][string]$Target='template_debug',
    [string]$Compiler=""
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent

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
$cxx = $Compiler
$flags=@('-std=c++17','-O2','-ffp-contract=off','-fPIC',('-I'+$root+'/native/src'),('-I'+$root+'/native/godot-cpp/include'),('-I'+$root+'/native/godot-cpp/gen/include'),('-I'+$root+'/native/godot-cpp/gdextension'))
if($Target -eq 'template_debug'){$flags+=@('-DDEBUG_ENABLED','-DDEBUG_METHODS_ENABLED')}
$objects=@()
$objectDir=Join-Path $root ".tools/cae-build-$Target"
New-Item -ItemType Directory -Force $objectDir | Out-Null
foreach($source in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'src/bindings') -Filter '*.cpp') {
 $obj=Join-Path $objectDir ($source.BaseName+'.o')
 & $cxx @flags -c $source.FullName -o $obj
 if($LASTEXITCODE -ne 0){throw "Compile failed: $($source.Name)"}
 $objects+=$obj
}
$output=Join-Path $root "bin/windows/x86_64/unicore_native.windows.$Target.x86_64.dll"
& $cxx -shared -static -static-libgcc -static-libstdc++ @objects "-L$root/native/godot-cpp/bin" "-lgodot-cpp.windows.$Target.x86_64" -o $output
if($LASTEXITCODE -ne 0){throw 'Link failed'}

