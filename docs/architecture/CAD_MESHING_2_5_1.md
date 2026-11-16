# CAD & Meshing 2.5.1 — working increment

## Current acceptance authority: CAD 2.5.1-E

The original working increment below is retained as historical evidence. Its
outstanding list is superseded by the production A/B/C/D implementation and the
[E final acceptance report](CAD_2_5_1_E_FINAL_ACCEPTANCE.md), with the
[measured final receipt](evidence/cad251-final-acceptance/final-receipt.json).

The final implementation has independent analysis participation, canonical
definition geometry storage, safe legacy migration, verified per-instance face
ownership, native placement/interference and genuine TET4/TET10 analysis.
Final lifecycle qualification includes actual cancellation/shutdown/recovery,
20 asynchronous Workbench mesh/solve/clear cycles, bounded console logging,
resource measurements and real GUI evidence at both required resolutions.
The receipt separately audits A/B/C/D/E, the 28 default regressions, current
historical campaigns and all original binary/SDK hashes. Its verdict applies to
the documented independent-body linear-static domain; no contact or tied
interfaces are introduced.

## Historical completion attempt: additional numerical qualification

The completion attempt remains **PARTIAL**. The original `cad251/final-receipt.json`
is preserved. New evidence and its separate receipt are under
`cad251-completion`. No production assembly-model implementation was completed
in this attempt; the outstanding architecture and GUI requirements below remain.

The numerical fixture now accepts `UNICORE_CAD251_PART_COUNT=3` (default two).
The third body uses 300 GPa, otherwise retaining the documented zero-Poisson
axial patch assumptions, force, dimensions and unchanged error thresholds.
Both orders completed genuine CalculiX jobs and all six per-body checks passed.
TET4 used 282 nodes/654 elements; TET10 used 1485 nodes/654 elements.
The third displacement was 1.333333e-7 m against 1.333333333e-7 m, relative
error approximately 2.5e-7. Maximum relative reaction imbalance was 1.22e-7.
The complete attempt took 45.90 s; solver durations were 0.518 s and 1.148 s,
with reported peak commit 170143744 and 171282432 bytes respectively.
The generalized independent deck audit checks total force against the number
of actual material sections, retaining disjoint ownership and coupling checks.

Evidence root:
`D:/PROJECT/TEST_OUTPUTS/CAD/cad251-completion/three-material/CAD/cad251/`.
Set `UNICORE_TEST_OUTPUT_ROOT` to
`D:/PROJECT/TEST_OUTPUTS/CAD/cad251-completion/three-material` and
`UNICORE_CAD251_PART_COUNT=3`, then run `tests/run_cad251.py` and
`tests/cad251_deck_audit.py` with the installed Python. Existing two-body
defaults are preserved. Completion baseline inventory is
`D:/PROJECT/TEST_OUTPUTS/CAD/cad25/inventory-1794693336808567600/inventory.json`.
Full regression, lifecycle, new GUI, native pair-inspection and transformed STEP
campaigns were not performed in this attempt. Prior passes remain historical.
Total repository size before/after remains unmeasured. Contact and ties remain
excluded. The native worker's single-solid Common result path is not sufficient
for safe empty/touching pair classification; it was not substituted for the
conservative interference rejection.

Verdict: **PARTIAL**. Independent multi-body, multi-material FEM is connected to
the existing Workbench backend and has genuine CalculiX evidence. The complete
production assembly checkpoint is unfinished.

## Architecture and ownership

The existing document `parts` array remains authoritative. Each part is meshed
separately through the existing Gmsh pipeline inside the owned meshing process.
The CAD25 composer concatenates nodes without coordinate welding and preserves
instance/material ownership, local/global element IDs and C3D4/C3D10 types.
Per-part meshes remain available for freshness and boundary validation.
Boundary node groups, linear surface triangles and quadratic surface nodes are
offset per instance into the composed mesh. Existing per-part native/Gmsh CAD
ancestry checks remain active. No new claim of assembly face-reference identity
or arbitrary outward orientation qualification is made.

The assembly solve uses the existing single-body validation and consistent face
traction integration to prepare each body's canonical model. It offsets the
DOFs, checks canonical element order against the composed mesh and exports one
CalculiX job. Every element has one material index and a corresponding ELSET and
SOLID SECTION. TET10 retains the existing permutation, Bernstein certificate,
midside nodes and integration-point handling. Engineering strain uses the owning
element's material compliance. There are no ties, springs, contact or welds.

Only uniform element order per job is accepted. Fixed supports and distributed
total face forces are supported through this path. Pressure and prescribed
displacement remain explicitly rejected by the existing CalculiX Workbench
adapter. Missing/pending boundaries and stale instance geometry block solving.
Possible interior interference is conservatively rejected when mesh bounding
boxes overlap by more than 1e-10 m along all axes; touching is permitted.
This broad-phase gate can reject valid separated curved bodies. It is not exact
OCCT interference detection and does not qualify arbitrary geometry.

## Numerical evidence

Two touching 0.1 × 0.4 × 0.1 m bars have independently fixed Y- faces and 1000 N
Y+ forces. Their elastic moduli are 100 and 200 GPa; Poisson's ratio is zero.
Zero Poisson's ratio makes this a uniform axial patch with the stated complete
end restraint, so FL/(EA) is appropriate. Thresholds are 1e-4 displacement error
and 1e-5 relative force imbalance. This is a patch test, not general continuum
convergence evidence.

| Order | Nodes | Elements | Tip displacements (m) | Reference (m) |
| --- | ---: | ---: | --- | --- |
| TET4 | 188 | 436 | 4e-7, 2e-7 | 4e-7, 2e-7 |
| TET10 | 990 | 436 | 4e-7, 2e-7 | 4e-7, 2e-7 |

Maximum observed relative reaction imbalance is approximately 1.22e-7.
Rounded DAT displacements match the reference; this does not imply exact
machine-precision agreement. Actual values, Job Object resource measurements,
solver exits and job locations are retained externally in `numerical.json`.
Independent auditing reads actual INP bytes and checks unique IDs, connectivity,
disjoint node ownership, exactly one material section per element, total force
and moment, and absence of coupling keywords. It does not yet independently
qualify CAD surface orientation or all applied constraints against CAD faces.

## Workbench and persistence

Existing controls provide multiple primitive parts, per-part materials, supports,
loads, mesh generation and solve. The reopened TET10 solution was rendered in
the actual Workbench and captured at 1280×720 and 1920×1080 for displacement and
stress. The displacement capture was visually inspected. These four captures
do not satisfy the entire requested GUI workflow matrix. No new placeholder
controls were added. Solved documents retain the existing lossless mesh payload.
The focused test checks reopened mesh coordinates; later validation also checks
result freshness and rejection of stale geometry and pending boundary review.
The receipt records which latest attempt actually passed those checks.

## Preservation and resources

Pre-edit inventory: `D:/PROJECT/TEST_OUTPUTS/CAD/cad25/inventory-1794689511361805300/inventory.json`.
It records HEAD, dirty-tree inventory, source hashes, paths and unchanged original
binary pins. Heavy outputs remain external. No kernel or engineering binary was
rebuilt or replaced. Mesh/prepare/solver workers retain their existing Job Object
limits, cancellation and timeouts; a dedicated new multi-body cancellation and
shutdown campaign is still required. No leak-free or orphan-free claim is made.

The 28 default regressions passed in `cad251/default-regressions-1`. Native CAD24
geometry and persistent history were invoked with a separate output root under
`cad251/preservation`, preserving CAD24 receipts. The initial editor scan showed
no script failures but could not save external editor settings in the sandbox;
it is not counted as a clean final scan. The 32 CAD23 and six CAD24 structural
campaigns were not rerun. Source inventory bytes are available; total repository
footprint before and after was not measured.

## Outstanding mandatory work

Reusable geometry definitions, stable definition/instance UUIDs, independent
instance transforms through native BREP, assembly-specific persistent face
references and their archival policy, transformed STEP assembly GUI, analysis
participation, complete persistence/Undo/Redo qualification, the three-material
and transformed/imported numerical matrix, GUI interaction coverage and lifecycle
acceptance remain incomplete. Existing CAD graph transform restrictions remain.
This increment must not be described as the requested production assembly layer.

Reproduce with installed Python 3.14.7:

```powershell
& $env:UNICORE_PYTHON tests/run_cad251.py
& $env:UNICORE_PYTHON tests/cad251_deck_audit.py
& $env:UNICORE_PYTHON tests/run_cad251.py gui
& $env:UNICORE_PYTHON tests/test_assembly_mesh.py
```

All evidence is rooted at `D:/PROJECT/TEST_OUTPUTS/CAD/cad251/`; failed attempts
remain alongside successful attempts. `final-receipt.json` lists exact changed
files/hashes, latest measurements and gaps. No CAD 2.5.2 work was started.
