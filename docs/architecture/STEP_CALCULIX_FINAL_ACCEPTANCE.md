# STEP → CalculiX final acceptance — PARTIAL

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

| h (m) | Nodes | TET4 | Min mean ratio | Min Jacobian (m³) | Tip mean (m) | Max displacement (m) | Reference (m) | Error (%) | Reaction imbalance / F | Max von Mises (Pa) | Solve wall (s) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.07 | 140 | 307 | 0.62013 | 5.8594e-05 | 4.761905e-07 | 4.76190507e-07 | 4.76190476e-07 | 5e-06 | 2e-08 | 100000 | 1.234 |
| 0.05 | 190 | 433 | 0.43306 | 2.8222e-05 | 4.761905e-07 | 4.76190507e-07 | 4.76190476e-07 | 5e-06 | 2e-08 | 100000 | 1.475 |
| 0.033333 | 587 | 1779 | 0.38874 | 1.5188e-05 | 4.761905e-07 | 4.76190507e-07 | 4.76190476e-07 | 5e-06 | 1e-08 | 100000 | 1.562 |

Cantilever bar: Euler–Bernoulli integration of EI times the fourth derivative of u = 0 with fixed root and end force gives u=FL³/(3EI)=1.90476190476e-4 m, I=(0.1)^4/12=8.333333333e-6 m⁴. This assumes a slender, linear, prismatic beam, small displacement, plane sections, and negligible shear deformation. L/width=10. A Timoshenko shear estimate F*L/(k*G*A), k=5/6 and G=E/[2(1+nu)], is 1.485714286e-6 m (0.78% of Euler–Bernoulli), much smaller than the observed discretization errors. Reported tip displacement is the arithmetic mean of loaded face nodes, not one selected corner. Solid clamp effects, nonuniform end response, and clamp stress singularities limit comparison of peak von Mises values to a beam stress formula.

| h (m) | Nodes | TET4 | Min mean ratio | Min Jacobian (m³) | Tip mean (m) | Max displacement (m) | Reference (m) | Error (%) | Reaction imbalance / F | Max von Mises (Pa) | Solve wall (s) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.07 | 140 | 307 | 0.62013 | 5.8594e-05 | 8.55847542e-05 | 8.58751519e-05 | 0.00019047619 | 55.068 | 1.7349e-06 | 3504141 | 1.369 |
| 0.05 | 190 | 433 | 0.43306 | 2.8222e-05 | 0.000107963933 | 0.000108270993 | 0.00019047619 | 43.3189 | 9.4816e-07 | 4688116.4 | 2.299 |
| 0.033333 | 587 | 1779 | 0.38874 | 1.5188e-05 | 0.00014872965 | 0.000149160929 | 0.00019047619 | 21.9169 | 1.2659e-06 | 5475497.4 | 2.432 |

The bending error decreases monotonically, 55.1% → 43.3% → 21.9%, but remains unacceptable for a high-accuracy bending prediction. First-order TET4 elements are too stiff on these meshes. No industrial-accuracy or asymptotic-convergence claim is made. Peak stress is a mesh-dependent output, not a converged stress certification.

Cylinder: source radius 0.1 m, length 0.2 m; exact CAD volume pi*r²*L=0.00628318530718 m³, end area pi*r²=0.0314159265359 m²; u=3.03152272556e-8 m at nu=0. Mesh faceting reduces area and volume, causing a positive axial compliance error which decreases with refinement. The independent reference uses exact circular area, not the discretized area.

| h (m) | Nodes | TET4 | Min mean ratio | Min Jacobian (m³) | Tip mean (m) | Max displacement (m) | Reference (m) | Error (%) | Reaction imbalance / F | Max von Mises (Pa) | Solve wall (s) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.06 | 85 | 231 | 0.4112 | 5.4134e-05 | 3.14317084e-08 | 3.17020721e-08 | 3.03152273e-08 | 3.68291 | 1e-08 | 33629.371 | 1.357 |
| 0.04 | 197 | 617 | 0.42174 | 1.8715e-05 | 3.0886888e-08 | 3.09858414e-08 | 3.03152273e-08 | 1.88572 | 2e-08 | 32875.886 | 2.303 |
| 0.025 | 581 | 2174 | 0.40405 | 4.1429e-06 | 3.05249398e-08 | 3.05694208e-08 | 3.03152273e-08 | 0.691773 | 6e-09 | 32168.605 | 2.549 |

CAD bounds, source units, CAD and faceted volumes, source hashes, actual physical face names, end areas, and selected support/load face IDs are recorded per row in `numerical.json`. All minimum Jacobians are positive. The production bridge checks triangle coverage against the TET4 exterior and verifies face-node membership and total applied force. Dimensionless minimum quality here is tetrahedron mean ratio, 12*(3V)^(2/3)/sum(edge²); Jacobian alone is dimensional and cannot substitute for a shape metric.

Reactions are summed only on constrained nodes; the reported imbalance is ||sum(R)+F||/||F||. All nine cases are below 1.8e-6. This uses CalculiX printed RF values, not an inferred equilibrium from load distribution. Stress and displacement were read from actual DAT output. Archived decks, DAT output, canonical models, terminal receipts and SHA-256 inventories are under `numerical-jobs/` and `numerical-artifacts.json`.

## Actual exits and regressions

Default manifest: 28/28 passed; all recorded exits: [0]. See `regressions/receipt.json` and individual logs. Native extension numerical tests, thermal, structural, Extreme, and other existing default functionality ran against the pinned 4.7.2 runtime.

| Engineering check | Actual exit | Outcome |
|---|---:|---|
| adapter | 0 | PASS |
| patch | 0 | PASS |
| canonical | 0 | PASS |
| failure-import | 0 | PASS |
| step-preview | 0 | PASS |
| gmsh-repeatability | 0 | PASS |
| extreme-comparison | 1 | FAIL |
| lifecycle | 0 | PASS |
| editor-scan | 0 | PASS |

The Extreme comparison failed with PermissionError while overwriting an existing Box.stdout.txt (both historical and reused campaign outputs). A narrowly scoped --output option and a unique output directory per attempt preserve prior evidence. A fresh-output rerun passed both comparisons; see `comparison-receipt.json` for the exact directory and exit 0. Displacement relative L2 differences were 8.40e-8 and 2.18e-7, stress differences below 2.10e-7. The latest failed engineering receipt and error stream are retained. The editor scan exited 0 with no SCRIPT ERROR; root certificate store warnings remain in logs and are not a native crash.

## Graphical Workbench evidence

| Fixture | Actual exit | Outcome |
|---|---:|---|
| gui-bar | 0 | PASS |
| gui-cylinder | 0 | PASS |

The graphical runner captures genuine viewport screenshots at 1280×720 and 1920×1080 in `screenshots/`: imported geometry, selected CAD face, TET4 mesh, support/force, backend, execution, displacement, von Mises, reopened, and recalculated. It validates new solve freshness, exact mesh fingerprint preservation, a blank-document close followed by reopen, three additional reopen cycles, and material E doubling with half displacement on recalculation. It also rejects edits to coordinates, connectivity, geometry placement, E, force, support, analysis type, solver configuration, and embedded source bytes. No fingerprint code was changed. Existing legacy hash validation remains strict; no old invalid result is reauthorized.

The first graphical bar passed (exit 0); the first cylinder capture timed out at 240 seconds without completing any screenshot. Its receipt and streams are retained as gui-first-receipt.json and gui-cylinder-first.*.txt. The capture helper now explicitly requests an actual Godot RenderingServer.force_draw rather than awaiting frame_post_draw indefinitely. Both fixtures then passed (exit 0) in about 11 and 14 seconds. This is evidence consistent with a capture synchronization issue, not proof of a particular Windows occlusion state. No new native crash was observed. Historical crashes remain separately documented.

Representative genuine captures: [bar displacement, 1280](evidence/step-final/screenshots/bar-displacement-1280.png), [bar stress, 1920](evidence/step-final/screenshots/bar-von-mises-1920.png), [cylinder displacement, 1280](evidence/step-final/screenshots/cylinder-displacement-1280.png), [cylinder stress, 1920](evidence/step-final/screenshots/cylinder-von-mises-1920.png). Visual inspection confirms nonempty rendered solids, contour colors, stress/displacement labels, units, and numerical legends. Some pre-existing UI text has mojibake and the bar can approach the top viewport boundary at the smaller size; no UI rewrite was attempted.

## Lifecycle and failure checks

| Engine | Scenario | Launcher exit | Terminal state | Outcome |
|---|---|---:|---|---|
| gmsh | cancel | 1 | cancelled | PASS |
| gmsh | timeout | 1 | timeout | PASS |
| gmsh | recovery | 0 | completed | PASS |
| gmsh | corrupt | 1 | failed | PASS |
| calculix | cancel | 1 | cancelled | PASS |
| calculix | timeout | 1 | timeout | PASS |
| calculix | recovery | 0 | completed | PASS |
| calculix | missing | 1 | failed | PASS |

Both active-cancel tests verify the launched PID is alive before requesting cancellation and gone afterward. Zero-duration timeout tests exercise real child termination deterministically; they do not measure a long-running 120-second timeout. Gmsh now emits its owned PID receipt; CalculiX launcher accepts an optional timeout argument while retaining the default 120 seconds. These are the only production launcher changes.

`workbench-lifecycle.json` records actual threaded Workbench tests: save during meshing/solving, rapid repeated actions rejected by operation guards, cancellation joined, reopen after cancellation, cancelled result not published, and graceful shutdown during an owned solve. Frame counts advance during operations, establishing responsiveness for these bounded cases. Missing physical groups, invalid connectivity, malformed/truncated/nonfinite output, corrupt source, and >32 MiB DAT are rejected. Test-generated oversized output is removed after rejection to avoid leaving a large dummy file. Actual lifecycle error streams and terminal receipts are retained.

## Limitations and final verdict

PARTIAL until every required criterion is satisfied. Numerical bending remains coarse (21.9% finest-mesh error). GUI coverage is automated Workbench invocation rather than manual complete shell/file-dialog navigation. The initial cylinder GUI capture timeout is preserved above; the explicit-render retry passed. No universal historical-crash fix is claimed. No sustained-memory-growth campaign or hard output/log disk quota has been demonstrated. The 32 MiB DAT import limit protects parsing, not solver output generation. Abrupt OS termination of the parent is not covered by graceful shutdown testing; no Windows Job Object containment is implemented. The Workbench now detects a missing executable before launching, names the expected pack and corrective action, and includes owned job log paths for unsuccessful terminal receipts. Per-path UX for every corrupt or oversized upstream output remains limited. These prevent an unrestricted safety/stability acceptance claim.

Changes are limited to acceptance scripts/evidence, the comparison runner output option, owned mesh PID evidence, optional owned solver timeout, and actionable missing-executable/failure-log messages in calculix_workbench.gd. Existing user edits, CAD architecture, native kernels, canonical fingerprints, and physics solvers were preserved. Stop at this checkpoint; do not begin CAD & Meshing 2.0.

## Modal/transient compatibility checks

- modal: exit 0, PASS; raw streams retained.
- dynamics: exit 0, PASS; raw streams retained.
- numeric-job: exit 0, PASS; raw streams retained.

The installed modal executable reported 580 checks, zero failures; the Newmark executable reported three energy/equilibrium/output-count checks, zero failures. Existing binaries were executed, not rebuilt; this is a compatibility smoke check, not a new exhaustive modal/transient validation campaign.

Screenshot inventory: 44 actual PNGs, dimensions and SHA-256 in screenshots.json.
