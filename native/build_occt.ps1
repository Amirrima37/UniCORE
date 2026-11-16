$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
Set-Location $taskRoot
$taskPython=$env:UNICORE_PYTHON
if([string]::IsNullOrEmpty($taskPython)){$taskPython='C:/Users/Victus/AppData/Local/Python/pythoncore-3.14-64/python.exe'}
$taskSdkRoot=& $taskPython $taskRoot/scripts/engines/development_paths.py sdk
$taskSdk=Join-Path $taskSdkRoot 'ucrt64'
$env:PATH="$taskSdk/bin;D:/msys64/ucrt64/bin;"+$env:PATH
& "$taskSdk/bin/g++.exe" -std=gnu++17 -O2 -B D:/msys64/ucrt64/lib/ -I "$taskSdk/include" -I "$taskSdk/include/opencascade" -idirafter D:/msys64/ucrt64/include native/occt/worker.cpp -L "$taskSdk/lib" -L D:/msys64/ucrt64/lib -lTKDESTEP -lTKXSBase -lTKDE -lTKBool -lTKBO -lTKPrim -lTKShHealing -lTKTopAlgo -lTKGeomAlgo -lTKBRep -lTKGeomBase -lTKG3d -lTKG2d -lTKMath -lTKernel -lbcrypt -o "$taskSdkRoot/unicore_occt_worker.exe"
if($LASTEXITCODE -ne 0){throw 'OCCT worker build failed'}
& "$taskSdk/bin/g++.exe" -std=gnu++17 -O2 -B D:/msys64/ucrt64/lib/ -I "$taskSdk/include" -I "$taskSdk/include/opencascade" -idirafter D:/msys64/ucrt64/include native/occt/make_fixtures.cpp -L "$taskSdk/lib" -L D:/msys64/ucrt64/lib -lTKDESTEP -lTKXSBase -lTKDE -lTKPrim -lTKTopAlgo -lTKGeomAlgo -lTKBRep -lTKGeomBase -lTKG3d -lTKG2d -lTKMath -lTKernel -o "$taskSdkRoot/make_occt_fixtures.exe"
if($LASTEXITCODE -ne 0){throw 'OCCT fixture builder failed'}
$taskPython=$env:UNICORE_PYTHON
if([string]::IsNullOrEmpty($taskPython)){$taskPython='C:/Users/Victus/AppData/Local/Python/pythoncore-3.14-64/python.exe'}
& $taskPython native/occt/seal_build.py
if($LASTEXITCODE -ne 0){throw 'OCCT build manifest failed'}
