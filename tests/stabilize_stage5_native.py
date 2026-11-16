"""Bounded Stage 5 native builds and cross-configuration checks; no benchmarks."""
import json, subprocess, time, hashlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root / 'docs/workbench-2/stage5-final-native'
out.mkdir(exist_ok=True)
build = root / '.tools/stage5-final-native'
build.mkdir(exist_ok=True)
rows = []
def run(name, command, timeout=120):
    start = time.perf_counter()
    try:
        p = subprocess.run(command, cwd=root, capture_output=True, timeout=timeout)
        log = (p.stdout+p.stderr).decode('utf-8', errors='replace')
        row = dict(name=name, exit=p.returncode, seconds=time.perf_counter()-start)
    except subprocess.TimeoutExpired as e:
        log = ((e.stdout or b'')+(e.stderr or b'')).decode('utf-8', errors='replace')
        row = dict(name=name, timeout=True, seconds=time.perf_counter()-start)
    (out/(name+'.log')).write_text(log, encoding='utf-8')
    rows.append(row)
    (out/'results.json').write_text(json.dumps(rows, indent=2))
    print(row, flush=True)
    assert row.get('exit') == 0, name

cxx = 'C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe'
for mode in ['release', 'debug', 'noomp']:
    flags = ['-std=c++17', '-static', '-ffp-contract=off', '-Inative/src', '-O0' if mode=='debug' else '-O2']
    if mode != 'noomp': flags += ['-fopenmp']
    for test in ['structural_solver_test', 'hex8_test', 'thermal_radiation_test', 'sparse_preconditioner_test', 'parallel_assembly_test']:
        exe = str(build/(test+'-'+mode+'.exe'))
        run('build-'+test+'-'+mode, [cxx,*flags,'native/tests/'+test+'.cpp','-o',exe])
        run(test+'-'+mode,[exe],30)

fields = ['displacement_flat','reactions_flat','stress','strain','von_mises','temperature','heat_flux','history','heat_reactions','relative_residual','iterations']
for fixture in ['docs/extreme-mode/examples/tet.ucjob','.tools/extreme-checkpoint/model.ucjob']:
    reference = None
    for mode,exe in [('release','unicore_solver.exe'),('debug','unicore_solver_debug.exe'),('noomp','unicore_solver_noomp.exe')]:
        dest = build/Path(fixture).parent.name/mode
        run('solve-'+Path(fixture).parent.name+'-'+mode,[str(root/'bin'/exe),'--job',fixture,'--output',str(dest),'--threads','1'],30)
        result = json.loads((dest/'results.json').read_text())
        data = {k:result[k] for k in fields if k in result}
        if reference is None: reference=data
        assert data==reference, (fixture,mode)
        assert result['provenance_version']==1 and isinstance(result['input_fingerprint'],str)
        rows[-1]['exact_fields']=True
        rows[-1]['binary_sha256']=hashlib.sha256((root/'bin'/exe).read_bytes()).hexdigest()
        (out/'results.json').write_text(json.dumps(rows,indent=2))
print('Fresh shared tests and standalone mode consistency PASS')
