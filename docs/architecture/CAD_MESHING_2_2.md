# CAD & Meshing 2.2 — PASS

This checkpoint adds engineering mesh controls to the existing Godot 4.7.2 Workbench and pinned Gmsh/OCCT → CalculiX pipeline. The verdict applies to the tested single-solid, linear static structural TET4 workflow. It does not promote CAD 2.1's deferred validity/history/scaling capabilities to production status or claim a universally resolved historical Godot crash.

## Baseline and exact changed production files

The existing dirty tree was recorded before editing: [working-tree-before.txt](evidence/cad22/working-tree-before.txt). Existing CAD 2.1, STEP final acceptance and migration reports and native regression infrastructure were inspected. Binary hashes were measured before editing and compared afterward; all 7 pinned executable/DLL hashes are unchanged. No GDExtension rebuild or new dependency was required. See binary-hashes-before.json, binary-hashes-after.json and source-hashes.json. Runtime: Godot 4.7.2 stable official ed1daf0bf; Gmsh 4.15.2 with OCCT 7.8.1; CalculiX 2.23.

- `core/cae/mesh_config.gd`
- `core/cae/cae_document.gd`
- `core/cae/calculix_workbench.gd`
- `core/cae/result_identity.gd`
- `core/cae/mesh_inspection.gd`
- `ui/cae/gmsh_mesh_panel.gd`
- `ui/cae/cae_workspace.gd`
- `scripts/engines/mesh_config.py`
- `scripts/engines/mesh_quality.py`
- `scripts/engines/gmsh_study.py`
- `scripts/engines/owned_mesh_job.py`
- `scripts/engines/run_owned_mesh.py`
- `scripts/engines/process_memory.py`
- `scripts/engines/run_owned_solver.py`

New acceptance files are `tests/cad22_validation.py`, `cad22_numerical.gd`, `cad22_independent.py`, `cad22_persistence.gd`, `cad22_lifecycle.py`, `cad22_pid_probe.py`, `cad22_gui.gd`, `run_cad22.py` and `summarize_cad22.py`. Existing user modifications, native kernels and binary mappings were preserved.

## Implementation and sizing mechanisms

`part.mesh_settings` is a complete explicit schema-1 configuration. SI metre fields are global target/min/max size; curvature is elements per 2*pi; boundary extension is a boolean. Supported 3D algorithms are Delaunay (Gmsh 1) and HXT (10), both exercised against the pinned SDK. Optimization choices are none, Gmsh or Netgen, with 1..5 passes. Node/element caps, timeout, worker memory, minimum mean ratio and maximum edge ratio are validated. Missing/unknown fields or schema versions, nonfinite numbers, bad bounds, incompatible face rules and unreasonable budgets are rejected, not silently clamped.

Actual Gmsh options include Mesh.MeshSizeMin/Max, Mesh.MeshSizeFromCurvature, Mesh.MeshSizeFromPoints=0 for configured jobs, Mesh.MeshSizeExtendFromBoundary, Mesh.Algorithm3D, and explicit optimize calls after measuring the generated mesh. A constant MathEval field supplies the global target. Each enabled face rule creates Distance(SurfacesList, Sampling=100) plus Threshold(SizeMin, SizeMax, DistMin, DistMax); Min combines these fields. Face mode transitions over one local element size; distance mode uses editable fine/coarse distances. These are real volume-mesh controls, separate from display tessellation. See the official [Gmsh sizing and OCC reference](https://gmsh.info/doc/texinfo/).

Configuration caps: sizes 1e-6..1000 m; curvature 0..100 elements/circle; max nodes up to 200000 and max TET4 up to 1000000; timeout 0.1..180 s; child memory 768..4096 MiB; at most 64 local rules. Preflight estimates reject excessive global/local density and extreme span/min-size ratios. Exact node/element counts are checked before and after optimization; quality thresholds are enforced before publication. Estimates are safeguards, not promises of a particular element count.

The Mesh workspace exposes global settings, local CAD face rules, generation/cancel controls, current/stale status, CAD/mesh volume statistics, histogram and worst element. Existing Inspection rendering, section controls, element selection, camera and legends provide quality contours and ID/connectivity/metric readout. Surface/edge/invalid modes reuse the existing infrastructure. Quality and meshing calculations run in workers; only render-resource publication runs on the Godot main thread.

## Provenance, persistence and topology

Every configured mesh records the exact effective settings, geometry revision, geometry snapshot, deterministic generation ID, quality statistics, optimization measurements, timing and owned-process receipt. A changed settings snapshot or geometry refuses solving with the retained stale mesh. Result identity still uses the existing versioned canonical SHA-256 mesh fingerprint, whose implementation and semantics were not changed. Relevant material/load/support/analysis edits continue to invalidate results under existing rules.

One-ULP drift and int/float representation differences were observed in the initial settings exchange. New settings therefore have explicit binary64 numeric transport between Godot and Python, and `unicore-mesh-settings-v1` lossless project storage, including result model-parts snapshots. Exact numeric encoding normalizes integral int/float representations while preserving binary64 value changes. This is a settings protocol, not a weakened mesh fingerprint or a JSON-tolerance comparison. Existing lossless mesh persistence is preserved.

Legacy CAD 2.1/STEP projects without mesh settings keep their old sizing path. Unknown settings encodings/schema or corrupt config payloads are rejected before replacing the active document. New configured meshes remain current on unchanged save/reopen. Tests cover schema/encoding corruption, NaN, invalid face references, settings Undo, stale worker publication, save during meshing, and cancel before launch.

Face rules retain CAD 2.1 IDs. A Boolean edit that removes/modifies a rule's face disables it and sets needs_review while retaining the original face ID and editable values. It cannot reach Gmsh enabled until explicitly reviewed/rebound. There is no nearest-face fallback. Source units remain explicit; all FEM coordinates and internal lengths are metres, forces N, moduli/stresses Pa. UI sizing distances display mm. CAD and mesh volumes are distinct quantities in m3.

## Quality definitions and independent checks

All backend metrics use actual node coordinates in Python binary64:

- Signed determinant det J = (b-a) dot ((c-a) cross (d-a)), units m3; signed volume V=det J/6. Negative determinants are inverted; abs(det J) <= 1e-12*longest_edge^3 is the relative degeneracy test. Invalid connectivity, nonpositive orientation, nonmanifold faces and exterior triangle coverage mismatches are rejected.
- Edge ratio = longest of six edges / shortest edge, dimensionless. Edge min/max/mean are metres; the mean counts six edge incidences per tetrahedron, not unique global edges.
- Tetrahedron mean ratio q = 12*(3*abs(V))^(2/3)/sum(six edge lengths squared), dimensionless, 1 for a regular tet. Raw Jacobian magnitude is not treated as a scale-independent score.
- Histograms count real elements in ten mean-ratio bins, [0,.1), …, [.9,1]. Worst element is the minimum-q zero-based element ID, with real node IDs and metric readout. Backend metric values are reused by the existing graphical inspector.

Independent regular/inverted/coplanar tetrahedron cases verify these definitions. Every numerical case is also audited by a separate Python DAT parser and determinant computation from the actual canonical solver model; input/DAT SHA-256, finite fields, counts, applied force, constrained reactions and loaded-face displacement means are verified. Actual solver files are archived under solver-jobs/. No CalculiX output is used as its own analytical reference.

### Isolated face-local density test

Both runs use identical global h=0.05 m, curvature=8 and disabled boundary extension. Only the cylindrical-hole distance rule changes. The local setting is h=0.008 m, fine zone 0.003 m, transition to coarse at 0.025 m.

| Local rule | Hole surface nodes | Hole triangles | Mean hole-surface edge (m) | Total nodes | TET4 |
|---|---:|---:|---:|---:|---:|
| False | 596 | 1176 | 0.015635676 | 942 | 3238 |
| True | 2006 | 3980 | 0.0085837654 | 2728 | 9411 |

This demonstrates actual local density change, not merely a larger global count.

### Optimization measurements

| Case | Min q before | Min q after | Nodes after | TET4 after |
|---|---:|---:|---:|---:|
| algorithm-delaunay-none | 0.10381426 | 0.10381426 | 108 | 276 |
| algorithm-delaunay-netgen | 0.10381426 | 0.53619943 | 136 | 434 |
| algorithm-hxt-gmsh | 0.10381426 | 0.47421083 | 110 | 282 |

None correctly leaves the measured minimum unchanged. The tested optimized cases improve the measured minimum; no universal improvement guarantee is asserted.

## Numerical refinement campaign

All sixteen levels use genuine STEP/BREP geometry, actual Gmsh TET4, the existing CalculiX adapter and pinned ccx executable. E=210 GPa; force magnitude=1000 N distributed by actual boundary-triangle area; lower Y end fixed. Axial cases use nu=0 to isolate the uniform-strain reference; bending uses nu=0.3. The bar is 0.1 x 1 x 0.1 m (A=.01 m2); the cylinder is radius .1 m and L=.2 m; the STEP-hole bar is the original 1 m bar cut by an axial radius-.02 m cylinder, A=.01-pi*.02^2. All settings and complete flattened measurements are in [convergence.csv](evidence/cad22/convergence.csv), [numerical.json](evidence/cad22/numerical.json) and [independent-audit.json](evidence/cad22/independent-audit.json).

Axial reference is FL/(EA). Bending reference is Euler–Bernoulli FL^3/(3EI), I=.1^4/12, u=1.90476190476e-4 m. It assumes a slender prismatic beam, small displacement and negligible shear. Timoshenko's approximate shear contribution F*L/[(5/6)*G*A], G=E/[2(1+nu)], is 1.485714286e-6 m, about 0.78% of that reference. The 3D clamped solid and beam model are different idealizations. TET4 stiffness and clamp/end effects remain; approaching the beam value is not proof of continuum convergence.

Meshing h sequences for bar/bending/cylinder are .07, .05, .0333333, .0222222 m. Cylinder curvature levels are 0,12,18,24. For the STEP-hole bar, global h=.05 m throughout, min h=.002 m and boundary extension off; curvature levels are 8,12,18,24. Hole local sizes at levels 1..3 are .015,.008,.005 m with fine/coarse distances .003/.025 m. Every case uses Delaunay and one Gmsh optimization pass, default quality/resource limits. Curvature and local settings deliberately vary together in the hole study; the isolated experiment above separates local-density effects.

Table units: volumes m3; displacement m; stress Pa; reaction imbalance ||sum(R)+F||/1000, using independent binary64 sums from DAT. Mesh memory is Windows Job Object peak process commit; solver memory is observed peak working set, different measurements, both in MiB.

### axial-bar — exact OCCT volume 0.01 m3

| Level | Nodes | TET4 | Mesh volume | Volume error % | Min q | Max u | Tip mean | Reference | u error % | Max VM | Reaction imbalance | Mesh s | Solver s | Mesh MiB | Solver MiB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 140 | 307 | 0.01 | 0 | 0.62013 | 4.76190507e-07 | 4.761905e-07 | 4.76190476e-07 | 5e-06 | 100000 | 2e-08 | 0.061 | 1.324 | 611.71 | 8.59 |
| 1 | 190 | 433 | 0.01 | 0 | 0.43306 | 4.76190507e-07 | 4.761905e-07 | 4.76190476e-07 | 5e-06 | 100000 | 2e-08 | 0.074 | 2.392 | 612.91 | 8.86 |
| 2 | 594 | 1821 | 0.01 | 0 | 0.39461 | 4.76190507e-07 | 4.761905e-07 | 4.76190476e-07 | 5e-06 | 100000 | 1e-08 | 0.140 | 2.594 | 613.81 | 11.65 |
| 3 | 1458 | 5145 | 0.01 | 0 | 0.40454 | 4.76190507e-07 | 4.76190493e-07 | 4.76190476e-07 | 3.6e-06 | 100000 | 1e-08 | 0.294 | 2.828 | 620.20 | 18.72 |

Observed error rates against effective h=(CAD volume / TET4 count)^(1/3): not meaningful at the printed-output error floor. These are empirical diagnostics under changing fields, not certified asymptotic convergence orders.

### axial-cylinder — exact OCCT volume 0.00628318530718 m3

| Level | Nodes | TET4 | Mesh volume | Volume error % | Min q | Max u | Tip mean | Reference | u error % | Max VM | Reaction imbalance | Mesh s | Solver s | Mesh MiB | Solver MiB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 55 | 114 | 0.005920055041 | 5.7794 | 0.67294 | 3.23954694e-08 | 3.21026931e-08 | 3.03152273e-08 | 5.89626 | 34364.317 | 3e-08 | 0.028 | 1.427 | 611.82 | 8.51 |
| 1 | 124 | 345 | 0.006104682379 | 2.841 | 0.43574 | 3.13104067e-08 | 3.11724504e-08 | 3.03152273e-08 | 2.8277 | 33438.53 | 1e-08 | 0.044 | 2.372 | 610.99 | 8.56 |
| 2 | 274 | 924 | 0.006197422258 | 1.365 | 0.42496 | 3.07907477e-08 | 3.07186596e-08 | 3.03152273e-08 | 1.33079 | 32495.257 | 1e-08 | 0.068 | 2.493 | 612.90 | 9.56 |
| 3 | 767 | 3037 | 0.006246812878 | 0.57889 | 0.40278 | 3.05201127e-08 | 3.04841346e-08 | 3.03152273e-08 | 0.55717 | 32220.53 | 2e-09 | 0.156 | 2.728 | 616.02 | 14.02 |

Observed error rates against effective h=(CAD volume / TET4 count)^(1/3): 1.991, 2.295, 2.195. These are empirical diagnostics under changing fields, not certified asymptotic convergence orders.

### bending — exact OCCT volume 0.01 m3

| Level | Nodes | TET4 | Mesh volume | Volume error % | Min q | Max u | Tip mean | Reference | u error % | Max VM | Reaction imbalance | Mesh s | Solver s | Mesh MiB | Solver MiB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 140 | 307 | 0.01 | 0 | 0.62013 | 8.58751519e-05 | 8.55847542e-05 | 0.00019047619 | 55.068 | 3504141 | 1.735e-06 | 0.059 | 1.441 | 611.37 | 8.60 |
| 1 | 190 | 433 | 0.01 | 0 | 0.43306 | 0.000108270993 | 0.000107963933 | 0.00019047619 | 43.3189 | 4688116.4 | 9.482e-07 | 0.092 | 1.557 | 612.82 | 8.86 |
| 2 | 594 | 1821 | 0.01 | 0 | 0.39461 | 0.000152449793 | 0.000152015715 | 0.00019047619 | 20.1917 | 5321354.5 | 2.156e-06 | 0.137 | 2.652 | 613.82 | 11.64 |
| 3 | 1458 | 5145 | 0.01 | 0 | 0.40454 | 0.000166021186 | 0.000165553029 | 0.00019047619 | 13.0847 | 5800977.2 | 9.125e-07 | 0.302 | 2.903 | 619.72 | 18.74 |

Observed error rates against effective h=(CAD volume / TET4 count)^(1/3): 2.094, 1.594, 1.253. These are empirical diagnostics under changing fields, not certified asymptotic convergence orders.

### step-hole — exact OCCT volume 0.00874336293856 m3

| Level | Nodes | TET4 | Mesh volume | Volume error % | Min q | Max u | Tip mean | Reference | u error % | Max VM | Reaction imbalance | Mesh s | Solver s | Mesh MiB | Solver MiB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 942 | 3238 | 0.00884310003 | 1.1407 | 0.28291 | 5.38820188e-07 | 5.38545613e-07 | 5.44630801e-07 | 1.11731 | 117884.81 | 2e-08 | 0.210 | 2.639 | 616.37 | 14.32 |
| 1 | 1928 | 6747 | 0.008785344222 | 0.48015 | 0.30793 | 5.42198165e-07 | 5.42059425e-07 | 5.44630801e-07 | 0.472132 | 116052.51 | 1.8e-08 | 0.544 | 1.537 | 653.60 | 22.50 |
| 2 | 4199 | 14977 | 0.008762272756 | 0.21628 | 0.26458 | 5.43555927e-07 | 5.43486982e-07 | 5.44630801e-07 | 0.210017 | 116491.54 | 9e-09 | 1.020 | 2.524 | 673.57 | 41.03 |
| 3 | 7873 | 27855 | 0.008753201685 | 0.11253 | 0.22414 | 5.44062118e-07 | 5.440347e-07 | 5.44630801e-07 | 0.109451 | 115655.11 | 2.36e-08 | 2.320 | 5.373 | 700.64 | 69.73 |

Observed error rates against effective h=(CAD volume / TET4 count)^(1/3): 3.520, 3.048, 3.151. These are empirical diagnostics under changing fields, not certified asymptotic convergence orders.

The axial bar stagnates near printed-output precision; increasing elements is not evidence of improved physical accuracy there. Cylinder geometry and displacement errors decrease. Bending improves from 55.1% to 13.1% error but remains materially too stiff on the tested TET4 meshes. No converged continuum bending or industrial accuracy claim is made.

The STEP-hole mesh-volume error improves from the CAD 2.1 coarse baseline of about 4.916% to 1.141%, .480%, .216% and .113% in this campaign; displacement error decreases to .109%. Geometry approximation improved substantially, but CAD volume was never replaced by mesh volume. Baseline source/evidence remains in CAD_MESHING_2_1.md. All stress maxima and their actual element centroids are retained in numerical.json/CSV. Maxima alone are not used to claim stress convergence.

For a physical sample away from the clamp and hole edge, the independent checker finds the tetrahedron containing (0.087,0.487,0.083) m and reports its constant TET4 integration-point von Mises stress. This is a fixed point, not an arbitrarily chosen node or a nearest-element fallback:

| Hole level | Sample VM (Pa) | Max VM (Pa) | Max-stress centroid (m) |
|---|---:|---:|---|
| 0 | 113099.12 | 117884.812 | [0.03176556155085564, 0.9940838813781738, 0.06330470740795135] |
| 1 | 113836.658 | 116052.511 | [0.0632694661617279, 0.9959951043128967, 0.06769227981567383] |
| 2 | 114130.592 | 116491.536 | [0.05868496373295784, 0.9972236752510071, 0.06943368911743164] |
| 3 | 114245.219 | 115655.107 | [0.04833000898361206, 0.6198585033416748, 0.028823504224419594] |

The sample stabilizes under these refinements; that does not certify the peak stress, singular clamp behavior or arbitrary hole-loading cases.

## Graphical acceptance

The actual Godot Workbench opens the saved refined STEP-hole study, exposes and applies settings, regenerates a mesh, rejects the old result, renders mesh/quality/worst-element views, runs a new CalculiX solve and verifies save/reopen freshness. GUI heartbeat frames are recorded in gui-details.json. Screenshots are actual viewport captures at 1280x720 and 1920x1080, with dimensions and hashes in screenshots.json. No synthetic evidence was generated.

Examples: [Global settings](evidence/cad22/screenshots/global-settings-1280.png), [local face rule](evidence/cad22/screenshots/local-face-refinement-1280.png), [refined hole mesh](evidence/cad22/screenshots/refined-through-hole-mesh-1920.png), [quality contour](evidence/cad22/screenshots/mean-ratio-quality-1920.png), [worst element](evidence/cad22/screenshots/worst-element-metrics-1920.png), [mesh statistics](evidence/cad22/screenshots/mesh-statistics-1280.png), [displacement](evidence/cad22/screenshots/refined-displacement-1280.png), [von Mises](evidence/cad22/screenshots/refined-von-mises-1920.png).

Visual review caught vertical wrapping in the first settings-dialog capture despite its scripted run exiting 0. Fixed-width label columns and scrollable pages corrected it; the rerun adds a dialog-size assertion and the final screenshots were inspected for legibility. Original attempt receipts/logs are retained; an exit-0 script alone was not treated as sufficient GUI acceptance.

## Resource/lifecycle and failure evidence

Every volume Gmsh worker uses a Windows kill-on-close Job Object and configured memory cap, monitors its owner, accepts cancellation and has an explicit timeout. Input is capped at 128 MiB before JSON loading; response at 192 MiB before acceptance. Reader threads cap individual stdout/stderr files at 4 MiB, discard excess and trigger termination. The helper waits for its child and records terminal state, exit, timing and peak commit. OCCT temporary source files are job-local. Exact connectivity/boundaries, counts and quality are checked before mesh publication. Old valid mesh/results are retained when changing settings but marked stale. New stale or failed jobs do not replace them.

The existing Workbench snapshot signature rejects a mesh completed after settings change. Tests cover save during meshing, early cancel, active child cancel, zero-deadline timeout, failed config/quality/budget paths, oversized request, recovery and owner exit. Godot shutdown while an owned Gmsh child is observed active is also checked; it cancels/joins and leaves no live child PID. Acceptance job evidence is deliberately retained. No automatic aggregate retention sweep was added, so successful/failed job folders still require managed archival/cleanup; this is a storage-management limitation, not unbounded active work.

| Scenario | Helper exit | State | Peak commit MiB | Outcome |
|---|---:|---|---:|---|
| cancel | 1 | cancelled | 0.48 | PASS |
| timeout | 1 | timeout | 0.45 | PASS |
| owner-exit | 0 | owner_exited | 3.49 | PASS |
| counts | 1 | failed | 607.32 | PASS |
| quality | 1 | failed | 633.33 | PASS |
| pathological | 1 | failed | 607.40 | PASS |
| invalid-config | 1 | failed | 0.00 | PASS |
| oversize-request | 1 | failed | 0.00 | PASS |
| recovery | 0 | completed | 633.20 | PASS |

Initial failed attempts are indexed in attempt-history.json with raw streams in timestamped directories. They include a native Gmsh overlapping-facet rejection when curvature sizing was disabled on the coarse hole and boundary extension was off; changing the 2D algorithm alone did not fix it. Curvature-aware configurations were then tested explicitly; no hidden fallback accepted the invalid mesh. Failure messages point to the owned log and suggest curvature/smaller sizes or coarser sizes for resource limits. Other fixes addressed exact settings transport/int-float comparison and early stale-solve rejection. One validation attempt also exposed a test path-concatenation error, which was corrected. The initial shutdown observation used Godot's PID query for a child launched indirectly by Python; the final check uses an independent Windows SYNCHRONIZE-handle probe, retaining both live-before-shutdown and gone-after-shutdown assertions. Earlier observation failures remain recorded. No assertions were relaxed to accept an invalid mesh or stale result.

No new native access violation was observed in this campaign. The retained historical crash evidence and CAD 2.1 limits remain valid.

## Actual campaign exits and preservation

| Campaign | Actual exits | Outcome |
|---|---|---|
| validation | 0 | PASS |
| numerical | 0 | PASS |
| independent | 0 | PASS |
| persistence | 0 | PASS |
| lifecycle | 0 | PASS |
| gui | 0 | PASS |
| scan | 0 | PASS |
| preservation | 0, 0, 0 | PASS |
| regressions | 0 | PASS |

Default manifest: 28/28 passed, all actual exits zero: True. Detailed default receipts: `docs\architecture\evidence\cad22\regressions-1794608391040644000\default`.

Preservation includes genuine CAD 2.1 Boolean geometry/Gmsh/CalculiX tests, original STEP bar/cylinder save/reopen, canonical fingerprints, modal (580 checks) and Newmark transient checks. No structural/thermal/modal/transient/Extreme kernels or pinned DLLs/executables were replaced. Existing default thermal/Extreme tests remain in the 28-suite campaign. Final parser/editor scan is recorded independently. Python compile checks are also run; root-certificate warnings remain in Godot logs.

## Reproduction, scope and decision

From repository root, PYTHON is `C:/Users/Victus/AppData/Local/Python/pythoncore-3.14-64/python.exe`. The runner supplies the existing local APPDATA/LOCALAPPDATA directories and UNICORE_PYTHON; it invokes the unchanged pinned Godot executable.

```text
PYTHON tests/run_cad22.py validation
PYTHON tests/run_cad22.py numerical
PYTHON tests/run_cad22.py independent
PYTHON tests/run_cad22.py persistence
PYTHON tests/run_cad22.py lifecycle
PYTHON tests/run_cad22.py gui
PYTHON tests/run_cad22.py scan
PYTHON tests/run_cad22.py preservation
PYTHON tests/run_cad22.py regressions
PYTHON tests/summarize_cad22.py
```

Known limitations: the tested FEM path remains single-solid TET4 and the existing CalculiX linear static material/face-force scope. Arbitrary direct Sphere/Pipe primitive Gmsh paths remain unsupported; exact CAD 2.1 BREP sphere/pipe bodies are supported. Distance fields use finite sampling; extremely small features or disabled curvature can still make Gmsh reject a boundary. File/memory caps bound individual jobs, not the entire Godot process/history or aggregate retained artifacts. No new guarantee of arbitrary complex CAD validity, arbitrary scaling, topology naming or stress/continuum convergence is made. CAD 2.1's direct BRepCheck_Analyzer/per-face OCCT history/scaling gaps remain deferred. CFD, assemblies, contact and new constitutive solvers were not started.

Final Checkpoint 2.2 decision: **PASS** for the evidenced supported workflow. Failed mandatory checks, if any: [].
