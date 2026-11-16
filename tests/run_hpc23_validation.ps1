param([switch]$ReuseRelease,[ValidateSet('all','numerical')][string]$From='all')
$ErrorActionPreference='Stop'
$cxx='C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe'
$python='C:/Users/Victus/AppData/Local/Python/pythoncore-3.14-64/python.exe'
$log='docs/hpc-optimization/hpc23-validation.log'
function Check-Exit {if($LASTEXITCODE -ne 0){throw "Exit $LASTEXITCODE"}}
if($From -eq 'all'){
if(-not $ReuseRelease){powershell -ExecutionPolicy Bypass -File native/extreme/build.ps1; Check-Exit}
foreach($mode in @('release','debug','noomp')) {
 $flags=@('-std=c++17','-ffp-contract=off','-static','-Inative/src')
 if($mode -eq 'debug'){$flags+=@('-O0','-g')}else{$flags+='-O2'}
 if($mode -ne 'noomp'){$flags+='-fopenmp'}
 foreach($test in @('sparse_preconditioner_test','parallel_assembly_test')) {
  & $cxx @flags "native/tests/$test.cpp" -o ".tools/hpc23_${test}_${mode}.exe"; Check-Exit
  & ".tools/hpc23_${test}_${mode}.exe" 2>&1 | Tee-Object -FilePath $log -Append; Check-Exit
 }
}
foreach($test in @('structural_solver_test','hex8_test','thermal_radiation_test')) {
 & $cxx -std=c++17 -O2 -fopenmp -ffp-contract=off -static -Inative/src "native/tests/$test.cpp" -o ".tools/hpc23_$test.exe"; Check-Exit
 & ".tools/hpc23_$test.exe" 2>&1 | Tee-Object -FilePath $log -Append; Check-Exit
}
foreach($method in @('ic0','block-jacobi')){& .tools/hpc23_thermal_radiation_test.exe $method 2>&1 | Tee-Object -FilePath $log -Append; Check-Exit}
& .tools/hpc23_parallel_assembly_test_release.exe --serial 2>&1 | Tee-Object -FilePath $log -Append; Check-Exit
powershell -ExecutionPolicy Bypass -File native/extreme/build.ps1 -Debug; Check-Exit
powershell -ExecutionPolicy Bypass -File native/extreme/build.ps1 -NoOpenMP; Check-Exit
}
$pythonTests=if($From -eq 'numerical'){@('test_hpc23_options','test_hpc23_numerical')}else{@('test_extreme_cli','test_extreme_checkpoint','test_extreme_configurations','test_hpc23_options','test_hpc23_numerical')}
foreach($test in $pythonTests) {
 & $python "tests/$test.py" 2>&1 | Tee-Object -FilePath $log -Append; Check-Exit
}
& $python -c "from pathlib import Path;p=Path('tests/test_hpc_assembly_equivalence.py');s=p.read_text().replace('hpc21-thermal-equivalence.json','hpc23-thermal-equivalence.json');exec(compile(s,str(p),'exec'),{'__file__':str(p.resolve()),'__name__':'__main__'})" 2>&1 | Tee-Object -FilePath $log -Append; Check-Exit
& $python -c "from pathlib import Path;p=Path('tests/test_hpc22_fallback.py');s=p.read_text().replace('hpc22-fallback-equivalence.json','hpc23-fallback-equivalence.json');exec(compile(s,str(p),'exec'),{'__file__':str(p.resolve()),'__name__':'__main__'})" 2>&1 | Tee-Object -FilePath $log -Append; Check-Exit
powershell -ExecutionPolicy Bypass -File native/build_direct.ps1 -Target template_debug; Check-Exit
powershell -ExecutionPolicy Bypass -File native/build_direct.ps1 -Target template_release; Check-Exit
& $python native/run_regressions.py --godot .tools/godot/Godot_v4.0-stable_win64_console.exe --all-suites --output .tools/hpc23-final 2>&1 | Tee-Object -FilePath $log -Append
"Godot runner exit: $LASTEXITCODE" | Tee-Object -FilePath $log -Append
Copy-Item .tools/hpc23-final/results.json docs/hpc-optimization/hpc23-final-regression.json
Copy-Item .tools/hpc23-final/test_app_shell_suite.log docs/hpc-optimization/hpc23-app-shell.log
