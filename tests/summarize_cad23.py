import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Measured Checkpoint 2.3 report; missing/failed mandatory evidence prevents PASS."""
import json,hashlib,csv,struct,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/architecture/evidence/cad23'
def read(name):return json.loads((OUT/name).read_text())
def sha(p):
    with Path(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
rows=read('numerical.json');audit=read('independent-audit.json');baseline=read('baseline.json')
modes=['unit','numerical','independent','persistence','lifecycle','shutdown','gui','gui_inspect','scan','preservation','regressions']
campaigns={m:read(m+'-latest.json') if (OUT/(m+'-latest.json')).exists() else [] for m in modes}
production=['core/cae/cae_document.gd','core/cae/mesh_config.gd','core/cae/calculix_backend.gd','core/cae/calculix_workbench.gd','core/cae/mesh_display.gd','core/cae/mesh_inspection.gd','core/cae/structural_display.gd','ui/cae/analysis_editor.gd','ui/cae/gmsh_mesh_panel.gd','ui/cae/cae_workspace.gd','scripts/engines/mesh_config.py','scripts/engines/gmsh_study.py','scripts/engines/quadratic_tet.py','scripts/engines/quadratic_prepare.py','scripts/engines/owned_execution.py','scripts/engines/run_owned_prepare.py','scripts/engines/run_owned_solver.py']
(OUT/'source-hashes.json').write_text(json.dumps({p:sha(ROOT/p) for p in production},indent=2))
binaries={p:dict(before=h,after=sha(p),outcome='PASS' if sha(p)==h else 'FAIL') for p,h in baseline['binaries'].items()};(OUT/'binary-hashes-after.json').write_text(json.dumps(binaries,indent=2))
screens=[]
for p in sorted((OUT/'screenshots').glob('*.png')):
    width,height=struct.unpack('>II',p.read_bytes()[16:24]);screens.append(dict(path=p.relative_to(OUT).as_posix(),width=width,height=height,sha256=sha(p),outcome='PASS' if (width,height) in [(1280,720),(1920,1080)] else 'FAIL'))
(OUT/'screenshots.json').write_text(json.dumps(screens,indent=2))
history=[]
for p in sorted(OUT.glob('*/receipt.json')):
    data=json.loads(p.read_text())
    if isinstance(data,list):history.extend(data)
(OUT/'attempt-history.json').write_text(json.dumps(history,indent=2))
flat=[]
for r,a in zip(rows,audit):
    assert (r['case'],r['order'],r['level'])==(a['case'],a['order'],a['level'])
    completion=json.loads((OUT/a['artifacts']/'receipt.json').read_text())
    error=r['relative_displacement_error'];seconds=completion['seconds'];memory=completion.get('peak_memory_bytes',0)/2**20
    flat.append(dict(case=r['case'],order=r['order'],level=r['level'],settings=json.dumps(r['settings'],sort_keys=True),nodes=r['nodes'],dofs=r['dofs'],elements=r['tet4'],exact_cad_volume_m3=r['quality']['cad_volume'],mesh_volume_m3=r['quality']['mesh_volume'],relative_volume_error=r['quality']['relative_volume_difference'],min_shape=r['quality'].get('minimum_quadratic_quality',r['quality']['minimum_mean_ratio']),minimum_jacobian_bound_m3=r['quality']['minimum_jacobian'],maximum_displacement_m=r['maximum_displacement_m'],tip_mean_m=r['tip_mean_m'],reference_m=r['reference_m'],relative_displacement_error=error,maximum_von_mises_of_display_tensor_Pa=r['maximum_von_mises_Pa'],stress_element_corner_centroid_m=json.dumps(r['stress_location_m']),sample_von_mises_Pa=a['sample']['von_mises_Pa'] if a['sample'] else None,reaction_imbalance=a['reaction_relative_imbalance'],mesh_s=r['meshing_s'],mesh_wall_s=r['mesh_wall_s'],mesh_peak_commit_MiB=r['mesh_peak_commit_bytes']/2**20,solve_pipeline_s=r['solver_s'],solver_process_s=seconds,solver_peak_working_set_MiB=r['solver_peak_working_set_bytes']/2**20,solver_peak_commit_MiB=memory,accuracy_per_dof=1/(error*r['dofs']),accuracy_per_second=1/(error*seconds),accuracy_per_MiB=1/(error*memory) if memory else None,observed_reference_error_rate=a['observed_error_rate'],artifacts=a['artifacts']))
with (OUT/'convergence.csv').open('w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=list(flat[0]));w.writeheader();w.writerows(flat)
(OUT/'convergence.json').write_text(json.dumps(flat,indent=2))
reg=[]
if campaigns['regressions']:reg=json.loads((Path(campaigns['regressions'][0]['evidence'])/'default/results.json').read_text())
checks={m:bool(campaigns[m]) and all(r['outcome']=='PASS' and r['exit_code']==0 for r in campaigns[m]) for m in modes}
checks.update(default_28=len(reg)==28 and all(r['passed'] and r['exit_code']==0 for r in reg),four_levels_each_order=len(rows)==32 and all(sum(r['case']==c and r['order']==o for r in rows)==4 for c in ['axial-bar','axial-cylinder','bending','step-hole'] for o in [1,2]),independent_32=len(audit)==32 and all(a['outcome']=='PASS' for a in audit),unchanged_pins=all(b['outcome']=='PASS' for b in binaries.values()),screenshots=bool(screens) and all(s['outcome']=='PASS' for s in screens),freshness=all(r['outcome']=='PASS' for r in read('persistence-details.json')))
verdict='PASS' if all(checks.values()) else 'PARTIAL'
(OUT/'final-receipt.json').write_text(json.dumps(dict(checkpoint='2.3',verdict=verdict,checks=checks,campaigns=campaigns,baseline=baseline,default_passed=sum(r['passed'] for r in reg),default_total=len(reg),failed_attempts=[r for r in history if r['outcome']!='PASS'],scope='single-solid isotropic linear static CalculiX C3D4/C3D10; display approximates TRI6 with 4 triangles'),indent=2))
report=f'''# CAD & Meshing 2.3 — {verdict}

Genuine Gmsh TET10 / CalculiX C3D10 is integrated into the existing Workbench. This verdict covers the bounded, single-solid, isotropic linear static workflow tested here. No assembly/contact capability or universal resolution of the historical Godot access violation is claimed.

## Baseline and changed files

Branch `{baseline['branch']}`, HEAD `{baseline['head']}`. The pre-existing dirty tree is preserved in [working-tree-before.txt](evidence/cad23/working-tree-before.txt). CAD 2.1, CAD 2.2, STEP final acceptance and migration reports were inspected before editing. The baseline default manifest passed 28/28 with actual exit 0; see baseline-regressions.json. No native rebuild, executable replacement or dependency download was needed.

Exact production files changed for this checkpoint (source-hashes.json records their final SHA-256):

'''+''.join('- `'+p+'`\n' for p in production)+'''
Acceptance sources are tests/cad23_{unit.py,numerical.gd,independent.py,persistence.gd,lifecycle.py,shutdown.gd,shutdown.py,gui.gd,gui_inspect.gd,smoke.gd}, tests/run_cad23.py and tests/summarize_cad23.py. Prior user changes were not reset. Existing canonical mesh fingerprint and result-identity algorithms were not redesigned.

## Dependencies and preservation

Godot 4.7.2 official ed1daf0bf; Gmsh 4.15.2 with OCCT 7.8.1; CalculiX 2.23. All seven measured pinned executable/DLL hashes match baseline.json and CAD 2.2. No GDExtension rebuild was performed.

| Binary | SHA-256 (before = after) |
|---|---|
'''
for p,b in binaries.items():report+=f"| {Path(p).name} | `{b['after']}` |\n"
report+='''
## Mesh generation, order and boundaries

Schema 1 mesh settings retain the legacy TET4 behavior. Schema 2 requires explicit order 1 or 2; unknown fields, schemas and unsupported orders are rejected. The same global sizes, curvature setting, Distance/Threshold face fields, Delaunay/HXT algorithm selection, linear precursor optimization and resource controls remain available. Gmsh generates/optimizes the linear precursor, then uses Mesh.SecondOrderLinear=0 and mesh.setOrder(2), projecting boundary midsides onto CAD. Only volume type 11 and complete six-node type 9 faces are accepted for quadratic output. Requested TET10 never falls back to TET4.

The runtime getElementProperties(11) node coordinates are checked independently. Gmsh's final two tetrahedral edges differ from CalculiX. The explicit zero-based permutation is `[0,1,2,3,4,5,6,7,9,8]`. Canonical C3D10 edges are 12, 23, 31, 14, 24, 34. Every deck contains all ten nodes under `*ELEMENT,TYPE=C3D10`. The actual binary is verified by patch, bending and independent kinematic stress checks. See [Gmsh node ordering](https://gmsh.info/doc/texinfo/#Node-ordering) and [CalculiX shape10tet](https://github.com/Dhondtguido/CalculiX/blob/master/src/shape10tet.f); the runtime tests, rather than current upstream source alone, establish compatibility with the pinned binary.

Outward canonical faces and CalculiX side IDs (one-based corner/midside positions) are:

| Side | TRI6 nodes |
|---|---|
| 1 | 1,3,2,7,6,5 |
| 2 | 1,2,4,5,9,8 |
| 3 | 2,3,4,6,10,9 |
| 4 | 3,1,4,7,8,10 |

All physical groups must partition the complete exterior exactly once, with matching six-node connectivity and orientation. Inconsistent interior midsides, nonmanifold connectivity, missing nodes, stale CAD IDs and duplicate physical faces are rejected. Fixed faces constrain all three DOFs on corners and midsides.

Total Cartesian face force is converted to consistent nodal forces by integrating each TRI6 shape function against actual curved surface area, using bounded adaptive seven-point degree-five triangle quadrature (1e-10 relative parent/child rule tolerance, depth at most 4). Nonconvergence is rejected. Planar corner weights are zero and each midside weight is area/3; nodes are never loaded uniformly. Force and first moment are checked before export. A separate 16x16 Gauss/Duffy curved-patch integration verifies the rule. Campaign load faces are planar, where the original seven-point rule and its adaptive subdivision are polynomial-exact. Later adaptive refinement therefore strengthens general curved-face loading without changing that campaign's mathematical load definition.

## Curved Jacobians, volume and quality

For barycentric coordinates Li, corner shapes are Li(2Li-1), edge shapes 4LiLj. The actual isoparametric Jacobian is evaluated, not the corner tetrahedron alone. Its cubic determinant is converted from 20 lattice samples to degree-three Bernstein coefficients. Every coefficient must exceed longest_corner_edge^3 * 1e-12; otherwise the mesh is rejected with a refinement diagnostic. Positive coefficients are a sufficient global local-Jacobian positivity test over the reference tetrahedron. This binary64 test is conservative, not interval arithmetic and not a proof against every possible global self-intersection.

The four CalculiX integration points are permutations of (A,B,B,B), A=0.5854101966249685 and B=0.1381966011250105. Actual Gauss minima/maxima and stronger Bernstein lower/upper bounds are recorded per element; the inspector displays both. TET10 volume uses a cubic-exact five-point reference rule. The independent audit uses a separate 4x4x4 Gauss/Duffy rule and independently written derivatives. CAD volume remains exact OCCT mass; discrete curved mesh volume is separately labeled, in m3.

The dimensionless quadratic score is corner mean ratio multiplied by Bernstein detJ lower/upper. It is explicitly defined, not presented as an established standardized quality metric. Corner mean ratio and corner edge-ratio diagnostics retain their corner-only limitation. Histograms and worst-element IDs use the quadratic score. detJ has units m3 and is never advertised as scale-independent. Invalid/uncertain curved elements are refused; they are not certified from corner positivity. Direct OCCT BRepCheck/history and arbitrary scaling remain deferred as in CAD 2.1.

## Workbench, results and persistence

Mesh settings expose Linear TET4 / Quadratic TET10, with TET10 restricted to the CalculiX static backend. The existing CAD graph, physical face selection, material, load, inspection, job and result interfaces are reused. Expensive Gmsh, curved quality and load/deck preparation execute in owned external workers. No FEM kernel was replaced.

Each TRI6 display face is divided into four triangles through all six physical nodes. Displacement/deformation uses every nodal value. This is a documented piecewise-linear visualization approximation, not an exact continuously rendered quadratic patch and not a replacement FEM mesh. Picking and highlighting retain original ten-node element IDs and all node values.

All four actual CalculiX stress tensors per element are parsed, checked, persisted and accessible in element inspection. Contours explicitly display the arithmetic mean of the four tensors; von Mises is evaluated from that mean. This is neither nodal averaging nor a detJ-weighted physical volume average. Engineering strain is derived from the displayed tensor using isotropic elastic compliance; shear components are gamma. It is labeled as derived, not fabricated solver strain output. Raw integration-point stresses remain available for independent reconstruction. The independent audit also differentiates actual nodal displacements, applies Hooke's law and checks the IP stresses, propagating the DAT's printed decimal rounding through the derivative/operator.

Mesh schema 2 records order, node-order convention, all ten connectivity entries, exact coordinates, quadratic faces, effective settings, geometry identity and generation metadata. Existing lossless persistence and version-2 canonical SHA-256 cover the complete mesh dictionary. Unknown schemas/encodings, malformed coordinates/connectivity and oversized projects are rejected before active-document replacement. Existing version-1 fingerprint compatibility is unchanged; failed legacy freshness is never upgraded to current. ImportSTEP now applies existing body defaults at creation, preventing reopen-only normalization differences without rewriting old results.

Persistence tests verify unchanged TET10 reopen, both order switches with genuine remesh/re-solve, single midside and connectivity changes without revision bumps, material/load/source/sizing/analysis changes, stale worker completion, corrupt schema and malformed/truncated/duplicate/oversized DAT rejection. CAD 2.1 topology invalidation and legacy TET4/STEP/modal/transient preservation tests also run.

## Independent numerical campaign

Units: m, N, Pa. Every case uses E=210 GPa, a fully fixed lower-Y face and 1000 N total consistent traction on upper-Y. Axial cases use nu=0 to establish the representable uniform-strain patch without Poisson clamp effects; bending uses nu=0.3. The genuine STEP bar is 0.1 x 1 x 0.1 m, area 0.01 m2. Cylinder radius=0.1 m, length=0.2 m, area=pi*0.1^2. The STEP Boolean bar has a Y-directed radius=0.02 m through-hole, net area=0.01-pi*0.02^2. Source-unit conversion is inherited and preserved, never inferred from bounds.

Axial reference: FL/(EA). Bending: Euler–Bernoulli FL^3/(3EI), I=0.1^4/12. Timoshenko shear adds FL/(kGA), k=5/6, G=E/[2(1+nu)]. These are beam approximations, not independent exact 3D clamped-continuum solutions. Reported tip displacement is the arithmetic mean of the loaded-face nodal component. Stress sampling uses the fixed physical point (0.087,0.487,0.083) m in the hole bar: constant TET4 IP stress or a linear reconstruction of four C3D10 IP tensors after solving the quadratic physical-to-reference map.

Global h levels are 0.07, 0.05, 0.0333333, 0.0222222 m. Cylinder curvature points are 8,12,18,24. Hole levels keep global h=0.07 m, curvature=8,12,16,20; levels 1..3 add local h=0.02,0.015,0.01 m, fine distance=0.003 m, transition distance=0.025 m, boundary extension disabled. Complete effective settings, counts, exact/discrete volume, extrema, reactions, timing, memory and accuracy/cost proxies are in convergence.csv/json. Actual decks, DAT, canonical models and process receipts are archived under solver-jobs/. Independent references never use solver output as their expected answer.

'''
for case in ['axial-bar','axial-cylinder','bending','step-hole']:
    report+='### '+case+'\n\n| Order/level | Nodes / DOFs / elements | Volume error % | Min shape | Tip m | Reference error % | Reaction imbalance | Mesh / solver s | Solver commit MiB |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|\n'
    for r in flat:
        if r['case']==case:report+=f"| {r['order']}/{r['level']} | {r['nodes']} / {r['dofs']} / {r['elements']} | {100*r['relative_volume_error']:.7g} | {r['min_shape']:.5g} | {r['tip_mean_m']:.9g} | {100*r['relative_displacement_error']:.7g} | {r['reaction_imbalance']:.3g} | {r['mesh_s']:.3f} / {r['solver_process_s']:.3f} | {r['solver_peak_commit_MiB']:.2f} |\n"
    if case=='step-hole':
        report+='\n| Order/level | Max VM of displayed mean tensor Pa | VM at fixed sample Pa |\n|---|---:|---:|\n'
        for r in flat:
            if r['case']==case:report+=f"| {r['order']}/{r['level']} | {r['maximum_von_mises_of_display_tensor_Pa']:.9g} | {r['sample_von_mises_Pa']:.9g} |\n"
report+=f"\nIndependent equilibrium summary: maximum normalized force imbalance {max(a['reaction_relative_imbalance'] for a in audit):.9g}; maximum applied-moment discrepancy divided by 1000 N {max(a['moment_error_per_force_m'] for a in audit):.9g} m. Actual deck forces and moments are audited against a separately integrated physical mesh boundary; the small centroid offset of a faceted cylinder is not silently replaced by the exact CAD centroid. See applied_moment_Nm and independent_surface_moment_Nm in independent-audit.json.\n"
report+='''
The bar patch is effectively order invariant within printed-output precision. Both curved cases show materially lower geometric and axial error with TET10. Bending TET4 remains stiff; TET10 greatly improves the beam-reference comparison. The finest TET10 result crosses the Euler–Bernoulli reference, so a small absolute reference error is not proof of convergence to the exact 3D continuum. The Timoshenko correction is about 0.78% of EB deflection; clamp/end-traction effects remain. Observed reference-error rates in the CSV are descriptive only: curvature/local rules also change, and near-zero or sign-crossing errors cannot establish formal element convergence order. No peak-stress convergence claim is made.

## Comparable cost

For each quadratic level the CSV retains accuracy-per-DOF, per solver second and per peak committed MiB, defined as 1/(relative reference error * cost). These proxies are inappropriate for a patch at the output rounding floor and are not universal efficiency scores. Identical geometric-size comparisons are in the full tables. The closest available DOF, solver-time and memory comparisons are chosen mechanically, without selecting the best accuracy outcome:

| Case / cost matched | TET4 level / cost | TET10 level / cost | TET4 error % | TET10 error % |
|---|---:|---:|---:|---:|
'''
comparisons=[]
for case in ['axial-cylinder','bending','step-hole']:
    linear=[r for r in flat if r['case']==case and r['order']==1];quad=[r for r in flat if r['case']==case and r['order']==2]
    for cost in ['dofs','solver_process_s','solver_peak_commit_MiB']:
        l,q=min(((l,q) for l in linear for q in quad),key=lambda p:abs(math.log(p[0][cost]/p[1][cost])))
        comparisons.append(dict(case=case,cost=cost,linear_level=l['level'],quadratic_level=q['level'],linear_cost=l[cost],quadratic_cost=q[cost],linear_error=l['relative_displacement_error'],quadratic_error=q['relative_displacement_error']))
        report+=f"| {case} / {cost} | {l['level']} / {l[cost]:.6g} | {q['level']} / {q[cost]:.6g} | {100*l['relative_displacement_error']:.6g} | {100*q['relative_displacement_error']:.6g} |\n"
(OUT/'cost-comparisons.json').write_text(json.dumps(comparisons,indent=2))
report+='''
Short solve times include process startup and are noisy; pipeline timing separately includes quadratic validation/deck preparation. Peak commit comes from Windows Job Object process peak; sampled peak working set is recorded separately. Neither is a universal whole-application memory measurement. The GUI heartbeat records continued frame processing, not a claim that every existing rendering/serialization operation is frame-time bounded.

## Lifecycle, failures and corrective actions

Owned Job Objects retain kill-on-close and memory containment. Gmsh settings limits are unchanged. CalculiX/preparation have a 1536 MiB process limit, 120 s normal timeout (maximum 180), bounded logs (4 MiB each), DAT 32 MiB, FRD 128 MiB, request/canonical model 128 MiB and deck 64 MiB. Cancellation and owner death reject publication, including cancellation during preparation. Child cleanup is verified by an independent Windows process-handle probe; Godot's child-process registry is not used to certify grandchild liveness.

Lifecycle receipts include cancel-before, cancel-active, timeout, owner exit, injected owned-worker termination, invalid input/counts, missing executable and recovery for both stages; actual Godot teardown with live Gmsh and live C3D10 children is separately verified. No unrelated process is terminated. Repeated order switching and stale completion are tested through Workbench. No new spontaneous native crash was observed in the successful bounded campaign; deliberate worker termination is labeled fault injection.

Failed attempts are retained with actual exits in attempt-history.json and their immutable directories. Corrections include schema numeric-type membership after binary64 decoding; integral boundary IDs; CalculiX's 20-character numeric token limit (maximum fitting significant digits, independently audited deck coordinate error); a file-replacement race in output monitoring; missing imported-body defaults; curved-face quadrature precision; stale TET4 inspector labels; evidence-directory collisions between identical decks with different timing receipts; and replacing an arbitrary kinematic stress tolerance with propagation of actual DAT print rounding. The failed very fine 0.012 m recovery request reached the unchanged 120 s timeout under concurrent GUI work. The separate practical 0.04 m recovery case completes; the finer failure is not erased or relabeled successful.

## Actual process exits

| Campaign | Outcome | Exit | Seconds | Receipt directory |
|---|---|---:|---:|---|
'''
for mode,receipts in campaigns.items():
    for r in receipts:report+=f"| {mode} / {r['test']} | {r['outcome']} | {r['exit_code']} | {r['seconds']:.3f} | `{Path(r['evidence']).name}` |\n"
report+=f"\nFinal default manifest: {sum(r['passed'] for r in reg)}/{len(reg)} actual exit-zero cases. Nested preservation receipts include STEP bar/cylinder reopen, canonical fingerprints, CAD 2.1 geometry/integration and native modal/transient binaries. Editor scans retain the environment's root-certificate-store warning; it is not a native compatibility crash.\n"
report+='''
## Graphical evidence

Real Godot screenshots, not synthesized images. screens​hots.json records dimensions and SHA-256; both 1280x720 and 1920x1080 are captured. Global/local controls, selected CAD face, quadratic surface mesh, quality/statistics, worst element, displacement, stress, derived strain and saved/reopened current results are covered. Supplementary actual ray-picking evidence shows original node IDs and all four IP tensors. Existing explorer rows intentionally ellipsize long identifiers; full IDs are available in the inspector. The display remains a four-subtriangle approximation of curved TRI6 geometry.

'''
for s in screens:report+=f"- [{Path(s['path']).name}](evidence/cad23/{s['path']}) ({s['width']}x{s['height']})\n"
report+='''
## Reproduction and limitations

Use the installed Python with NumPy and the pinned binaries already present. No installation is necessary:

```powershell
$py = 'C:/Users/Victus/AppData/Local/Python/pythoncore-3.14-64/python.exe'
& $py tests/run_cad23.py unit
& $py tests/run_cad23.py numerical
& $py tests/run_cad23.py independent
& $py tests/run_cad23.py persistence
& $py tests/run_cad23.py lifecycle
& $py tests/run_cad23.py shutdown
& $py tests/run_cad23.py gui
& $py tests/run_cad23.py gui --inspect
& $py tests/run_cad23.py scan
& $py tests/run_cad23.py preservation
& $py tests/run_cad23.py regressions
& $py tests/summarize_cad23.py
```

Do not run multiple numerical campaigns against the same evidence output concurrently. Failed attempts and raw logs remain available. Unsupported scopes include mixed order/types, assemblies/contact, new constitutive models, arbitrary CAD topology repair/scaling and higher-order physics beyond isotropic linear static CalculiX. A valid curved shape can be conservatively rejected by the Bernstein test or resource budgets; refine/coarsen as the diagnostic directs. Stress contours are element tensor means, not a recovered smooth nodal stress field. Timing is machine/load dependent. The historical Godot access violation remains a historical unresolved claim outside these bounded observations. CAD 2.4 and unrelated work were not started.
'''
report+='\nFinal decision: **'+verdict+'**. '+('All recorded mandatory checks above pass within the stated scope.' if verdict=='PASS' else 'Unverified/failed checks: '+', '.join(k for k,v in checks.items() if not v))+ '\n'
(ROOT/'docs/architecture/CAD_MESHING_2_3.md').write_text(report,encoding='utf-8')
print(json.dumps(dict(verdict=verdict,checks=checks),indent=2))
