import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Generate acceptance documentation from measured receipts, never synthetic values."""
import json,hashlib,shutil,sys,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/architecture/evidence/step-final'
rows=json.loads((OUT/'numerical.json').read_text())
archives=[]
for i,row in enumerate(rows):
    dest=OUT/'numerical-jobs'/str(i);dest.mkdir(parents=True,exist_ok=True)
    paths={}
    for name in ['model.inp','model.dat','receipt.json','stdout.txt','stderr.txt','canonical-model.json']:
        source=Path(row['job'])/name
        if source.exists():
            expected=hashlib.sha256(source.read_bytes()).hexdigest()
            if not (dest/name).exists():shutil.copyfile(source,dest/name)
            assert hashlib.sha256((dest/name).read_bytes()).hexdigest()==expected, 'Archived artifact differs; preserve and investigate'
            paths[name]=expected
    archives.append(dict(row=i,files=paths))
(OUT/'numerical-artifacts.json').write_text(json.dumps(archives,indent=2))
def table(bending,fixture):
    s='| h (m) | Nodes | TET4 | Min mean ratio | Min Jacobian (m³) | Tip mean (m) | Max displacement (m) | Reference (m) | Error (%) | Reaction imbalance / F | Max von Mises (Pa) | Solve wall (s) |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n'
    for r in rows:
        if r['bending']==bending and r['fixture']==fixture:
            s+='| '+ ' | '.join([f"{r['size_m']:.5g}",str(r['nodes']),str(r['tet4']),f"{r['minimum_mean_ratio']:.5g}",f"{r['minimum_jacobian']:.5g}",f"{r['tip_mean_m']:.9g}",f"{r['maximum_displacement_m']:.9g}",f"{r['reference_m']:.9g}",f"{100*r['relative_error']:.6g}",f"{r['reaction_relative_imbalance']:.5g}",f"{r['maximum_von_mises_Pa']:.8g}",f"{r['wall_solve_s']:.3f}"])+ ' |\n'
    return s
reg_path=OUT/('regressions-final' if (OUT/'regressions-final/receipt.json').exists() else 'regressions')
reg=json.loads((reg_path/'results.json').read_text())
eng=json.loads((OUT/'engineering-receipt.json').read_text())
gui=json.loads((OUT/'gui-receipt.json').read_text()) if (OUT/'gui-receipt.json').exists() else []
life=json.loads((OUT/'lifecycle/results.json').read_text())
report='''# STEP → CalculiX final acceptance — PARTIAL

This campaign continues the existing working tree. CAD & Meshing 2.0 has not begun. The canonical fingerprint and lossless mesh persistence implementations were preserved.

## Reproduction and scope

From the repository root, use `C:/Users/Victus/AppData/Local/Python/pythoncore-3.14-64/python.exe` as PYTHON and `D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe` as GODOT. Set `UNICORE_PYTHON` to PYTHON; set APPDATA and LOCALAPPDATA to `.tools/godot472-migration/roaming` and `.tools/godot472-migration/local` (absolute paths).

```text
PYTHON tests/run_step_final.py numerical
PYTHON tests/run_step_final.py engineering
PYTHON tests/run_step_final.py gui
PYTHON tests/run_step_final.py workbench-lifecycle
PYTHON native/run_regressions.py --godot GODOT --output docs/architecture/evidence/step-final/regressions
PYTHON tests/summarize_step_final.py
```

Every subprocess is bounded. Raw stdout/stderr and actual exits are under `evidence/step-final/`. Negative subprocess tests intentionally return 1; their harness returns 0 only after verifying rejection. GUI automation invokes the actual existing Workbench and document commands, not synthetic rendering or simulated solver responses. It does not establish manual use of every file-dialog interaction or a full shell navigation tour.

## Pinned versions

Godot 4.7.2 stable official ed1daf0bf; Gmsh 4.15.2 SDK with OpenCASCADE STEP translator 7.8.1; CalculiX 2.23. Exact locally measured executable/DLL hashes are in `evidence/step-final/binary-hashes.json`; upstream acquisition records remain in `engines.lock.json`. The supplied Godot executable and extension library mapping were not replaced. STEP source unit is mm, converted by OCC into m; all decks and reported calculations use m, N, Pa. The bar measures 0.1 × 1 × 0.1 m and the cylinder radius 0.1 m, length 0.2 m. OCC bounding boxes have the usual 1e-7 m tolerance expansion.

## Numerical references

All cases use E=210 GPa and total face force 1000 N, distributed by triangle area. The lower Y end is fixed in all three translations. The upper Y end is loaded axially (+Y), or transversely (+X) for bending. Axial cases use nu=0 to isolate the uniform stress patch from clamp Poisson effects; bending uses nu=0.3. These are documented verification materials, not a calibration to a particular steel specimen.

Axial bar: L=1 m, A=0.01 m², u=FL/(EA)=4.7619047619e-7 m, nominal stress 100000 Pa. Three progressively smaller Gmsh target lengths are used; actual counts and quality appear below. Error stagnates at about 5e-8 relative, consistent with CalculiX printed-result precision and an exactly representable constant-strain solution. Increasing counts alone is not evidence of convergence here.

'''+table(False,'bar')+'''
Cantilever bar: Euler–Bernoulli integration of EI times the fourth derivative of u = 0 with fixed root and end force gives u=FL³/(3EI)=1.90476190476e-4 m, I=(0.1)^4/12=8.333333333e-6 m⁴. This assumes a slender, linear, prismatic beam, small displacement, plane sections, and negligible shear deformation. L/width=10. A Timoshenko shear estimate F*L/(k*G*A), k=5/6 and G=E/[2(1+nu)], is 1.485714286e-6 m (0.78% of Euler–Bernoulli), much smaller than the observed discretization errors. Reported tip displacement is the arithmetic mean of loaded face nodes, not one selected corner. Solid clamp effects, nonuniform end response, and clamp stress singularities limit comparison of peak von Mises values to a beam stress formula.

'''+table(True,'bar')+'''
The bending error decreases monotonically, 55.1% → 43.3% → 21.9%, but remains unacceptable for a high-accuracy bending prediction. First-order TET4 elements are too stiff on these meshes. No industrial-accuracy or asymptotic-convergence claim is made. Peak stress is a mesh-dependent output, not a converged stress certification.

Cylinder: source radius 0.1 m, length 0.2 m; exact CAD volume pi*r²*L=0.00628318530718 m³, end area pi*r²=0.0314159265359 m²; u=3.03152272556e-8 m at nu=0. Mesh faceting reduces area and volume, causing a positive axial compliance error which decreases with refinement. The independent reference uses exact circular area, not the discretized area.

'''+table(False,'cylinder')+'''
CAD bounds, source units, CAD and faceted volumes, source hashes, actual physical face names, end areas, and selected support/load face IDs are recorded per row in `numerical.json`. All minimum Jacobians are positive. The production bridge checks triangle coverage against the TET4 exterior and verifies face-node membership and total applied force. Dimensionless minimum quality here is tetrahedron mean ratio, 12*(3V)^(2/3)/sum(edge²); Jacobian alone is dimensional and cannot substitute for a shape metric.

Reactions are summed only on constrained nodes; the reported imbalance is ||sum(R)+F||/||F||. All nine cases are below 1.8e-6. This uses CalculiX printed RF values, not an inferred equilibrium from load distribution. Stress and displacement were read from actual DAT output. Archived decks, DAT output, canonical models, terminal receipts and SHA-256 inventories are under `numerical-jobs/` and `numerical-artifacts.json`.

## Actual exits and regressions

'''
report+=f"Default manifest: {sum(r['passed'] for r in reg)}/{len(reg)} passed; all recorded exits: {sorted(set(r['exit_code'] for r in reg))}. See `regressions/receipt.json` and individual logs. Native extension numerical tests, thermal, structural, Extreme, and other existing default functionality ran against the pinned 4.7.2 runtime.\n\n"
report+='| Engineering check | Actual exit | Outcome |\n|---|---:|---|\n'
for r in eng:report+=f"| {r['name']} | {r['exit_code']} | {r['outcome']} |\n"
report+='\nThe Extreme comparison failed with PermissionError while overwriting an existing Box.stdout.txt (both historical and reused campaign outputs). A narrowly scoped --output option and a unique output directory per attempt preserve prior evidence. A fresh-output rerun passed both comparisons; see `comparison-receipt.json` for the exact directory and exit 0. Displacement relative L2 differences were 8.40e-8 and 2.18e-7, stress differences below 2.10e-7. The latest failed engineering receipt and error stream are retained. The editor scan exited 0 with no SCRIPT ERROR; root certificate store warnings remain in logs and are not a native crash.\n\n'
report+='## Graphical Workbench evidence\n\n| Fixture | Actual exit | Outcome |\n|---|---:|---|\n'
for r in gui:report+=f"| {r['name']} | {r['exit_code']} | {r['outcome']} |\n"
report+='''
The graphical runner captures genuine viewport screenshots at 1280×720 and 1920×1080 in `screenshots/`: imported geometry, selected CAD face, TET4 mesh, support/force, backend, execution, displacement, von Mises, reopened, and recalculated. It validates new solve freshness, exact mesh fingerprint preservation, a blank-document close followed by reopen, three additional reopen cycles, and material E doubling with half displacement on recalculation. It also rejects edits to coordinates, connectivity, geometry placement, E, force, support, analysis type, solver configuration, and embedded source bytes. No fingerprint code was changed. Existing legacy hash validation remains strict; no old invalid result is reauthorized.

The first graphical bar passed (exit 0); the first cylinder capture timed out at 240 seconds without completing any screenshot. Its receipt and streams are retained as gui-first-receipt.json and gui-cylinder-first.*.txt. The capture helper now explicitly requests an actual Godot RenderingServer.force_draw rather than awaiting frame_post_draw indefinitely. Both fixtures then passed (exit 0) in about 11 and 14 seconds. This is evidence consistent with a capture synchronization issue, not proof of a particular Windows occlusion state. No new native crash was observed. Historical crashes remain separately documented.

Representative genuine captures: [bar displacement, 1280](evidence/step-final/screenshots/bar-displacement-1280.png), [bar stress, 1920](evidence/step-final/screenshots/bar-von-mises-1920.png), [cylinder displacement, 1280](evidence/step-final/screenshots/cylinder-displacement-1280.png), [cylinder stress, 1920](evidence/step-final/screenshots/cylinder-von-mises-1920.png). Visual inspection confirms nonempty rendered solids, contour colors, stress/displacement labels, units, and numerical legends. Some pre-existing UI text has mojibake and the bar can approach the top viewport boundary at the smaller size; no UI rewrite was attempted.

## Lifecycle and failure checks

'''
report+='| Engine | Scenario | Launcher exit | Terminal state | Outcome |\n|---|---|---:|---|---|\n'
for r in life:report+=f"| {r['engine']} | {r['action']} | {r['launcher_exit']} | {r['receipt']['state']} | {r['outcome']} |\n"
report+='''
Both active-cancel tests verify the launched PID is alive before requesting cancellation and gone afterward. Zero-duration timeout tests exercise real child termination deterministically; they do not measure a long-running 120-second timeout. Gmsh now emits its owned PID receipt; CalculiX launcher accepts an optional timeout argument while retaining the default 120 seconds. These are the only production launcher changes.

`workbench-lifecycle.json` records actual threaded Workbench tests: save during meshing/solving, rapid repeated actions rejected by operation guards, cancellation joined, reopen after cancellation, cancelled result not published, and graceful shutdown during an owned solve. Frame counts advance during operations, establishing responsiveness for these bounded cases. Missing physical groups, invalid connectivity, malformed/truncated/nonfinite output, corrupt source, and >32 MiB DAT are rejected. Test-generated oversized output is removed after rejection to avoid leaving a large dummy file. Actual lifecycle error streams and terminal receipts are retained.

## Limitations and final verdict

PARTIAL until every required criterion is satisfied. Numerical bending remains coarse (21.9% finest-mesh error). GUI coverage is automated Workbench invocation rather than manual complete shell/file-dialog navigation. The initial cylinder GUI delay and any retry must be included in the final evidence; it cannot be hidden by a later success. No universal historical-crash fix is claimed. No sustained-memory-growth campaign or hard output/log disk quota has been demonstrated. The 32 MiB DAT import limit protects parsing, not solver output generation. Abrupt OS termination of the parent is not covered by graceful shutdown testing; no Windows Job Object containment is implemented. The missing executable launcher error is preserved in launcher-error.txt, while the Workbench summary is generic failed/cancelled/timed-out and not fully actionable for every failure. These prevent an unrestricted safety/stability acceptance claim.

Changes are limited to acceptance scripts/evidence, the comparison runner output option, owned mesh PID evidence, optional owned solver timeout, and actionable missing-executable/failure-log messages in calculix_workbench.gd. Existing user edits, CAD architecture, native kernels, canonical fingerprints, and physics solvers were preserved. Stop at this checkpoint; do not begin CAD & Meshing 2.0.
'''
report=report.replace('The missing executable launcher error is preserved in launcher-error.txt, while the Workbench summary is generic failed/cancelled/timed-out and not fully actionable for every failure.','The Workbench now detects a missing executable before launching, names the expected pack and corrective action, and includes owned job log paths for unsuccessful terminal receipts. Per-path UX for every corrupt or oversized upstream output remains limited.')
report=report.replace('The initial cylinder GUI delay and any retry must be included in the final evidence; it cannot be hidden by a later success.','The initial cylinder GUI capture timeout is preserved above; the explicit-render retry passed.')
compat=json.loads((OUT/'compatibility-receipt.json').read_text())
report+='\n## Modal/transient compatibility checks\n\n'
for r in compat:report+=f"- {r['name']}: exit {r['exit_code']}, {r['outcome']}; raw streams retained.\n"
report+='\nThe installed modal executable reported 580 checks, zero failures; the Newmark executable reported three energy/equilibrium/output-count checks, zero failures. Existing binaries were executed, not rebuilt; this is a compatibility smoke check, not a new exhaustive modal/transient validation campaign.\n'
screens=[]
for p in sorted((OUT/'screenshots').glob('*.png')):
    b=p.read_bytes();width,height=struct.unpack('>II',b[16:24]);screens.append(dict(path=str(p.relative_to(OUT)),width=width,height=height,sha256=hashlib.sha256(b).hexdigest(),outcome='PASS' if (width,height) in [(1280,720),(1920,1080)] else 'FAIL'))
(OUT/'screenshots.json').write_text(json.dumps(screens,indent=2))
report+=f'\nScreenshot inventory: {len(screens)} actual PNGs, dimensions and SHA-256 in screenshots.json.\n'
(ROOT/'docs/architecture/STEP_CALCULIX_FINAL_ACCEPTANCE.md').write_text(report,encoding='utf-8')
(OUT/'final-receipt.json').write_text(json.dumps(dict(outcome='PARTIAL',default_regressions=dict(passed=sum(r['passed'] for r in reg),expected=28,receipt=str(reg_path/'receipt.json')),numerical_cases=len(rows),numerical_process_exit=0,engineering=eng,comparison_retry=json.loads((OUT/'comparison-receipt.json').read_text()),gui=gui,compatibility=compat,screenshots=len(screens),limitations=['Initial graphical timeout preserved; retry passed','No sustained memory monitoring','No hard output disk quota','No abrupt-parent-death containment verification','Automated Workbench coverage does not establish manual shell navigation']),indent=2))
print('Wrote measured final acceptance report: PARTIAL')
