"""Bounded, sequential acceptance runner; records commands and preserves earlier artifacts."""
import argparse, hashlib, json, os, re, shutil, subprocess, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/workbench-2/stage6-final'
GODOT = str(ROOT / '.tools/godot/Godot_v4.0-stable_win64.exe')
OUT.mkdir(exist_ok=True)
os.environ['APPDATA'] = str(ROOT / '.tools/cae-appdata')

def run(name, command, timeout=120):
    start = time.perf_counter()
    try:
        p = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=timeout)
        log = (p.stdout+p.stderr).decode('utf-8', 'replace')
        row = dict(name=name, command=command, exit_code=p.returncode, appdata=os.environ['APPDATA'])
    except subprocess.TimeoutExpired as e:
        log = ((e.stdout or b'')+(e.stderr or b'')).decode('utf-8', 'replace')
        row = dict(name=name, command=command, timeout=True)
    row.update(seconds=round(time.perf_counter()-start, 3),
               log=str((OUT/(name+'.log')).relative_to(ROOT)),
               diagnostics=[s for s in log.splitlines() if any(x in s for x in ['ERROR:', 'WARNING:', 'SCRIPT ERROR', 'script is gone'])],
               assertions=[s for s in log.splitlines() if re.search(r'PASS|Passed|checks=|failures=', s)])
    row['passed'] = row.get('exit_code') == 0 and not any(x in log for x in ['SCRIPT ERROR:', 'script is gone', 'nonexistent signal'])
    (OUT/(name+'.log')).write_text(log, encoding='utf-8')
    records.append(row)
    (OUT/(args.phase+'.json')).write_text(json.dumps(records, indent=2))
    print(json.dumps({k:v for k,v in row.items() if k not in ['diagnostics','assertions','command']}), flush=True)
    return row

def gd(name, graphical=False, timeout=120):
    row=run(name, [GODOT, *([] if graphical else ['--headless']), '--path', str(ROOT),
                      '-s', 'res://tests/'+name+'.gd'], timeout)
    engine=ROOT/'.tools/cae-appdata/Godot/app_userdata/UniCORE/logs/godot.log'
    if engine.exists():shutil.copy2(engine,OUT/(name+'-engine.log'))
    return row

parser=argparse.ArgumentParser()
parser.add_argument('phase', choices=['lifecycle','build','native','focused','regression','graphics','references'])
args=parser.parse_args()
records=[]
# Existing fixtures write fixed artifact paths. Preserve historical bytes before execution.
if args.phase in ['focused','graphics']:
    backup=OUT/('before-'+args.phase)
    backup.mkdir(exist_ok=True)
    for p in (ROOT/'docs/workbench-2').glob('stage[456]*'):
        if p.is_file() and not (backup/p.name).exists(): shutil.copy2(p, backup/p.name)

if args.phase=='lifecycle':
    gd('test_analysis_drawer_listener_lifetime', timeout=35)
    gd('test_app_shell_suite', timeout=35)
    gd('diagnose_stage6_render_wait', True, 20)
elif args.phase=='build':
    run('compiler', ['C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe','--version'])
    for mode, flags, binary in [('release',[],'unicore_solver.exe'),('debug',['-Debug'],'unicore_solver_debug.exe'),('noomp',['-NoOpenMP'],'unicore_solver_noomp.exe')]:
        row=run('build-'+mode,['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','native/extreme/build.ps1',*flags],180)
        if row['passed']:
            p=ROOT/'bin'/binary
            row.update(binary=str(p),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest())
            (OUT/'build.json').write_text(json.dumps(records,indent=2))
elif args.phase=='regression':
    run('default-manifest',[str(Path(__import__('sys').executable)), 'native/run_regressions.py','--godot',GODOT,'--output','docs/workbench-2/stage6-final/regression'],600)
elif args.phase=='native':
    if gd('test_stage6_native_matrix')['passed']:
        run('restart',[__import__('sys').executable,'tests/stage6_restart_acceptance.py'])
elif args.phase=='focused':
    for name in ['test_stage6_cylinder','test_stage6_topology','test_stage6_remesh','test_cylinder_fem',
                 'test_stage6_sphere','test_stage6_sphere_contract','test_stage6_pipe','test_stage6_pipe_contract',
                 'test_stage6_condition_conflicts','test_stage6_dialog_ui','test_stage6_failure_ui',
                 'test_stage5_provenance','test_stage5_quality','test_stage5_display','test_stage5_probes',
                 'test_stage51_cache','test_stage51_equivalence']:
        gd(name)
elif args.phase=='graphics':
    gd('test_stage6_workbench',True,150)
    gd('test_stage6_load_persistence',timeout=40)
elif args.phase=='references':
    row=run('build-debug-noomp',['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','native/extreme/build.ps1','-Debug','-NoOpenMP'],180)
    if row['passed']:
        p=ROOT/'bin/unicore_solver_debug_noomp.exe'
        row.update(binary=str(p),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest())
        gd('test_stage6_native_matrix')
        run('restart-final',[__import__('sys').executable,'tests/stage6_restart_acceptance.py'])
    run('lame',[__import__('sys').executable,'tests/stage6_lame_reference.py'])
    gd('test_stage51_cache',timeout=35)
    gd('capture_stage6_final_cylinder',True,120)

raise SystemExit(0 if all(r['passed'] for r in records) else 1)
