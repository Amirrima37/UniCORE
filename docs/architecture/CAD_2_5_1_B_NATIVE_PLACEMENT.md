# CAD 2.5.1-B native instance placement

Verdict: **PASS for this checkpoint**. CAD 2.5.1-C was not started.
The machine-readable [final receipt](evidence/cad251-native-placement/final-receipt.json)
contains production source hashes, native validations, actual solver job paths,
errors, binary preservation hashes and screenshot hashes.

External evidence:
`D:/PROJECT/TEST_OUTPUTS/CAD/cad251-native-placement/attempt-1794694733241411900/`.
Failed initial diagnostics remain there. Solver jobs reside in the existing
external Godot test profile; their absolute locations are recorded per solve.

Production changes:

- `scripts/engines/instance_placement.py`: rigid matrix construction, native
  placement and invariants, bijective source face transport, checked Gmsh import.
- `scripts/engines/gmsh_study.py`: definition resolution, transformed BREP handoff
  for preview and volume meshing, placement receipts in per-instance meshes.
- `scripts/engines/cad_model.py`: owned assembly preview, combining independently
  placed CAD tessellations and preserving source metadata separately.
- `core/cae/cae_document.gd`: enables CAD position/rotation, rejects instance scale,
  adds RotateInstanceAxis, lossless definition persistence alongside existing JSON.
- `core/cae/assembly_model.gd`: normalizes the compatibility inner-diameter default
  before sealing definitions so reopen cannot introduce a geometry mismatch.
- `ui/cae/cae_workspace.gd`: existing placement fields, asynchronous multi-instance
  preview, stale-preview rejection, source metadata preservation.
- `ui/cae/cad_viewport.gd`: converts global CAD preview/mesh vertices and normals
  to instance-local display coordinates, avoiding double placement.

The composer, CalculiX exporter, native worker and pinned binaries are unchanged.

## Geometry contract

Document schema remains 1 with assembly_schema 1. part_definitions stores immutable
source geometry; parts stores independent instances, UUID references, radians,
translations in metres, material, visibility and revisions. Definition geometry
is resolved and checked against the compatibility snapshot before meshing.
Lossless assembly definitions use `unicore-assembly-definitions-v1`; old files
without that optional payload remain supported.

Placement uses Godot YXZ Euler order, R = Ry * Rx * Rz, followed by translation.
RotateInstanceAxis composes a normalized arbitrary-axis rotation in global axes
and stores the equivalent Euler orientation. Forces remain global vectors and
are never implicitly rotated with the body. Scaling is explicitly unsupported.
The no-instance-UUID branch retains the legacy world-space CAD interpretation.

Existing isolated worker request: schema 1, units m, action transform, a row-major
3x4 matrix, job-local input BREP, operation UUID, feature/instance UUID and input
hash. The worker returns hashed output BREP, before/after measurements and direct
BREP validation. Rigid transforms select BRepBuilderAPI_Transform. STEP is first
converted by the existing step operation. No native rebuild was needed.

Source bytes are never replaced. Every instance obtains validated temporary BREP
bytes before Gmsh imports geometry and generates volume elements. No post-mesh
coordinate transform is used. Worker containment, pin verification, timeouts,
resource bounds and error propagation are retained.

Checks require positive VALID volume, rigid volume/area invariance, transformed
centroid and unique face transport by area, centroid and rotated surface inertia.
Each source face must correspond to exactly one transformed native face and one
Gmsh face, including transformed native/Gmsh bounds and complete boundary coverage.
Indistinguishable descriptors reject the operation; native face slots are not
used as a correspondence fallback. Face names stay instance-scoped. Existing
pending-boundary and mesh freshness gates continue to reject unsafe solves.

## Exercised results

The real worker passed identity, individual X/Y/Z 90-degree rotations, combined
translation/rotation and general orientation. Arbitrary-axis document orientation
is additionally checked against independent Rodrigues rotation and exercised
through native placement. The source SHA remains unchanged.

Rotated single-instance Gmsh checks generated 94 nodes/218 TET4 cells and
495 nodes/218 TET10 cells in the expected global bounds around X=2.
Twelve genuine multi-body CalculiX 2.23 jobs passed: translated reusable CAD bars,
a 90-degree rotated instance and imported bar.step instances; both orders;
before and after save/reopen with regenerated meshes. Twenty-four per-instance
response checks passed. Maximum axial relative displacement error was
2.08334e-8; maximum relative reaction imbalance was 1.22071e-7. Required existing
thresholds remain 1e-4 and 1e-5 respectively.

Independent actual-deck auditing verifies unique node/element identifiers,
disjoint instance nodes, no cross-instance elements, one material section per
element, C3D4/C3D10 connectivity widths, global force and moment resultants and
absence of coupling keywords. Force tolerance is 1e-6 N; moment tolerance is
max(1e-6 Nm, 1e-8 times maximum expected moment component), allowing existing
decimal exporter precision. No exporter precision or numerical threshold changed.

Nine negative cases passed: missing BREP, nonfinite transform, unsupported scale,
worker failure propagation, invalid transformed output, missing face ancestry,
double-transform invariant violation, real native timeout and Gmsh import failure.
Fault injection is used for worker failure, invalid output and Gmsh import;
the timeout launches and terminates an actual contained worker. Workbench checks
also reject stale geometry and pending boundaries. Moving an instance invalidates
its mesh/results and produces a new two-instance native preview.

Actual Workbench solved the rotated TET10 assembly and captured displacement
results at both resolutions:

- `workbench-1280.png` (1280 x 720).
- `workbench-1920.png` (1920 x 1080).

The screenshots were inspected; they show separate vertical and horizontal bars
with results in the corresponding global positions. Existing selection and
position/rotation commands were exercised. Final schema/axis smoke and the
CAD 2.5.1-A focused document test also passed. All seven original pinned binary
hashes match the CAD24 completion receipt.

## Limits

The existing conservative overlap gate remains. Geometrically indistinguishable
face descriptors require reassignment rather than guessed ancestry. Compatibility
geometry snapshots remain duplicated. This checkpoint does not add interfaces,
contact or scale support, and does not claim a full historical regression run.
