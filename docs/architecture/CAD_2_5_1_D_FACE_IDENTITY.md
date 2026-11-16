# CAD 2.5.1-D — face identity audit (before implementation)

The existing document stores `support` and `load_face` as opaque face strings on
each compatibility `parts` entry. `cad_faces`, areas, centers and (for evaluated
graphs) complete descriptors accompany source geometry. Native graph history
uses verified OCCT ancestry; operation-local slots and Gmsh tags are temporary.
STEP mapping and placement require unique matches; they must not guess.

CAD 2.5.1-B transports faces by area, centroid and rotated inertia, then checks
Gmsh bounds and full face coverage. However the initial name-to-source binding
still uses only area and center, and does not persist an instance-qualified
assignment. There is no explicit assignment record binding instance UUID,
definition UUID, source hash, face identity and revisions. AddInstance/Duplicate
currently copy loads/supports. That is a concrete independence weakness.

Viewport picking ray-tests each displayed instance's triangles and chooses the
nearest actual hit. CAD triangle ownership is reconstructed from region iteration
counts instead of an explicit triangle-to-face table. The region order currently
matches construction, but this is an implicit coupling to harden.

CommitCADFeature archives modified/deleted/ambiguous conditions and marks pending
review. ApplySupport/ApplyLoad and RemoveCondition clear pending review; undo/redo
retain document snapshots. Solver preparation checks source hash, current mesh,
pending conditions and boundary triangle/node membership, but cannot detect a
copied cross-instance reference because such a reference is not represented.
Rigid placement preserves face strings; assignments are not explicitly sealed
against definition/revision changes. Full per-instance reference validation and
deliberate reassignment controls remain to be implemented in this checkpoint.

This audit was written before production edits for CAD 2.5.1-D. It distinguishes
existing native history from geometric correspondence and does not claim that
face enumeration or triangle indices are persistent identity.

## Implemented contract and verdict

**CAD 2.5.1-D: PASS for the qualified production workflow below. Overall
CAD 2.5.1 milestone: PARTIAL.** The separate milestone audit is at the end.
The [measured receipt](evidence/cad251-face-identity/final-receipt.json) records
source hashes, executed checks, solver paths, reference records and preservation.

Final evidence root:
`D:/PROJECT/TEST_OUTPUTS/CAD/cad251-face-identity/final-1794701326345/`.
Earlier attempts remain preserved. Native/history/partition source evidence
copied into this final attempt is traceable to its recorded source attempt.
Solver jobs retain their original absolute paths; verified ZIP archives and
per-file restoration hashes also reside under the final evidence root.

Production files modified in D:

- `core/cae/assembly_boundaries.gd` (new): reference creation, descriptor anchors,
  explicit legacy migration, validation, rigid revision updates, unresolved
  state and deliberate assignment/clearing.
- `core/cae/assembly_model.gd`: migrates reference records after identities exist.
- `core/cae/cae_document.gd`: independent instances start without conditions;
  adds RefreshCADFaces; retains unresolved origins; validates saved references;
  geometry commits cannot overwrite ownership or engineering inputs.
- `core/cae/calculix_workbench.gd`: checks reference ownership, revisions and
  source anchors against the verified per-instance mesh proof before any deck.
- `scripts/engines/face_identity.py` (new): source identity binding, assignment
  validation, complete import correspondence and mesh proof generation.
- `scripts/engines/instance_placement.py`: verifies source descriptors, rigid
  orientation and planar normals; retains stable source face IDs.
- `scripts/engines/gmsh_study.py`: reference preflight, face-resolution evidence,
  grouped physical surfaces and complete partition node/face collection.
- `scripts/engines/mesh_config.py`: local refinement targets every verified
  surface subdivision of the selected definition face.
- `scripts/engines/cad_model.py`: owned source-face review and source metadata.
- `ui/cae/cad_viewport.gd`: explicit displayed triangle-to-face table and actual
  instance ray picking; primitive analytic selection no longer uses CAD counts.
- `ui/cae/cae_workspace.gd`: readable assignment inspector, review/reassignment,
  clear controls, selected ownership, and one bounded geometry display cache.

No native worker, kernel, composer, FEM equations or exporter was rewritten.
The B/C test setup now explicitly assigns each new instance's conditions rather
than depending on the unsafe historical copy behavior. Thresholds are unchanged.

### Reference schema

The document keeps its existing schema, parts array and definition/instance
UUIDs. Each part has `boundary_schema: 1` and `boundary_refs`, keyed by support
or load_face. A CAD reference contains:

```text
schema, instance_uuid, definition_uuid,
geometry_revision, transformation_revision, source_sha256,
definition_face_id, source_face, state, coordinate_system
```

`source_face` anchors the intended immutable physical face with source area and
centroid and available inertia, bounds and planar outward normal. Source anchors
are checked against both cached definition metadata and the actual meshed source
face. Altering cached face names/descriptors cannot silently redirect an existing
assignment. Nonfinite anchors and missing/current-schema records are rejected.
Primitive named regions retain their analytic parametric identity; CAD faces use
the verified source evidence. Legacy documents explicitly acquire qualified
records on document migration, not during solver preparation.

Resolved records must match owner, definition, geometry hash/revision, face and
accepted placement revision. Unresolved records retain their original reference
and reason, block analysis, and survive reopen. Explicit reassignment creates a
current reference with `reassigned_from` diagnostics; removal clears the record.
Rigid document transforms preserve the face ID and advance the accepted placement
revision, but native correspondence must still succeed before solving.

Definition edits preserve references only for genuinely unchanged native history
continuations. Unknown, modified and deleted identities become unresolved. The
real native Boolean-history fixture preserves five base faces while changing the
cap. Its unchanged support is preserved; the changed loaded face is archived and
requires reassignment. Primitive-to-CAD conversion also preserves unresolved
diagnostics rather than discarding its original condition.

### Geometry-to-mesh verification

The chain is explicitly separated:

`definition UUID/source SHA → definition face/anchor → instance UUID/revision
→ transformed native face → verified Gmsh surface set → boundary triangles/nodes`.

Rigid transport checks positive valid BREP, volume/area invariants, transformed
centroid, rotated surface inertia, unchanged orientation and rotated planar outward
normals. Curved faces do not receive an invented constant normal. The initial
opaque legacy-name binding must be unique; saved full descriptors strengthen it.
New reviewed source names are deterministic descriptor/hash identities, independent
of face enumeration. An instance move never creates new arbitrary face IDs.

Gmsh correspondence uses complete unique area/centroid/inertia/bounds evidence and
planar type/normal checks. One-to-many planar subdivisions must conserve area,
centroid, parallel-axis surface inertia and bounds and form an edge-connected
partition. A genuine Gmsh fragmentation test resolves seven imported surfaces to
six native definition faces. All physical patches are collected into one boundary
group, including local refinement, linear triangles and quadratic midsides.
Unproven curved subdivisions reject explicitly instead of dropping a patch.

These are validated geometric equivalences at documented native tolerances, not
fabricated OCCT Modified/Generated/Deleted history or a proof for arbitrary shapes
at every floating-point scale. Actual native history remains the authority for
unchanged feature-edit continuations. No nearest-centroid or first-match fallback
authorizes a boundary.

### Ambiguity and Workbench workflow

The real ambiguity fixture is a valid grooved cylinder. Two coplanar top faces
have equal area and centroid but different inertia/bounds. Weak legacy evidence
is blocked. Reviewing the shared definition obtains stronger native descriptors
and deterministic face names, marks existing assignments unresolved, and allows
the user to click a physical replacement and deliberately reassign it.

The existing inspector now exposes Face assignments before dimensional details.
It shows selected face, owner, condition state, global force, unresolved reason,
review, assign/reassign and clear controls. Full identifiers/reasons are available
as tooltips when compact labels are used. Review is an explicit confirmed action
because it marks conditions on that definition unresolved. Undo/Redo are normal
document snapshots. Native failure or a changed request signature cannot commit
new review metadata to a different instance.

Picking ray-tests the actual displayed triangles of each visible instance and
uses the explicit triangle-to-definition-face table. The nearest actual hit wins;
screen-space proximity is not used as instance identity. Five actual viewport
clicks were exercised through mouse-event navigation, including rotated STEP and
both selected instances. Face IDs and UUIDs are recorded in gui-picks.json.

### Executed acceptance

| Requirement | Measured acceptance |
| --- | --- |
| Duplicate independence | Different supports and loads; no inherited conditions on AddInstance/Duplicate |
| Translation | Assigned faces retain identity through translation, remeshing and solve |
| Nontrivial rotation | 37° placement; correct global vector, selected face, reactions and moment |
| STEP | Two independently placed instances; references preserved after reopen |
| Symmetric ambiguity | Equal-area/equal-centroid native faces block weak evidence; explicit GUI review and reassignment succeeds |
| Definition change | Real OCCT history preserves unchanged faces; changed face is unresolved |
| Instance deletion | Deleted owner's conditions cannot migrate to the remaining instance |
| Touching solids | Loaded body and unloaded independent partner; no force transfer |
| Positive interference | C preflight still rejects overlap after assignment |
| Persistence/Undo/Redo | Assignment, clearing, moves, native edits and reassignment tested; UUIDs stable |

The anchored final schema passed 24 genuine CalculiX 2.23 jobs: six scenarios
(duplicate, translated, rotated, STEP, touching, reassigned), both C3D4 and C3D10,
before/after reopen with regenerated meshes. All 48 per-instance checks passed.
Maximum relative displacement error was 1.54108e-7; maximum relative reaction
imbalance 1.22071e-7; maximum normalized reaction-moment discrepancy 1.22134e-7.
The original displacement/reaction thresholds remain 1e-4 and 1e-5; the moment
check uses 1e-5 with an explicit force/length normalization. Unloaded touching
partners remain below 1e-14 m axial displacement.

Independent auditing of all 24 actual decks checks IDs, C3D4/C3D10 widths, material
sections, disjoint ownership, support-node membership on the correct native
world-space plane (including every TET10 midside), load-plane membership, global
force/moment and absence of ties, equations, springs or contact. Touching interfaces
retain coincident coordinates with distinct node IDs. Audit tolerances account
for existing float32 geometry/traction arithmetic; no production solver tolerance
was altered. Complete reaction vectors, moments, representative displacement,
references, mesh surface sets and actual job paths are in the external rows.

Forty document/history checks pass. Eleven negative/stale document checks cover
missing/deleted/cross-instance identities, missing UUID, descriptor corruption,
stale mesh/results/classification, missing mesh face and overlap. Corrupted saved
references are rejected before replacing the active document. Five real native
failure checks cover invalid STEP reading and pipeline use, operation failure,
timeout and cancellation. Existing B failure checks and C's native failure matrix
were also rerun; injected failures are identified as such in their records.

### GUI, performance and preservation

Sixteen actual screenshots (eight views at 1280×720 and 1920×1080) cover each
selected instance, rotated STEP selection, unresolved warning, explicit
reassignment, successful TET4/TET10 results and reopened corrected references.
The screenshots were inspected; the assignment actions and unresolved diagnostics
are visible at 720p. The UI has one active selected face; the independent instance
highlights are captured sequentially, not presented as simultaneous multi-select.

Median measured complete Gmsh face resolution was approximately 24.0 ms. Median
document reassignment mutation was 637 µs over 20 samples. Actual GUI checks
verify that boundary-only assignments reuse the existing native display geometry.
The display cache contains one immutable geometry snapshot; geometry, placement or
face-name changes invalidate it. No new unbounded cache was added.

Worker Job Objects, timeout/cancellation, memory/log/output bounds, atomic receipts
and failure diagnostics remain in force. D did not rebuild the native worker.
All seven original binary pins and all 243 SDK runtime DLL hashes are unchanged.
The final default regression campaign passes 28/28. Existing A document tests,
B placement/failure tests, C native classification tests and all three C assembly
solver scenarios were rerun successfully. Full historical numerical and long
GUI/endurance campaigns were **NOT RUN**; there is no leak-free claim.

### Reproduction

Use installed Python explicitly and the pinned Godot executable. Native Python
runners write a unique attempt and `face-identity-attempt.txt`:

1. Run cad251_faces_native.py, cad251_faces_history.py and cad251_faces_partition.py.
2. Set UNICORE_FACE_OUT to that attempt, UNICORE_PYTHON explicitly, and use the
   existing external Godot test profile.
3. Run cad251_faces_solve.gd (all six cases by default), cad251_faces_unit.gd,
   cad251_faces_negative.gd, cad251_faces_perf.gd and cad251_faces_gui.gd.
4. Run cad251_faces_failures.py, cad251_faces_compatibility.py and
   cad251_faces_deck_audit.py.
5. Run the existing 28-regression runner with an external output directory.
6. cad251_faces_receipt.py verifies measured records, logs, pins, SDK hashes,
   screenshots and lossless solver archives before publishing a PASS receipt.
   It expects the final log/directory names used by this campaign.

## Separate original CAD 2.5.1 milestone audit

| Checkpoint | Current assessment |
| --- | --- |
| A | Reusable definitions, independent instances, identity, transformations, material/visibility and compatibility paths revalidated. Original A report was PARTIAL; later checkpoints fill its native gaps. |
| B | Native rigid placement, STEP, genuine TET4/TET10 and failure handling revalidated. |
| C | Native pair classification, cache safety, valid overlapping-AABB cases, touching behavior and overlap rejection revalidated. |
| D | Anchored per-instance references, safe mapping, explicit review/reassignment, GUI picking, stale gates and solver acceptance pass in the qualified domain. |

**Overall CAD 2.5.1 remains PARTIAL.** The original 2.5.1 report also calls for
analysis participation, complete lifecycle/endurance acceptance and broader
original acceptance coverage. Visibility is still display-only: all parts take
part in analysis. Definition geometry is canonical but remains duplicated in
compatibility parts/templates and persistence; storage deduplication is unfinished.
These limitations are not hidden by D's successful face-identity tests.

Recommended next checkpoint: a narrowly scoped CAD 2.5.1 acceptance-closure task
to agree and finish participation/storage requirements and the remaining
lifecycle/endurance qualification. No CAD 2.5.2, interfaces or contact work was
started. Unproven correspondence and unsupported subdivisions continue to block
safely rather than receive guessed identities.
