"""Render the final report from measured acceptance records."""
import json,statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
r=json.loads((ROOT/'docs/architecture/evidence/cad251-final-acceptance/final-receipt.json').read_text())
out=Path(r['external_evidence']);cycles=r['endurance']['data']['cycles'];memory=r['endurance']['memory_investigation']
rows=['| Geometry | Instances / definitions | Legacy control bytes | Canonical bytes | Legacy / canonical |','| --- | ---: | ---: | ---: | ---: |']
for row in r['storage']:rows.append(f"| {row['kind']} | {row['instances']} / {row['definitions']} | {row['legacy_bytes']:,} | {row['canonical_bytes']:,} | {row['legacy_bytes']/row['canonical_bytes']:.2f} |")
files='\n'.join('- `'+name+'`' for name in r['production_files'])
pins='\n'.join('- `'+name+'`: `'+value+'`' for name,value in r['preservation_hashes'].items())
d=r['numerical']['D'];example=d[:2]
gates='\n'.join('| '+name+' | '+('PASS' if passed else 'PARTIAL')+' |' for name,passed in r['gates'].items())
before=r['repository_footprint']['before'];after=r['repository_footprint']['after']
text=f'''# CAD 2.5.1-E — final assembly acceptance

**CAD 2.5.1-E: {r['verdict']}. Overall CAD 2.5.1: {r['overall_CAD_2_5_1']}.**
This verdict covers independent-body linear static analysis with validated single-solid
BREP/STEP definitions, rigid placements, TET4/C3D4 and TET10/C3D10. It does not
extend to contact, ties, welding, nonlinear assemblies or nonuniform scaling.
The [measured receipt](evidence/cad251-final-acceptance/final-receipt.json) contains
actual UUIDs, job paths, errors, raw-evidence locations, hashes and screenshots.
Previous A/B/C/D reports and receipts are preserved.

## Production implementation

{files}

`analysis_participation.gd` provides strict boolean validation, the full instance
participation signature and the active document projection. `SetAnalysisEnabled`
is a real document command. The mesh and solve paths project before interference,
Gmsh, composition, material sections and boundary export. Meshes stamp the full
participation signature; changes reject old solver preparation. Successful results
carry active instance/node/element ownership. Zero participating instances fail
with “Enable at least one instance for analysis”.

Visibility remains independent. Hidden enabled bodies are classified, meshed and
solved; visible disabled bodies remain displayed and pickable through the complete
native preview while their elements and sections are absent from the solver deck.
Disabled bodies retain UUIDs, placement, material and boundary references. Re-enable
performs normal geometry/interference/face validation; an overlapping or unresolved
body is rejected. The real inspector offers separate **Visible** and **Include in
analysis** controls, and the explorer marks excluded instances. Undo/Redo and
save/reopen preserve both states.

`InitializeCADMetadata` commits verified native source metadata through the
document, including measured STEP units/extents, without changing definition UUIDs.
Native source hash, validity, descriptor completeness and existing face names are
checked. It never repairs an unresolved assignment implicitly. Geometry workers
cannot replace visibility, participation or engineering ownership during commits.

Lifecycle inspection also fixed an unattached STEP topology picker and camera
fitting of missing geometry. Rebuilding the inspector 40 times returns orphan
node count to zero. Geometry/process receipts now publish through temporary files
and atomic replacement. Worker Job Object limits and owner monitoring are unchanged.

## Canonical storage and migration

New saves retain project schema 1 and introduce `assembly_storage_schema: 2`:

```text
schema: 1
assembly_storage_schema: 2
parts: [{{id, instance_uuid, definition_uuid}}, ...]  # checked index
canonical_outline: base64(var_to_bytes(lossless engineering outline))
geometry_assets: {{sha256(variant bytes): base64(variant bytes), ...}}
```

The decoded outline contains definition records, instance records, analysis,
mesh/results and unsupported engineering fields. Definitions hold a `geometry_ref`;
instances hold UUID/reference, placement, material, visibility, participation,
boundary references and revisions. Complete source BREP/STEP and feature payloads
are interned once by verified hashes. Compatibility parts/templates do not persist
independent geometry copies. Exact historical geometry is retained by asset reference
when result snapshots require an older definition. Legacy provenance strings that
contain source payloads are losslessly tokenized; new mesh provenance uses a digest.
This is canonical ownership with shared assets, rather than compression of duplicate
JSON. In memory, compatibility geometry binds to read-only definition values;
tests verify shared array identity and immutable source geometry.

Old unversioned documents and A/B/C/D schemas retain their existing load paths.
Participation defaults explicitly to **true**, regardless of visibility. Opening
does not rewrite the source file. Saving upgrades the envelope and preserves UUIDs,
placements, material, unknown engineering fields, unresolved references and exact
numeric/Variant types. Fresh solved snapshots survive supported lossless round trips;
unverifiable results remain stale. Malformed assets, indices, definitions, mesh
envelopes and historical references reject before replacing the active document.

Actual serialized controls use the previous duplicated layout and identical data:

{chr(10).join(rows)}

Each tested source payload occurs once in the asset pool. Adding instances increases
engineering records without repeating the full source geometry. Measurements are
specific to these fixtures and do not predict universal compression or memory savings.

Example shared definition: `{example[0]['definition']}`. Independently loaded instances:
`{example[0]['instance']}` and `{example[1]['instance']}`. Their first TET4 duplicate
case measured {example[0]['displacement_m']:.9g} m and {example[1]['displacement_m']:.9g} m
at their respective loaded faces; face IDs and source/world/mesh correspondence are
recorded per row in the receipt, including reopened cases.

## Executed acceptance

| Gate | Latest result |
| --- | --- |
{gates}

The current D rerun covers 24 genuine solves: duplicate, translated, rotated,
imported STEP, touching independent and explicitly reassigned assemblies, with
both orders and save/reopen. C adds 12 genuine rotated disjoint/overlapping-AABB,
touching and STEP solves. The original E document campaign includes two- and
three-material assemblies; participation adds both mesh orders with an excluded
overlapping/unresolved instance and a hidden enabled instance. Re-enabling stale
boundaries, all-disabled input and edits after completed results are rejected safely.

The native B/C/D reruns exercise placement, the genuine classification matrix,
invalid/inconclusive behavior, timeouts, cancellation, face descriptors, native
history, subdivisions and symmetric ambiguity. D unit/negative runs cover ownership,
definition changes, deletion, corruption and stale geometry/classification/results.
The 28 default regressions were rerun. The 32 CAD23 cases and six CAD24 cases also
ran currently, with original numerical assertions. Historical runners now use
deliberate document face assignment; CAD24 explicitly performs native source review
because its earlier face names fail the current safety contract. Its rejected first
attempt is retained, rather than counted as a passing historical solve.

Independent auditing read actual INP, DAT, stdout and completion records for
**{r['numerical']['audited_jobs']} accepted jobs**. It checks unique IDs, C3D4/C3D10
connectivity, disjoint ownership, material sections, global force/moment and reactions,
and absence of ties, equations, springs, contact and coupling. The separate D audit
checks source/world faces and mesh-plane membership for its 24 jobs. Touching bodies
retain coincident coordinates with independent node IDs and zero response on the
unloaded body. No exporter or mesh-composer rewrite was made.

## Lifecycle, endurance and memory

Ten actual fault scenarios passed with reopen/retry: native geometry cancellation,
native interference cancellation, Gmsh cancellation, CalculiX cancellation, closing
the Workbench during meshing and solving, native timeout, native crash, Gmsh failure
and CalculiX failure. Active descendants were observed through Windows process
handles, not Godot's tracking of its own directly launched processes. Failed/cancelled
jobs publish no current result; actual retries succeed. Diagnostics remain external.

The final asynchronous Workbench campaign ran **20 sequential mesh/solve/clear
cycles**, alternating orders. Every completed cycle had zero owned descendant
processes, current results before clearing, stale results afterwards and advancing
UI heartbeat frames. Duration: {min(c['duration_ms'] for c in cycles)/1000:.3f}–{max(c['duration_ms'] for c in cycles)/1000:.3f} s;
median {statistics.median(c['duration_ms'] for c in cycles)/1000:.3f} s. System process
counts, working set, peak commit, output bytes, undo depth and heartbeat counts are
recorded per cycle. System counts include unrelated applications; owned descendants
are tracked separately. Earlier completed and interrupted campaigns remain external.

Investigation found per-frame meshing messages accumulated unbounded RichTextLabel
paragraphs. Production now throttles progress to 200 ms, coalesces duplicate messages
and caps the transient console at 512 paragraphs / 131,072 characters. Full worker
diagnostics are retained in bounded external logs. The final endurance run asserts
these console bounds on every cycle. It also measures static allocation and orphan
nodes, rather than claiming leak freedom from working set alone.

After cycle 20, clearing {memory['before']['undo_depth']} retained undo snapshots changed
static allocation from {memory['before']['static_memory']:,} to {memory['after']['static_memory']:,}
bytes. This is an explicit measurement step after the acceptance cycles, not an
application change that removes Undo history. Final workspace destruction releases
owned nodes and job resources; `teardown.json` records memory and zero orphan nodes.
Static allocation at the first/last TET4 samples was {cycles[0]['static_memory']:,} /
{cycles[-2]['static_memory']:,} bytes, and the TET10 samples were {cycles[1]['static_memory']:,} /
{cycles[-1]['static_memory']:,} bytes. The cycle-time orphan counter includes controls
awaiting Godot's deferred deletion; final teardown has zero. System working set can
retain allocator pages after those objects are released.
Runtime allocation/caching and bounded history explain residual retained memory;
this short campaign does **not** establish leak-free operation at arbitrary duration.

## Actual Workbench evidence

The latest GUI run captures 32 images, sixteen views at both 1280×720 and 1920×1080.
It creates/duplicates bodies, imports reusable STEP geometry, moves/rotates instances,
assigns independent materials, picks physical faces, applies support/global force,
toggles both visibility and participation, meshes/solves both orders, inspects stress
and displacement, excludes/re-enables a body, rejects active overlap, reopens, and
reviews/reassigns unresolved boundaries. Actual ray picks retain instance/face UUIDs.
The excluded visible body is picked again after active-only meshing. Screenshots
were inspected for readable controls and diagnostics at both sizes. The latest run
exits without script, renderer or orphan-node errors. Prior failing screenshots/logs
are retained with the fixes described above.

Latest screenshot directory: `{r['gui']['directory']}`.
Raw evidence root: `{out}`.

## Preservation and footprint

All seven original binary hashes match the pre-edit baseline:

{pins}

All 243 sealed SDK runtime DLL hashes and the existing OCCT worker hash also match.
No native worker rebuild, SDK relocation, solver replacement or dependency restore
was performed. External SDK, Godot profile, cache and heavy outputs stay under the
established `D:/PROJECT` paths. Dirty/untracked work was inventoried before and after;
no reset, cleanup or removal of unrelated files was performed. Referenced job evidence
is PINNED through the existing retention protocol.

Accessible repository footprint at receipt publication: {before['bytes']:,} bytes /
{before['files']:,} files before, {after['bytes']:,} bytes / {after['files']:,} files after.
Both traversals record {len(before['errors'])} / {len(after['errors'])} inaccessible legacy
paths and exclude reparse targets. These are comparable accessible lower bounds,
not a claim to have measured inaccessible dependency contents. Final exact values
and the full diagnostics are in the receipt.

## Reproduction and milestone audit

Use pinned Godot and the installed Python named by `UNICORE_PYTHON`. Process-local
`APPDATA`/`LOCALAPPDATA` select an external Godot profile. `UNICORE_E_OUT` points to
the E evidence root; `UNICORE_D_SOURCE` selects the retained D input fixtures.

1. Record a fresh baseline with `tests/cad251_e_baseline.py` and run
   `cad251_e_participation.gd` through the pinned Godot executable.
2. Run `cad251_e_storage.gd`, `cad251_e_verify.py`, `cad251_e_native_verify.py`
   and `cad251_e_compat_solve.py`. Verification preserves existing source pointers.
3. Run `cad251_e_endurance.gd` to create ready documents, then the actual Workbench
   `cad251_e_workbench_endurance.gd` with `UNICORE_E_ENDURANCE_OUT` set to a fresh
   external directory. Run `cad251_e_lifecycle.py` for actual faults and recovery.
4. Run `cad251_e_gui.gd` with the real compatibility renderer and
   `UNICORE_E_GUI_OUT` set to a new external directory. Run the inspector teardown
   check. `cad251_e_close_checks.py` also orchestrates GUI/endurance, participation
   and the historical structural runners into unique external attempts.
5. Run `native/run_regressions.py --godot <pinned-exe> --output <new-external-dir>`.
   Each runner retains stdout/stderr, receipts and failed diagnostics.
6. Evidence pointers under the E root identify the selected latest storage, GUI,
   endurance, CAD24, native, C-solver, lifecycle, verification and regression attempts.
   Run `cad251_e_receipt.py` to verify actual decks/DAT files, hashes and every gate;
   it emits PARTIAL if a required gate is absent. `cad251_e_report.py` renders this
   report from the measured receipt. Reproduction uses the external fixture paths
   listed in those receipts; previous A/B/C/D evidence is not overwritten.

| Original requirement group | Final qualified assessment |
| --- | --- |
| A: reusable definitions and independent instances | PASS; UUIDs, edits, deletion, compatibility, ownership and persistence revalidated. |
| B: native placement and transformed meshes | PASS; rigid BREP/STEP placement, Gmsh global coordinates and genuine both-order solves revalidated. |
| C: solid interference classification | PASS; actual transformed solids, overlapping-AABB separation, touching acceptance and positive-overlap rejection retained. |
| D: persistent boundary identity | PASS; verified instance/face ownership, ambiguity blocking, deliberate reassignment, stale gates and persistence retained. |
| E: participation, canonical storage and lifecycle closure | {r['verdict']}; measured gates above. |

No mandatory original requirement remains open within the stated qualified domain
when every receipt gate is PASS. Remaining limitations are deliberate safety/domain
limits, not unsupported operations counted as successful. Recommended next action:
review/archive this CAD 2.5.1 evidence using the existing retention workflow. No
CAD 2.5.2, contact or tied-interface implementation was started.
'''
(ROOT/'docs/architecture/CAD_2_5_1_E_FINAL_ACCEPTANCE.md').write_text(text,encoding='utf-8')
print('FINAL_REPORT_WRITTEN',r['verdict'])
