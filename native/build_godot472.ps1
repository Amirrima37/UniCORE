param([ValidateSet('template_debug','template_release')][string]$Target='template_debug')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$cpp=Join-Path $root '.tools/godot-cpp-4.7'
$revision=& git -C $cpp rev-parse HEAD
if($LASTEXITCODE -ne 0 -or $revision -ne '2a4c066e1e8c121046e9d35fe91cc8e726861c48'){throw 'Unexpected godot-cpp revision'}
$cxx='C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe'
$flags=@('-std=c++17','-O2','-ffp-contract=off','-fPIC',('-I'+$root+'/native/src'),('-I'+$cpp+'/include'),('-I'+$cpp+'/gen/include'),('-I'+$cpp+'/gdextension'))
if($Target -eq 'template_debug'){$flags+=@('-DDEBUG_ENABLED','-DDEBUG_METHODS_ENABLED')}
$taskCacheRoot=$env:UNICORE_BUILD_CACHE_ROOT
if([string]::IsNullOrEmpty($taskCacheRoot)){$taskCacheRoot='D:/PROJECT/CACHE/BUILD'}
$objectDir=Join-Path $taskCacheRoot "cae-godot472-$Target"
New-Item -ItemType Directory -Force $objectDir | Out-Null
$objects=@()
foreach($source in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'src/bindings') -Filter '*.cpp') {
 $obj=Join-Path $objectDir ($source.BaseName+'.o')
 & $cxx @flags -c $source.FullName -o $obj
 if($LASTEXITCODE -ne 0){throw "Compile failed: $($source.Name)"}
 $objects+=$obj
}
$lib=Join-Path $cpp "bin/libgodot-cpp.windows.$Target.x86_64.a"
if(-not (Test-Path -LiteralPath $lib)){throw "Missing binding archive $lib"}
$output=Join-Path $root "bin/windows/x86_64/unicore_native.godot472.windows.$Target.x86_64.dll"
& $cxx -shared -static -static-libgcc -static-libstdc++ @objects $lib -o $output
if($LASTEXITCODE -ne 0){throw 'Link failed'}
Write-Output "Built $output"
