# CAD & Meshing 2.1 — PARTIAL

Genuine parametric OCCT Boolean modeling is implemented in the existing UniCORE Workbench. This is a working implementation with real meshing, CalculiX and GUI evidence, not a second CAD application. Production acceptance remains PARTIAL because full independent B-Rep validity analysis, direct per-face OCCT history and general imported/Boolean B-Rep scaling are not implemented through the available public kernel API.

## Baseline and dependencies

The dirty working tree was recorded before editing in [working-tree-before.txt](evidence/cad21/working-tree-before.txt). Existing user changes were retained. Prior STEP final acceptance, CAD checkpoint and Godot migration reports were read. No native kernel, extension ABI, pinned executable, or mesh fingerprint implementation was replaced. Binary hashes were compared to the STEP checkpoint and all present pinned binaries are unchanged; see [binary-hashes.json](evidence/cad21/binary-hashes.json). Godot is 4.7.2 stable official ed1daf0bf, CalculiX 2.23, Gmsh 4.15.2 with OCCT STEP writer 7.8.1. Source fingerprints are in source-hashes.json. No dependency download was needed.

## Implementation and exact files

- `scripts/engines/cad_model.py`: validates and evaluates a directed feature graph using the existing OCCT kernel in the pinned Gmsh DLL. Calls `gmsh.model.occ.fuse`, `cut`, `intersect`, primitive constructors, rotation/translation, `getMass`, `getMatrixOfInertia`, and native BREP export. The worker verifies the DLL SHA-256 and Gmsh version. No triangle subtraction or hidden-body geometry stands in for a Boolean.
- `scripts/engines/run_owned_geometry.py`: owns the OCCT child, monitors its owner, enforces timeout/output limits, and installs a Windows Job Object with kill-on-close and a 768 MiB per-process memory limit. It records real exit state, peak commit and timing.
- `scripts/engines/gmsh_study.py`: extends the existing STEP bridge to explicitly unit-tagged BREP caches, uses conservative stable face IDs for evaluated graphs, and rejects a graph/cache mismatch before preview or FEM meshing. Legacy STEP processing remains available.
- `core/cae/cad_model.gd`: graph conversion and validation; persistent feature IDs; cycle/dependency/source-hash checks; existing primitive rotations converted from radians into graph degrees.
- `core/cae/cad_geometry_job.gd`: runs the owned helper on a worker thread and checks bounded responses and terminal receipts.
- `core/cae/cae_document.gd`: transactional CommitCADFeature, replacement of active operands with one editable result, boundary review/invalidation, Undo/Redo through existing history, validated graph persistence, and multiple STEP input bodies for Boolean selection. Existing single-solid FEM scope remains.
- `core/cae/calculix_workbench.gd`: refuses a changed graph whose evaluated BREP has not been recomputed. The existing CalculiX backend remains the actual solver.
- `ui/cae/cad_boolean_panel.gd`: base/tool/operation selectors, quality control, asynchronous preview, cancel/confirm, editable primitive and Boolean parameters/dependencies/transforms, and stale-preview rejection.
- `ui/cae/cae_workspace.gd`: Geometry menu/ribbon, operation explorer, genuine CAD properties/source metadata, worker lifecycle/publication guards, and bounded BREP previews after open/Undo/Redo. Corrects idle polling to include CAD jobs.
- `ui/cae/cad_viewport.gd`: computes normals for actual OCCT display tessellation so the CAD surfaces are shaded. No shell or unrelated inspector redesign.
- Tests and reproduction: `tests/cad21_geometry.py`, `cad21_integration.gd`, `cad21_gui.gd`, `cad21_lifecycle.py`, `run_cad21.py`, `summarize_cad21.py`.

The kernel adapter follows the official [Gmsh OCC API](https://gmsh.info/doc/texinfo/#Namespace-gmsh_002fmodel_002focc). Those APIs call real OCCT modeling algorithms and serialize real B-Rep geometry. They do not expose BRepCheck_Analyzer or OCCT Modified/Generated/IsDeleted face history directly. This implementation does not claim those direct APIs were invoked.

## CAD schema and persistence

The enclosing CAE schema remains version 1. A CAD part adds a separately versioned model:

```json
{"schema":1,"units":"m","root":"cut_1","nodes":[
  {"id":"box_1","type":"Box","dimensions":[0.1,0.2,0.1]},
  {"id":"cylinder_1","type":"Cylinder","dimensions":[0.04,0.3,0.04]},
  {"id":"cut_1","type":"Cut","base":"box_1","tool":"cylinder_1"}
]}
```

Primitive nodes carry dimensions, position, rotation (XYZ degrees), scale and optional pipe inner diameter. STEP nodes retain source name, exact embedded source bytes, SHA-256, parsed source units and conversion to metres. Boolean nodes carry persistent IDs and explicit base/tool dependencies. The result records kernel metadata, tolerance, geometry revision, face descriptors and evaluated BREP bytes/hash. `cad_model` is authoritative; `cad_evaluated_model` snapshots the graph that generated the cached BREP. A mismatch requires recomputation, rather than meshing stale geometry.

Sorted JSON keys and ordered feature arrays define deterministic graph revision serialization. BREP bytes themselves are not promised byte-identical across kernel versions. New project saves encode CAD graph numeric data losslessly with `unicore-cad-graph-v1`, including the result identity's model-parts snapshot, using object-disabled Variant decoding on open. Existing lossless mesh encoding and canonical SHA-256 verification remain unchanged. Schema migration is explicit: legacy parts without a CAD model remain legacy; plain version-1 CAD graphs are accepted only with a matching evaluated snapshot; lossless graph encoding version 1 is decoded; unknown versions, corrupt payloads, cycles, missing dependencies, unsupported types and bad STEP hashes are rejected before document replacement. Old unsupported experimental graph caches require recomputation; they are not silently accepted as fresh results.

Inputs remain recoverable in the graph after active base/tool bodies are replaced by the result. Undo restores those bodies, and Redo restores the result. Parameter changes recompute the graph and produce a new geometry revision, invalidate the old FEM mesh and reject old results. Opening an unchanged saved result preserves freshness.

## Topology and boundary-condition identity

Face indices/tags are never used as persistent boundary IDs for graph-generated CAD. IDs are scoped to feature provenance and geometry descriptors: surface type, area, centroid, bounds, inertia, and trimmed boundary edge type/length/bounds plus orientation-normalized sampled curve positions. Matching requires a unique one-to-one complete descriptor match within max(1e-11 absolute, 1e-9 relative); numeric ordering of edges is normalized separately from matching tolerance. Missing, split, merged or ambiguous matches invalidate old associations. The bridge rematches faces after BREP reimport and refuses an identity mismatch before meshing. No nearest-face or face-index fallback exists.

Support and total-force associations survive only when the selected ID is preserved. Other condition classes are conservatively cleared for review during CAD commits. A slot-cut regression splits an old selected top face into two, invalidates its old ID and preserves the unchanged bottom ID. The GUI radius-edit regression invalidates both modified end-face assignments. The volume ancestry returned by Gmsh Boolean calls is recorded, but is explicitly not represented as per-face OCCT history. Descriptor matching is conservative and tested on this bounded feature set; it is not a general topological-naming solution for arbitrary NURBS or degenerate topology. See [topology-receipt.json](evidence/cad21/topology-receipt.json).

## Geometric and Gmsh verification

Units are explicit: graph primitives use metres; STEP units are read from declarations, never inferred from dimensions. Existing metre/millimetre/centimetre source cases pass. Unsupported or ambiguous unit declarations fail. STEP shells/assemblies with more than one solid are rejected; two individual STEP solids can participate in a Boolean. STEP + STEP union, STEP + primitive cut, through-hole, blind cavity, pipe, and supported primitive scale/rotation cases were evaluated.

For the box examples A and B each have volume 0.002 m³ and their analytic overlap is 0.001 m³. Union must be 0.003 m³, satisfying V(A union B)=V(A)+V(B)-V(A intersect B). The hole case removes pi*(0.02)^2*0.2 from 0.002 m³. The pipe uses pi*(0.05²-0.03²)*0.2. The STEP bar hole removes pi*(0.02)^2*1 from 0.01 m³. The comparison tolerance is 1e-8 relative for these regular well-conditioned cases, with OCCT geometry/Boolean tolerances set to 1e-8 m; this is not a guaranteed relative error bound for arbitrarily small features.

| Case | Analytic volume (m³) | OCCT volume (m³) | Relative error | Faces | Nodes | TET4 | Min Jacobian (m³) | Build + mesh wall (s) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| fuse | 0.003 | 0.003 | 0 | 6 | 131 | 338 | 1.76187e-05 | 0.218 |
| hole | 0.00174867258771 | 0.00174867258771 | 2.22e-16 | 7 | 154 | 426 | 2.92195e-06 | 0.163 |
| pipe | 0.00100530964915 | 0.00100530964915 | 4.44e-16 | 4 | 117 | 310 | 4.51924e-06 | 0.141 |
| intersect | 0.001 | 0.001 | 2.22e-16 | 6 | 76 | 172 | 1.41234e-05 | 0.135 |
| step-cut | 0.00874336293856 | 0.00874336293856 | 0 | 7 | 358 | 1107 | 2.85779e-06 | 0.264 |
| sphere | 0.000523598775598 | 0.000523598775598 | 0 | 1 | 28 | 50 | 2.15154e-05 | 0.123 |

All listed cases passed actual production-bridge Gmsh meshing, including the five requested Boolean-generated solids. Positive determinants and exact exterior triangle coverage were checked. Physical face IDs match the complete evaluated face set; no extra or missing physical face groups are accepted. OCCT single-solid count, positive mass and boundary edge incidence are checked. These checks do not replace a full independent BRepCheck_Analyzer/self-intersection analysis, which remains a production-acceptance gap.

Additional geometry/units/assembly receipts: `additional-geometry.json`, `units-receipt.json`, `assembly-rejection.json`. Nonuniform boxes and axial/radial cylinder scales are baked into analytic primitive constructors, avoiding general curved-surface transform approximation. Sphere scaling is uniform only; cylinder/pipe X and Z radial scales must agree. General scaling of imported or Boolean BREP results is explicitly rejected; edit constituent primitive dimensions instead.

## Genuine CalculiX results

Both cases use E=210 GPa, nu=0, fixed lower Y planar end, and a total +Y force of 1000 N distributed by triangle area on the upper planar end. Material assignment, CAD face membership, real solver execution, actual DAT displacement/stress output, unchanged save/reopen, parametric recomputation, stale rejection and Undo/Redo are checked. The GUI additionally solves the through-hole box with its assigned material. No fallback to Extreme occurs.

| Case | Nodes | TET4 | Maximum displacement (m) | Maximum von Mises (Pa) | Reaction imbalance / 1000 N |
|---|---:|---:|---:|---:|---:|
| fuse | 131 | 338 | 6.349206672e-08 | 66666.67048 | 6.10352e-08 |
| step-cut | 358 | 1107 | 5.226218605e-07 | 116746.5313 | 1.2207e-07 |

For the STEP-cut bar the exact-area axial reference is 5.446308011e-07 m; the coarse-mesh maximum displacement differs by 4.041%. Its faceted mesh volume is 0.009173213157 m³ versus exact CAD 0.008743362939 m³ (4.916% difference). This intentionally coarse hole mesh is a compatibility/equilibrium check, not a converged accuracy claim. The fused-box axial reference is 1000*0.2/(210e9*0.015)=6.349206349e-8 m. Reaction balance uses actual constrained-node RF output. Archived decks/DAT/logs/receipts are in solver-jobs/ and solver-artifacts.json.

## Graphical acceptance and failures preserved

The actual pinned Godot Workbench exercised Geometry → Boolean CAD, base/tool Cut selection, asynchronous exact preview, confirm, operation explorer, face selection, Gmsh meshing, CalculiX solve, displacement/von Mises contours, save/reopen, primitive radius edit, boundary invalidation and Undo/Redo. Captures are genuine Godot viewport images, at both 1280×720 and 1920×1080, with an inventory and hashes in screenshots.json.

Examples: [Boolean controls](evidence/cad21/screenshots/boolean-controls-1920.png), [solid and operation tree](evidence/cad21/screenshots/boolean-solid-operation-tree-1280.png), [selected CAD face](evidence/cad21/screenshots/selected-cad-face-1280.png), [FEM mesh](evidence/cad21/screenshots/boolean-tet4-mesh-1920.png), [displacement](evidence/cad21/screenshots/calculix-displacement-1280.png), [von Mises](evidence/cad21/screenshots/calculix-von-mises-1920.png), [parametric editor](evidence/cad21/screenshots/edit-cylinder-feature-1920.png).

Failed attempts are retained in timestamped directories and attempt-history.json. The first hole-volume test exposed an unnecessary identity dilation through OCCT's general transform path, changing mass-property accuracy; removing that no-op and baking supported primitive scales fixed it. A stricter edge descriptor initially failed BREP reimport because tiny numeric noise changed edge ordering; canonical geometric ordering fixed the mismatch without weakening face matching or mesh provenance. An integration failure used geometry/mesh artifacts from that interrupted campaign and passed once regenerated consistently. The first GUI attempt timed out waiting for publication because the old idle predicate disabled processing despite an active CAD job; the predicate now includes the CAD worker. No new native crash was observed. This does not claim universal resolution of historical Godot crashes.

## Resource/lifecycle evidence

CAD jobs default to 45 seconds (allowed 0..120). The helper records the owned PID, uses a Windows kill-on-close Job Object and 768 MiB per-worker commit limit, monitors the Godot owner, and terminates/waits only its owned child. Job-local temporary directories keep interrupted OCCT files controlled. Requests/results are capped at 96 MiB, individual source/BREP assets at 64 MiB, feature count at 64, display vertices at 300000 and preview quality at 8..60. Logs are monitored at 4 MiB each and job disk usage at 256 MiB; checks poll at 20 ms, so these are monitored kill thresholds rather than OS disk quotas. Final output sizes are checked again before accepting completion. Completed/failed job directories are retained for diagnosis; automatic aggregate retention cleanup is not implemented.

| Lifecycle case | Harness child exit | Terminal state | Job Object | Peak worker commit (MiB) | Wall (s) | Outcome |
|---|---:|---|---|---:|---:|---|
| cancel | 1 | cancelled | True | 0.48 | 0.462 | PASS |
| timeout | 1 | timeout | True | 0.43 | 0.300 | PASS |
| invalid | 0 | completed | True | 606.26 | 0.952 | PASS |
| recovery | 0 | completed | True | 619.09 | 1.517 | PASS |
| owner-exit | 0 | owner_exited | True | 3.49 | 0.464 | PASS |
| oversize | 0 | completed | True | 606.44 | 0.939 | PASS |

The cancellation test observes a live child before cancel. All recorded child PIDs are gone at completion, including abrupt owner exit. Timeout uses a zero-second deadline for deterministic termination. Invalid graph and oversized-request paths reject without publishing geometry, then a valid operation recovers. Actual workspace testing also changes the document mid-computation and confirms stale publication rejection. Render resources are created only on the Godot main thread. These are bounded resource tests, not proof of leak-free operation under an unlimited history or all adversarial CAD inputs.

## Actual exit codes and preservation

| Campaign | Actual exits | Outcome |
|---|---|---|
| geometry | 0 | PASS |
| integration | 0 | PASS |
| gui | 0 | PASS |
| lifecycle | 0 | PASS |
| scan | 0 | PASS |
| preservation | 0, 0, 0, 0, 0 | PASS |
| Default regressions | 28/28 exit 0 | PASS |

Full exits, commands and raw streams are in mode-latest.json and timestamped attempt folders; default manifest evidence is in regressions-release-check/. Preservation runs include original STEP bar/cylinder CalculiX save/reopen, canonical fingerprint regressions, 580 modal checks and three Newmark checks. No native binary or kernel was rebuilt. Editor scans pass with the existing root-certificate warning retained. Historical UI mojibake remains outside this checkpoint's scope.

## Reproduction and remaining gaps

Set `UNICORE_PYTHON` to the installed `C:/Users/Victus/AppData/Local/Python/pythoncore-3.14-64/python.exe`; set APPDATA/LOCALAPPDATA to the absolute `.tools/godot472-migration/roaming` and `local` directories. Run from the repository root:

```text
PYTHON tests/run_cad21.py geometry
PYTHON tests/run_cad21.py integration
PYTHON tests/run_cad21.py lifecycle
PYTHON tests/run_cad21.py gui
PYTHON tests/run_cad21.py scan
PYTHON tests/run_cad21.py preservation
PYTHON native/run_regressions.py --godot GODOT --output docs/architecture/evidence/cad21/regressions-final
PYTHON tests/summarize_cad21.py
```

GODOT is the unchanged `D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe`.

**PARTIAL.** Working Booleans, editable persistent graph, conservative topology invalidation, five required meshes, two Boolean CalculiX studies, graphical acceptance and 28 regressions are evidenced. Missing production guarantees are full independent BRepCheck_Analyzer/self-intersection validation and direct per-face OCCT history. General imported/Boolean scaling, nonuniform sphere/elliptical cylinder scaling, and general STEP unit/assembly support beyond the documented scope are rejected rather than approximated. Descriptor matching is limited to tested regular geometry; arbitrary complex CAD needs further topology qualification. Log/disk limits are monitored thresholds, aggregate job/history retention is not bounded, and long-duration Godot memory behavior has not been qualified. These gaps prevent a production PASS despite the passing focused cases. No Checkpoint 2.2, assembly constraints, new physics solver or CFD/OpenFOAM work began.
