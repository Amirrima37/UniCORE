# CAD 2.5.1-C — native assembly interference

**PASS.** Production assembly meshing now classifies actual transformed solids
through isolated OCCT before generating independent meshes. AABB overlap alone
no longer rejects an assembly. No interfaces, ties, contact or welding were added.

The [final receipt](evidence/cad251-interference/final-receipt.json) contains
measured native responses, solver jobs, hashes, performance and screenshots.
Large evidence is retained under
`D:/PROJECT/TEST_OUTPUTS/CAD/cad251-interference/attempt-1794697076729609200/`.

## Production implementation

The replaced gate was in `scripts/engines/gmsh_study.py::mesh_study`, after
independent mesh composition. It formerly rejected any positive overlap of the
meshes' bounding boxes. Its replacement runs before meshing:

1. Resolve immutable definitions through the existing placement path.
2. Obtain each actual world-space BREP through the existing native placement
   worker, including STEP conversion. Primitive boxes/cylinders/spheres use
   the same native primitive and rigid-transform operations.
3. Run native `classify_pair` for each pair, with a hash/revision keyed cache.
4. Accept only SEPARATED and TOUCHING; block every other outcome with names,
   stable instance UUIDs and diagnostics.
5. Use the existing Gmsh integration, mesh composer and CalculiX exporter.

Modified production files:

- `native/occt/worker.cpp`: adds `classifyPair` and `classify_pair` dispatch.
- `scripts/engines/assembly_interference.py`: instance BREP resolution, pair
  classification, bounded cache and assembly preflight.
- `scripts/engines/native_occt.py`: explicit cancellation-file and owner-death
  checks inside the existing bounded worker loop.
- `scripts/engines/gmsh_study.py`: replaces the final AABB gate with native
  preflight and retains classification evidence in the assembly mesh.
- `core/cae/calculix_workbench.gd`: rejects missing, incomplete, blocked or stale
  classification before assembly deck preparation.
- `core/cae/assembly_model.gd`: canonical numeric geometry comparison fixes the
  integer/float save/reopen mismatch exposed by the default structural test.
- `ui/cae/cae_workspace.gd`: reports accepted pair classifications and instance
  identities through existing Workbench diagnostics. Rejection errors already
  flow through the owned mesh error path.

The composer and exporter are unchanged. Classification uses BREPs, never
tessellation intersection. Classified and meshed geometry use the same source
hashes and rigid placement; neither source definitions nor meshes are moved
after classification.

## Native contract and tolerances

`classify_pair` uses the existing schema 1/metres/job-local BREP request with
two verified input hashes, operation identity and feature identity. It returns
an explicit classification and diagnostics, both input validations, native
bounds, common volume and distance when computed. It does not serialize the
Boolean common through the old single-solid-only output path.

Both inputs must pass the existing positive-volume closed-single-solid checks,
including BRepCheck_Analyzer. Native BRepBndLib bounds are broad phase only.
Safely disjoint bounds establish separation without a Boolean call. Otherwise,
BRepAlgoAPI_Common runs serially; errors, warnings, null output or invalid common
topology produce INCONCLUSIVE. Valid common solid volumes are measured with
BRepGProp. A significant positive volume produces OVERLAPPING. A positive volume
below resolution produces INCONCLUSIVE. For zero common volume,
BRepExtrema_DistShapeShape distinguishes touching from separation.

Let L be the largest extent of either input and tA/tB their maximum native
tolerances:

- Length tolerance: `max(1e-9 m, L*1e-10, 4*tA, 4*tB)`.
- Significant volume threshold: `max(1e-18 m³, L³*1e-12)`.
- With valid zero-volume common, distance at or below the length tolerance is
  TOUCHING. Near-coincident features below OCCT resolution can therefore be
  TOUCHING rather than mathematically separated.

Malformed serialization or worker failure is INCONCLUSIVE and blocks analysis.
A parsed solid that fails validity is INVALID. Neither failure is converted to
zero intersection or separation. These are finite-precision engineering
classifications, not a claim of exactness at arbitrary scales.

## Measured geometry matrix

| Case | Outcome | Common volume (m³) | Native distance (m) |
| --- | --- | ---: | ---: |
| Separated boxes | SEPARATED | broad phase | lower bound only |
| Face-touching boxes | TOUCHING | 0 | 0 |
| Edge-touching boxes | TOUCHING | 0 | 0 |
| Overlapping boxes | OVERLAPPING | 0.002 | not needed |
| Rotated disjoint bars, overlapping AABBs | SEPARATED | 0 | 0.020 |
| Disjoint cylinders, overlapping AABBs | SEPARATED | 0 | 0.01213203436 |
| Tangent cylinders | TOUCHING | 0 | 0 |
| Cylinder through box | OVERLAPPING | 0.004 | not needed |
| Object inside hollow tube | SEPARATED | 0 | 0.07928932188 |
| Independently transformed STEP solids | SEPARATED | broad phase | lower bound only |
| Shared definition, separate placements | SEPARATED | 0 | 0.020 |
| 1 µm box penetration | OVERLAPPING | 4.0e-8 | not needed |
| Near-coincident faces | TOUCHING | 0 | 0 |
| Malformed BREP | INCONCLUSIVE | not computed | not computed |
| Reversed, parsed solid | INVALID | not computed | not computed |
| Injected Boolean failure | INCONCLUSIVE | not computed | not computed |
| Real worker timeout | INCONCLUSIVE | not computed | not computed |
| Real pre-signalled worker cancellation | INCONCLUSIVE | not computed | not computed |

The tube is a genuine native cut BREP. The reversed solid has negative signed
volume and fails native validation. Boolean failure injection verifies safe
propagation; timeout and cancellation launch contained native workers and retain
their process receipts. Production overlap and inconclusive checks reject before
meshing/deck preparation and identify both instances.

## Meshing, solver and persistence acceptance

Twelve genuine multi-body CalculiX 2.23 jobs passed: rotated disjoint bars whose
AABBs overlap, face-touching bars, and transformed imported STEP bars; TET4 and
TET10; before and after save/reopen with regenerated meshes. All 24 per-instance
response checks passed. Maximum relative displacement error was 1.20404e-7;
maximum relative reaction imbalance was 1.22071e-7. Existing thresholds remain
1e-4 and 1e-5. The touching partner is unloaded and remains below 1e-14 m axial
displacement, with no artificial force transfer.

Independent actual-deck audits verify unique node/element IDs, correct C3D4/C3D10
widths, exactly one material section per element, disjoint instance node ownership,
and absence of ties, equations, springs and contact. Touching meshes retain 30
coincident coordinate locations for TET4 and 97 for TET10 with distinct node IDs.
Applied global force/moment resultants are checked per instance. Audit tolerances
are 1e-5 N and `max(1e-6 Nm, 2e-7*maximum expected moment component)`; the latter
accounts for existing float32 Vector3 traction weighting. Solver thresholds and
production loads/export precision were not changed.

The solver compares the full geometry identity fields and geometry/transform
revisions against the classification snapshot. Missing preflight evidence on an
older saved assembly requires remeshing. Transforming an instance makes the
classification stale; cached classifications cannot authorize the edited model.
Reopen preserves UUIDs and transforms, and remeshing recomputes or validates cache
identities before solving. Existing pending-boundary checks remain active.

## Cache, performance and lifecycle

Cache keys include both verified transformed BREP SHA-256 values, geometry and
transformation revisions, algorithm identity and the sealed worker/source hashes.
Classification constants belong to that source identity. Cache envelopes check
input identities and receipt hashes. Only definitive results are cached; failures
are retried. The cache stops adding files at 512 entries without deleting evidence.
Revision changes produce misses. The receipt records actual hits/misses and calls.

Successful matrix pair calls took approximately 0.54–1.47 s including isolated
process launch; peak measured native commit was 23,871,488 bytes. A dedicated cache
miss took 1.401 s and a hit 0.0251 s. Native broad phase avoids Common/Distance for
safely disjoint boxes. Cache reuse avoids repeated native pair calls, while source
and placement validation remains active.

Windows Job Object containment, suspended-child assignment, owner monitoring,
768 MiB native memory cap, bounded logs/output, timeout and atomic receipts remain
in force. Successful native temporaries follow the existing cleanup path; failure
diagnostics are retained. The owned outer meshing job still handles cancellation
of the complete process tree.

## Workbench and preservation

Actual Workbench regenerated meshes and solved valid rotated/touching assemblies,
then rejected positive overlap after a placement edit. Screenshots were captured
at 1280×720 and 1920×1080 and inspected:

- `rotated-disjoint-{1280,1920}.png` and corresponding result views.
- `touching-{1280,1920}.png` and corresponding result views.
- `overlap-rejected-{1280,1920}.png` with names/UUIDs in diagnostics.

The native worker required a rebuild for the new operation. Its previous executable,
fixture builder, manifest and hash-verified original source are archived externally
under `sdk-before-1794696907774`; restoration instructions and per-file hashes are
in the receipt. The new build is sealed and its runtime import audit has no missing
modules. SDK package locks and all 243 sealed runtime DLL hashes remain unchanged.
All seven original pinned binary hashes match CAD 2.5.1-B.

Existing CAD 2.5.1-A document tests, B native placement/TET4/TET10 tests and nine B
failure tests passed. The final sealed default campaign passed **28/28**. Initial
failed diagnostics and an interrupted regression attempt remain preserved; the
numeric identity mismatch they exposed is fixed. Full historical numerical
campaigns were **NOT RUN**.

## Reproduction and limits

Run `tests/cad251_interference_native.py` with the installed Python; it creates a
unique external attempt and records its path in `interference-attempt.txt`.
Set UNICORE_INTERFERENCE_OUT to that path and run the Godot
`tests/cad251_interference_solve.gd` script, followed by the GUI script.
The rejection, deck audit and receipt Python runners use the recorded attempt.
Use the existing external Godot test profile and set UNICORE_PYTHON explicitly.
The sealed worker is built with `native/build_occt.ps1`; runtime imports are
audited with `native/occt/audit_runtime.py`.

Indistinguishable placement face descriptors still block safely. Unsupported
primitive types reject explicitly; hollow geometry is supported as CAD BREP.
Scaling remains outside this checkpoint. There is no mechanical contact, interface
or coupling implementation. CAD 2.5.1-D and CAD 2.5.2 were not started.
