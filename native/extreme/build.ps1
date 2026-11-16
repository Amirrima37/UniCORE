param([switch]$Debug,[switch]$NoOpenMP)
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$compiler='C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe'
$flags=@('-std=c++17','-municode','-static','-ffp-contract=off',('-I'+$root+'/native/src'))
$name='unicore_solver.exe'
if($Debug){$flags+=@('-O0','-g');$name='unicore_solver_debug.exe'}else{$flags+='-O2'}
if(-not $NoOpenMP){$flags+='-fopenmp'}else{$name=$name.Replace('.exe','_noomp.exe')}
& $compiler @flags ($PSScriptRoot+'/main.cpp') '-lpsapi' '-lbcrypt' '-o' ($root+'/bin/'+$name)
if($LASTEXITCODE -ne 0){throw 'Standalone build failed'}
