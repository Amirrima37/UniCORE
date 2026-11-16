# CAD & Meshing 2.3 — PASS

Genuine Gmsh TET10 / CalculiX C3D10 is integrated into the existing Workbench. This verdict covers the bounded, single-solid, isotropic linear static workflow tested here. No assembly/contact capability or universal resolution of the historical Godot access violation is claimed.

## Baseline and changed files

Branch `master`, HEAD `13e40a5a565a273485aa80ea14ed110df36136a2`. The pre-existing dirty tree is preserved in [working-tree-before.txt](evidence/cad23/working-tree-before.txt). CAD 2.1, CAD 2.2, STEP final acceptance and migration reports were inspected before editing. The baseline default manifest passed 28/28 with actual exit 0; see baseline-regressions.json. No native rebuild, executable replacement or dependency download was needed.

Exact production files changed for this checkpoint (source-hashes.json records their final SHA-256):

- `core/cae/cae_document.gd`
- `core/cae/mesh_config.gd`
- `core/cae/calculix_backend.gd`
- `core/cae/calculix_workbench.gd`
- `core/cae/mesh_display.gd`
- `core/cae/mesh_inspection.gd`
- `core/cae/structural_display.gd`
- `ui/cae/analysis_editor.gd`
- `ui/cae/gmsh_mesh_panel.gd`
- `ui/cae/cae_workspace.gd`
- `scripts/engines/mesh_config.py`
- `scripts/engines/gmsh_study.py`
- `scripts/engines/quadratic_tet.py`
- `scripts/engines/quadratic_prepare.py`
- `scripts/engines/owned_execution.py`
- `scripts/engines/run_owned_prepare.py`
- `scripts/engines/run_owned_solver.py`

Acceptance sources are tests/cad23_{unit.py,numerical.gd,independent.py,persistence.gd,lifecycle.py,shutdown.gd,shutdown.py,gui.gd,gui_inspect.gd,smoke.gd}, tests/run_cad23.py and tests/summarize_cad23.py. Prior user changes were not reset. Existing canonical mesh fingerprint and result-identity algorithms were not redesigned.

## Dependencies and preservation

Godot 4.7.2 official ed1daf0bf; Gmsh 4.15.2 with OCCT 7.8.1; CalculiX 2.23. All seven measured pinned executable/DLL hashes match baseline.json and CAD 2.2. No GDExtension rebuild was performed.

| Binary | SHA-256 (before = after) |
|---|---|
| Godot_v4.7.2-stable_win64.exe | `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424` |
| ccx.exe | `27a9426a1ee2f72c38fbe892e0ffaf38e14867628ffd0235770261b6f3ec9c5f` |
| unicore_native.godot472.windows.template_debug.x86_64.dll | `293734a767241b3914f08d9829d6647a3efee5c93a85d375c6744c66296a20cc` |
| unicore_native.godot472.windows.template_release.x86_64.dll | `7d0ab1ba5cb393068bdae4424ae1f754e8574b39a9ff93f7358ee63fad7bd03f` |
| unicore_native.windows.template_debug.x86_64.dll | `e091dee7d29badf2f8a95b9556417ee20be0dc867f12ab067d5a1e68efaea868` |
| unicore_native.windows.template_release.x86_64.dll | `2172eb05b89a7f20a7d39652e7d7253ed499b3e804dea5d8a99b95952498e6eb` |
| gmsh-4.15.dll | `6cac3eefb477265d9fa60bbd869dbbbf7c7ca4cb308c0f8f2b43e91d43de3c1c` |

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

### axial-bar

| Order/level | Nodes / DOFs / elements | Volume error % | Min shape | Tip m | Reference error % | Reaction imbalance | Mesh / solver s | Solver commit MiB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1/0 | 140 / 420 / 307 | 0 | 0.62013 | 4.761905e-07 | 5e-06 | 2e-08 | 0.070 / 0.313 | 162.27 |
| 1/1 | 190 / 570 / 433 | 0 | 0.43306 | 4.761905e-07 | 5e-06 | 2e-08 | 0.101 / 0.094 | 162.28 |
| 1/2 | 594 / 1782 / 1821 | 0 | 0.39461 | 4.761905e-07 | 5e-06 | 1e-08 | 0.163 / 0.359 | 162.49 |
| 1/3 | 1458 / 4374 / 5145 | 0 | 0.40454 | 4.76190493e-07 | 3.6e-06 | 1e-08 | 0.346 / 0.543 | 164.56 |
| 2/0 | 724 / 2172 / 307 | 3.330669e-14 | 0.62013 | 4.761905e-07 | 5e-06 | 1e-08 | 0.323 / 0.347 | 162.25 |
| 2/1 | 998 / 2994 / 433 | 3.330669e-14 | 0.43306 | 4.761905e-07 | 5e-06 | 1e-08 | 0.409 / 0.255 | 162.92 |
| 2/2 | 3518 / 10554 / 1821 | 3.330669e-14 | 0.39461 | 4.761905e-07 | 5e-06 | 5e-08 | 1.607 / 1.096 | 166.33 |
| 2/3 | 9186 / 27558 / 5145 | 3.330669e-14 | 0.40454 | 4.761905e-07 | 5e-06 | 4e-09 | 5.928 / 2.888 | 175.94 |
### axial-cylinder

| Order/level | Nodes / DOFs / elements | Volume error % | Min shape | Tip m | Reference error % | Reaction imbalance | Mesh / solver s | Solver commit MiB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1/0 | 55 / 165 / 114 | 5.779398 | 0.67294 | 3.21026931e-08 | 5.896264 | 3e-08 | 0.046 / 0.340 | 162.26 |
| 1/1 | 124 / 372 / 345 | 2.840962 | 0.43574 | 3.11724504e-08 | 2.827698 | 1e-08 | 0.054 / 0.118 | 162.27 |
| 1/2 | 274 / 822 / 924 | 1.364961 | 0.42496 | 3.07186596e-08 | 1.330791 | 1e-08 | 0.090 / 0.156 | 162.24 |
| 1/3 | 767 / 2301 / 3037 | 0.5788852 | 0.40278 | 3.04841346e-08 | 0.55717 | 2e-09 | 0.204 / 0.407 | 163.20 |
| 2/0 | 275 / 825 / 114 | 0.02642285 | 0.59239 | 3.03211163e-08 | 0.01942586 | 2.21e-08 | 0.144 / 0.111 | 162.23 |
| 2/1 | 701 / 2103 / 345 | 0.006386396 | 0.30325 | 3.03168799e-08 | 0.005451519 | 1.24e-08 | 0.300 / 0.241 | 162.30 |
| 2/2 | 1684 / 5052 / 924 | 0.001432677 | 0.40903 | 3.03156011e-08 | 0.001233054 | 1.3e-09 | 0.744 / 0.485 | 163.95 |
| 2/3 | 5070 / 15210 / 3037 | 0.0002570196 | 0.37482 | 3.03152951e-08 | 0.0002237298 | 3.79e-10 | 2.463 / 1.752 | 169.32 |
### bending

| Order/level | Nodes / DOFs / elements | Volume error % | Min shape | Tip m | Reference error % | Reaction imbalance | Mesh / solver s | Solver commit MiB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1/0 | 140 / 420 / 307 | 0 | 0.62013 | 8.55847542e-05 | 55.068 | 1.73e-06 | 0.069 / 0.167 | 162.28 |
| 1/1 | 190 / 570 / 433 | 0 | 0.43306 | 0.000107963933 | 43.31893 | 9.48e-07 | 0.079 / 0.156 | 162.26 |
| 1/2 | 594 / 1782 / 1821 | 0 | 0.39461 | 0.000152015715 | 20.19175 | 2.16e-06 | 0.162 / 0.216 | 162.48 |
| 1/3 | 1458 / 4374 / 5145 | 0 | 0.40454 | 0.000165553029 | 13.08466 | 9.13e-07 | 0.359 / 0.483 | 164.55 |
| 2/0 | 724 / 2172 / 307 | 3.330669e-14 | 0.62013 | 0.000189773343 | 0.3689948 | 3.46e-07 | 0.291 / 0.244 | 162.23 |
| 2/1 | 998 / 2994 / 433 | 3.330669e-14 | 0.43306 | 0.000190158751 | 0.1666555 | 3.03e-07 | 0.397 / 0.282 | 162.95 |
| 2/2 | 3518 / 10554 / 1821 | 3.330669e-14 | 0.39461 | 0.000190319812 | 0.08209854 | 4.48e-07 | 1.741 / 0.879 | 166.30 |
| 2/3 | 9186 / 27558 / 5145 | 3.330669e-14 | 0.40454 | 0.000190505858 | 0.01557543 | 3.35e-07 | 4.806 / 2.415 | 175.92 |
### step-hole

| Order/level | Nodes / DOFs / elements | Volume error % | Min shape | Tip m | Reference error % | Reaction imbalance | Mesh / solver s | Solver commit MiB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1/0 | 864 / 2592 / 2936 | 1.140718 | 0.29328 | 5.38543617e-07 | 1.117672 | 1e-08 | 0.229 / 0.361 | 163.24 |
| 1/1 | 1708 / 5124 / 5352 | 0.4801503 | 0.22467 | 5.42059309e-07 | 0.4721532 | 4e-09 | 0.589 / 0.526 | 164.74 |
| 1/2 | 2876 / 8628 / 8548 | 0.2676443 | 0.068093 | 5.43210544e-07 | 0.2607743 | 4e-09 | 0.733 / 0.924 | 166.82 |
| 1/3 | 4227 / 12681 / 12221 | 0.1784581 | 0.17457 | 5.43687693e-07 | 0.1731646 | 6e-09 | 1.180 / 1.276 | 168.77 |
| 2/0 | 5408 / 16224 / 2936 | 0.007094233 | 0.0779 | 5.44593963e-07 | 0.006763966 | 2.27e-08 | 2.339 / 1.435 | 169.80 |
| 2/1 | 10281 / 30843 / 5352 | 0.001232977 | 0.17189 | 5.44624489e-07 | 0.001158997 | 2.02e-08 | 5.454 / 2.964 | 175.91 |
| 2/2 | 16899 / 50697 / 8548 | 0.000385579 | 0.068093 | 5.44628938e-07 | 0.0003421845 | 1.12e-08 | 9.405 / 5.579 | 199.80 |
| 2/3 | 24537 / 73611 / 12221 | 0.0001683139 | 0.1407 | 5.44629995e-07 | 0.0001479666 | 2.16e-08 | 14.747 / 8.506 | 294.41 |

| Order/level | Max VM of displayed mean tensor Pa | VM at fixed sample Pa |
|---|---:|---:|
| 1/0 | 117985.411 | 113097.561 |
| 1/1 | 116337.002 | 113837.184 |
| 1/2 | 116681.213 | 114071.013 |
| 1/3 | 116185.838 | 114169.197 |
| 2/0 | 114438.663 | 114364.599 |
| 2/1 | 114391.803 | 114371.098 |
| 2/2 | 114382.283 | 114372.003 |
| 2/3 | 114376.554 | 114372.3 |

Independent equilibrium summary: maximum normalized force imbalance 2.15603803e-06; maximum applied-moment discrepancy divided by 1000 N 2.01563505e-09 m. Actual deck forces and moments are audited against a separately integrated physical mesh boundary; the small centroid offset of a faceted cylinder is not silently replaced by the exact CAD centroid. See applied_moment_Nm and independent_surface_moment_Nm in independent-audit.json.

The bar patch is effectively order invariant within printed-output precision. Both curved cases show materially lower geometric and axial error with TET10. Bending TET4 remains stiff; TET10 greatly improves the beam-reference comparison. The finest TET10 result crosses the Euler–Bernoulli reference, so a small absolute reference error is not proof of convergence to the exact 3D continuum. The Timoshenko correction is about 0.78% of EB deflection; clamp/end-traction effects remain. Observed reference-error rates in the CSV are descriptive only: curvature/local rules also change, and near-zero or sign-crossing errors cannot establish formal element convergence order. No peak-stress convergence claim is made.

## Comparable cost

For each quadratic level the CSV retains accuracy-per-DOF, per solver second and per peak committed MiB, defined as 1/(relative reference error * cost). These proxies are inappropriate for a patch at the output rounding floor and are not universal efficiency scores. Identical geometric-size comparisons are in the full tables. The closest available DOF, solver-time and memory comparisons are chosen mechanically, without selecting the best accuracy outcome:

| Case / cost matched | TET4 level / cost | TET10 level / cost | TET4 error % | TET10 error % |
|---|---:|---:|---:|---:|
| axial-cylinder / dofs | 2 / 822 | 0 / 825 | 1.33079 | 0.0194259 |
| axial-cylinder / solver_process_s | 1 / 0.117879 | 0 / 0.111139 | 2.8277 | 0.0194259 |
| axial-cylinder / solver_peak_commit_MiB | 2 / 162.238 | 0 / 162.234 | 1.33079 | 0.0194259 |
| bending / dofs | 2 / 1782 | 0 / 2172 | 20.1917 | 0.368995 |
| bending / solver_process_s | 2 / 0.215933 | 0 / 0.244355 | 20.1917 | 0.368995 |
| bending / solver_peak_commit_MiB | 1 / 162.262 | 0 / 162.234 | 43.3189 | 0.368995 |
| step-hole / dofs | 3 / 12681 | 0 / 16224 | 0.173165 | 0.00676397 |
| step-hole / solver_process_s | 3 / 1.27562 | 0 / 1.43492 | 0.173165 | 0.00676397 |
| step-hole / solver_peak_commit_MiB | 3 / 168.77 | 0 / 169.797 | 0.173165 | 0.00676397 |

Short solve times include process startup and are noisy; pipeline timing separately includes quadratic validation/deck preparation. Peak commit comes from Windows Job Object process peak; sampled peak working set is recorded separately. Neither is a universal whole-application memory measurement. The GUI heartbeat records continued frame processing, not a claim that every existing rendering/serialization operation is frame-time bounded.

## Lifecycle, failures and corrective actions

Owned Job Objects retain kill-on-close and memory containment. Gmsh settings limits are unchanged. CalculiX/preparation have a 1536 MiB process limit, 120 s normal timeout (maximum 180), bounded logs (4 MiB each), DAT 32 MiB, FRD 128 MiB, request/canonical model 128 MiB and deck 64 MiB. Cancellation and owner death reject publication, including cancellation during preparation. Child cleanup is verified by an independent Windows process-handle probe; Godot's child-process registry is not used to certify grandchild liveness.

Lifecycle receipts include cancel-before, cancel-active, timeout, owner exit, injected owned-worker termination, invalid input/counts, missing executable and recovery for both stages; actual Godot teardown with live Gmsh and live C3D10 children is separately verified. No unrelated process is terminated. Repeated order switching and stale completion are tested through Workbench. No new spontaneous native crash was observed in the successful bounded campaign; deliberate worker termination is labeled fault injection.

Failed attempts are retained with actual exits in attempt-history.json and their immutable directories. Corrections include schema numeric-type membership after binary64 decoding; integral boundary IDs; CalculiX's 20-character numeric token limit (maximum fitting significant digits, independently audited deck coordinate error); a file-replacement race in output monitoring; missing imported-body defaults; curved-face quadrature precision; stale TET4 inspector labels; evidence-directory collisions between identical decks with different timing receipts; and replacing an arbitrary kinematic stress tolerance with propagation of actual DAT print rounding. The failed very fine 0.012 m recovery request reached the unchanged 120 s timeout under concurrent GUI work. The separate practical 0.04 m recovery case completes; the finer failure is not erased or relabeled successful.

## Actual process exits

| Campaign | Outcome | Exit | Seconds | Receipt directory |
|---|---|---:|---:|---|
| unit / unit | PASS | 0 | 26.356 | `unit-1794613934033346500` |
| numerical / numerical | PASS | 0 | 326.304 | `numerical-1794611976677743000` |
| independent / independent | PASS | 0 | 12.326 | `independent-1794615942083985200` |
| persistence / persistence | PASS | 0 | 41.852 | `persistence-1794613160946957500` |
| lifecycle / lifecycle | PASS | 0 | 93.603 | `lifecycle-1794613838832827200` |
| shutdown / shutdown | PASS | 0 | 56.958 | `shutdown-1794613550904868200` |
| gui / gui | PASS | 0 | 246.213 | `gui-1794613540092257100` |
| gui_inspect / gui_inspect | PASS | 0 | 22.347 | `gui-1794615842674086700` |
| scan / scan | PASS | 0 | 23.107 | `scan-1794614955588692800` |
| preservation / cad22-preservation | PASS | 0 | 122.000 | `preservation-1794613044037589800` |
| preservation / cad22-validation | PASS | 0 | 6.235 | `preservation-1794613044037589800` |
| regressions / regressions | PASS | 0 | 40.734 | `regressions-1794615854096520300` |

Final default manifest: 28/28 actual exit-zero cases. Nested preservation receipts include STEP bar/cylinder reopen, canonical fingerprints, CAD 2.1 geometry/integration and native modal/transient binaries. Editor scans retain the environment's root-certificate-store warning; it is not a native compatibility crash.

## Graphical evidence

Real Godot screenshots, not synthesized images. screens​hots.json records dimensions and SHA-256; both 1280x720 and 1920x1080 are captured. Global/local controls, selected CAD face, quadratic surface mesh, quality/statistics, worst element, displacement, stress, derived strain and saved/reopened current results are covered. Supplementary actual ray-picking evidence shows original node IDs and all four IP tensors. Existing explorer rows intentionally ellipsize long identifiers; full IDs are available in the inspector. The display remains a four-subtriangle approximation of curved TRI6 geometry.

- [corrected-stress-association-1280.png](evidence/cad23/screenshots/corrected-stress-association-1280.png) (1280x720)
- [corrected-stress-association-1920.png](evidence/cad23/screenshots/corrected-stress-association-1920.png) (1920x1080)
- [displacement-1280.png](evidence/cad23/screenshots/displacement-1280.png) (1280x720)
- [displacement-1920.png](evidence/cad23/screenshots/displacement-1920.png) (1920x1080)
- [engineering-strain-1280.png](evidence/cad23/screenshots/engineering-strain-1280.png) (1280x720)
- [engineering-strain-1920.png](evidence/cad23/screenshots/engineering-strain-1920.png) (1920x1080)
- [local-face-refinement-1280.png](evidence/cad23/screenshots/local-face-refinement-1280.png) (1280x720)
- [local-face-refinement-1920.png](evidence/cad23/screenshots/local-face-refinement-1920.png) (1920x1080)
- [mesh-statistics-1280.png](evidence/cad23/screenshots/mesh-statistics-1280.png) (1280x720)
- [mesh-statistics-1920.png](evidence/cad23/screenshots/mesh-statistics-1920.png) (1920x1080)
- [quadratic-bending-displacement-1280.png](evidence/cad23/screenshots/quadratic-bending-displacement-1280.png) (1280x720)
- [quadratic-bending-displacement-1920.png](evidence/cad23/screenshots/quadratic-bending-displacement-1920.png) (1920x1080)
- [quadratic-bending-von-mises-1280.png](evidence/cad23/screenshots/quadratic-bending-von-mises-1280.png) (1280x720)
- [quadratic-bending-von-mises-1920.png](evidence/cad23/screenshots/quadratic-bending-von-mises-1920.png) (1920x1080)
- [quadratic-quality-1280.png](evidence/cad23/screenshots/quadratic-quality-1280.png) (1280x720)
- [quadratic-quality-1920.png](evidence/cad23/screenshots/quadratic-quality-1920.png) (1920x1080)
- [quadratic-through-hole-mesh-1280.png](evidence/cad23/screenshots/quadratic-through-hole-mesh-1280.png) (1280x720)
- [quadratic-through-hole-mesh-1920.png](evidence/cad23/screenshots/quadratic-through-hole-mesh-1920.png) (1920x1080)
- [saved-reopened-current-1280.png](evidence/cad23/screenshots/saved-reopened-current-1280.png) (1280x720)
- [saved-reopened-current-1920.png](evidence/cad23/screenshots/saved-reopened-current-1920.png) (1920x1080)
- [selected-c3d10-integration-points-1280.png](evidence/cad23/screenshots/selected-c3d10-integration-points-1280.png) (1280x720)
- [selected-c3d10-integration-points-1920.png](evidence/cad23/screenshots/selected-c3d10-integration-points-1920.png) (1920x1080)
- [selected-cad-face-1280.png](evidence/cad23/screenshots/selected-cad-face-1280.png) (1280x720)
- [selected-cad-face-1920.png](evidence/cad23/screenshots/selected-cad-face-1920.png) (1920x1080)
- [selected-quadratic-node-1280.png](evidence/cad23/screenshots/selected-quadratic-node-1280.png) (1280x720)
- [selected-quadratic-node-1920.png](evidence/cad23/screenshots/selected-quadratic-node-1920.png) (1920x1080)
- [tet10-settings-1280.png](evidence/cad23/screenshots/tet10-settings-1280.png) (1280x720)
- [tet10-settings-1920.png](evidence/cad23/screenshots/tet10-settings-1920.png) (1920x1080)
- [von-mises-1280.png](evidence/cad23/screenshots/von-mises-1280.png) (1280x720)
- [von-mises-1920.png](evidence/cad23/screenshots/von-mises-1920.png) (1920x1080)
- [worst-element-integration-jacobians-1280.png](evidence/cad23/screenshots/worst-element-integration-jacobians-1280.png) (1280x720)
- [worst-element-integration-jacobians-1920.png](evidence/cad23/screenshots/worst-element-integration-jacobians-1920.png) (1920x1080)
- [worst-element-metrics-1280.png](evidence/cad23/screenshots/worst-element-metrics-1280.png) (1280x720)
- [worst-element-metrics-1920.png](evidence/cad23/screenshots/worst-element-metrics-1920.png) (1920x1080)

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

Final decision: **PASS**. All recorded mandatory checks above pass within the stated scope.
