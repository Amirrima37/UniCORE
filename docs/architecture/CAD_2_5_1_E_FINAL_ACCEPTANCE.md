# CAD 2.5.1-E — final assembly acceptance

**CAD 2.5.1-E: PASS. Overall CAD 2.5.1: PASS.**
This verdict covers independent-body linear static analysis with validated single-solid
BREP/STEP definitions, rigid placements, TET4/C3D4 and TET10/C3D10. It does not
extend to contact, ties, welding, nonlinear assemblies or nonuniform scaling.
The [measured receipt](evidence/cad251-final-acceptance/final-receipt.json) contains
actual UUIDs, job paths, errors, raw-evidence locations, hashes and screenshots.
Previous A/B/C/D reports and receipts are preserved.

## Production implementation

- `core/cae/analysis_participation.gd`
- `core/cae/assembly_storage.gd`
- `core/cae/assembly_model.gd`
- `core/cae/cae_document.gd`
- `core/cae/calculix_workbench.gd`
- `core/cae/mesh_config.gd`
- `scripts/engines/gmsh_study.py`
- `scripts/engines/native_occt.py`
- `scripts/engines/run_owned_geometry.py`
- `ui/cae/cae_workspace.gd`
- `ui/cae/cad_viewport.gd`

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
parts: [{id, instance_uuid, definition_uuid}, ...]  # checked index
canonical_outline: base64(var_to_bytes(lossless engineering outline))
geometry_assets: {sha256(variant bytes): base64(variant bytes), ...}
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

| Geometry | Instances / definitions | Legacy control bytes | Canonical bytes | Legacy / canonical |
| --- | ---: | ---: | ---: | ---: |
| brep | 1 / 1 | 38,373 | 14,654 | 2.62 |
| brep | 2 / 1 | 45,438 | 16,801 | 2.70 |
| brep | 10 / 1 | 102,283 | 34,393 | 2.97 |
| step | 10 / 1 | 316,858 | 43,807 | 7.23 |
| several | 13 / 4 | 111,857 | 41,918 | 2.67 |

Each tested source payload occurs once in the asset pool. Adding instances increases
engineering records without repeating the full source geometry. Measurements are
specific to these fixtures and do not predict universal compression or memory savings.

Example shared definition: `cf1dadf7-4b94-4f1b-b451-9081c9afa7f5`. Independently loaded instances:
`9cefb25c-8722-4bec-aece-1825764f696d` and `71537eb7-c284-4382-bdd6-0f5ba90e1104`. Their first TET4 duplicate
case measured 4.00000005e-07 m and 5.99999998e-07 m
at their respective loaded faces; face IDs and source/world/mesh correspondence are
recorded per row in the receipt, including reopened cases.

## Executed acceptance

| Gate | Latest result |
| --- | --- |
| analysis_participation_TET4_TET10 | PASS |
| canonical_storage_and_migration | PASS |
| A_document_D_identity_and_24_solves | PASS |
| B_C_D_native_contracts | PASS |
| C_12_actual_solves_and_D_face_deck_audit | PASS |
| lifecycle_10_and_recovery | PASS |
| asynchronous_Workbench_20_cycles | PASS |
| memory_growth_investigated | PASS |
| GUI_workflow_and_clean_teardown | PASS |
| inspector_40_rebuild_cleanup | PASS |
| default_28 | PASS |
| CAD23_historical_32 | PASS |
| CAD24_historical_six | PASS |
| seven_binary_pins | PASS |
| 243_SDK_DLL_pins | PASS |
| final_A_geometry_sharing | PASS |
| actual_decks_DAT_equilibrium_and_independent_ownership | PASS |

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
**118 accepted jobs**. It checks unique IDs, C3D4/C3D10
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
UI heartbeat frames. Duration: 19.513–50.118 s;
median 33.559 s. System process
counts, working set, peak commit, output bytes, undo depth and heartbeat counts are
recorded per cycle. System counts include unrelated applications; owned descendants
are tracked separately. Earlier completed and interrupted campaigns remain external.

Investigation found per-frame meshing messages accumulated unbounded RichTextLabel
paragraphs. Production now throttles progress to 200 ms, coalesces duplicate messages
and caps the transient console at 512 paragraphs / 131,072 characters. Full worker
diagnostics are retained in bounded external logs. The final endurance run asserts
these console bounds on every cycle. It also measures static allocation and orphan
nodes, rather than claiming leak freedom from working set alone.

After cycle 20, clearing 38 retained undo snapshots changed
static allocation from 50,155,899 to 46,174,547
bytes. This is an explicit measurement step after the acceptance cycles, not an
application change that removes Undo history. Final workspace destruction releases
owned nodes and job resources; `teardown.json` records memory and zero orphan nodes.
Static allocation at the first/last TET4 samples was 46,071,695 /
47,850,751 bytes, and the TET10 samples were 52,686,375 /
54,106,547 bytes. The cycle-time orphan counter includes controls
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

Latest screenshot directory: `D:\PROJECT\TEST_OUTPUTS\CAD\cad251-final-acceptance\attempt-1794737039861577500\gui-bounded-1794757612009`.
Raw evidence root: `D:\PROJECT\TEST_OUTPUTS\CAD\cad251-final-acceptance\attempt-1794737039861577500`.

## Preservation and footprint

All seven original binary hashes match the pre-edit baseline:

- `D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`: `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`
- `C:\Users\Victus\Desktop\UniCORE-main\.tools\engines\calculix\CalculiX-2.23.0-win-x64\bin\ccx.exe`: `27a9426a1ee2f72c38fbe892e0ffaf38e14867628ffd0235770261b6f3ec9c5f`
- `C:\Users\Victus\Desktop\UniCORE-main\bin\windows\x86_64\unicore_native.godot472.windows.template_debug.x86_64.dll`: `293734a767241b3914f08d9829d6647a3efee5c93a85d375c6744c66296a20cc`
- `C:\Users\Victus\Desktop\UniCORE-main\bin\windows\x86_64\unicore_native.godot472.windows.template_release.x86_64.dll`: `7d0ab1ba5cb393068bdae4424ae1f754e8574b39a9ff93f7358ee63fad7bd03f`
- `C:\Users\Victus\Desktop\UniCORE-main\bin\windows\x86_64\unicore_native.windows.template_debug.x86_64.dll`: `e091dee7d29badf2f8a95b9556417ee20be0dc867f12ab067d5a1e68efaea868`
- `C:\Users\Victus\Desktop\UniCORE-main\bin\windows\x86_64\unicore_native.windows.template_release.x86_64.dll`: `2172eb05b89a7f20a7d39652e7d7253ed499b3e804dea5d8a99b95952498e6eb`
- `C:\Users\Victus\Desktop\UniCORE-main\.tools\engines\gmsh-4.15.2-Windows64-sdk\lib\gmsh-4.15.dll`: `6cac3eefb477265d9fa60bbd869dbbbf7c7ca4cb308c0f8f2b43e91d43de3c1c`

All 243 sealed SDK runtime DLL hashes and the existing OCCT worker hash also match.
No native worker rebuild, SDK relocation, solver replacement or dependency restore
was performed. External SDK, Godot profile, cache and heavy outputs stay under the
established `D:/PROJECT` paths. Dirty/untracked work was inventoried before and after;
no reset, cleanup or removal of unrelated files was performed. Referenced job evidence
is PINNED through the existing retention protocol.

Accessible repository footprint at receipt publication: 3,727,141,346 bytes /
25,311 files before, 3,727,729,875 bytes / 25,337 files after.
Both traversals record 87 / 87 inaccessible legacy
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
| E: participation, canonical storage and lifecycle closure | PASS; measured gates above. |

No mandatory original requirement remains open within the stated qualified domain
when every receipt gate is PASS. Remaining limitations are deliberate safety/domain
limits, not unsupported operations counted as successful. Recommended next action:
review/archive this CAD 2.5.1 evidence using the existing retention workflow. No
CAD 2.5.2, contact or tied-interface implementation was started.
