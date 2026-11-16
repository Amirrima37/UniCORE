# CAD & Meshing 2.4 ? completion

Verdict: **PASS**, within the supported scope and limitations below. The authoritative gates, exact changed-file inventory and source/binary hashes are in [the completion receipt](evidence/cad24-completion/final-receipt.json). The [original report](evidence/cad24-completion/partial-report-original.md) and original `evidence/cad24/` PARTIAL campaign remain preserved. Assemblies, contact, CFD and CAD 2.5 have not begun.

Recovery began on `master`, HEAD `13e40a5a565a273485aa80ea14ed110df36136a2`, with extensive dirty/untracked work. `working-tree-before.txt` records that inventory. No reset, clean or unrelated overwrite was performed. `baseline.json` hashes seven pinned binaries and four relevant sources before recovery. Other pre-edit source hashes were not captured; final production source hashes are sealed in the receipt. Git diff against HEAD alone cannot identify this checkpoint's changes. All seven original executable/DLL pins are checked again at completion.

## Architecture and dependency provenance

The implementation is hybrid: isolated owned native OCCT evaluation, validation and history, followed by pinned Gmsh meshing. Godot and the existing GDExtension do not link the new runtime. No TopoDS object or pointer crosses the standalone/Gmsh ABI boundary. Exchanges use bounded, hashed BREP files in metres and complete unique face mapping. Gmsh's embedded OCCT is not treated as a public C++ SDK.

The official MSYS2 UCRT OCCT **7.8.1-2** SDK is isolated in ignored `.tools/occt-sdk/`, with public headers, import libraries, DLLs and CMake package configuration. The compiler is GCC **15.1.0-1**, using C++17 and `-O2`. `native/build_occt.ps1` records exact compiler/include/link flags and toolkit libraries. Existing MSYS2 binutils, CRT imports, C headers, winpthread and zstd-capable tar are prerequisites, recorded in the package inventory. The installed GCC16 initially failed with the selected TBB/runtime (`WinError 127`); the matching GCC15 runtime resolved it.

`native/occt/sdk-lock.json`, `sdk-provenance.json`, `native-binary-hashes.json` and `msys2-installed-packages.txt` record 108 official package URLs, SHA-256 pins, available build/license metadata and prerequisites. OCCT is LGPL-2.1-or-later with OCCT exception; transitive dependencies retain their own package licenses. PGP signatures were not verified: provenance is official HTTPS plus locked archive hashes. The dependency set is larger than geometry alone because packaged STEP toolkits transitively import visualization/media libraries. The build manifest seals the worker, source, 243 SDK DLLs and external winpthread. Recursive PE import auditing records unresolved dependencies. No pinned Gmsh, CalculiX, Godot or GDExtension binary was replaced.

Exact production filenames/hashes are enumerated in `production_files`: the native worker/build/setup/provision/audit/seal/lock files; native invocation, feature evaluation, memory measurement and retention Python modules; existing CAD/Gmsh and owned geometry/mesh/solver runners; existing CAD document/model/job/CalculiX Workbench code; existing Workbench/Boolean panels and the validation panel. Test files are enumerated separately. The CAD22 independent test archive now includes a receipt-hash suffix to avoid identical-deck/different-timestamp collisions; its numeric/hash assertions are unchanged.

## Genuine validation and persistent topology

The executable invokes `BRepCheck_Analyzer`, `TopExp_Explorer`, `TopTools_IndexedMapOfShape`, shell closure, edge/face incidence, `BRepGProp`, `BRepTools`, `STEPControl_Reader`, `BRepAlgoAPI_Fuse/Cut/Common`, `Modified`, `Generated`, and `IsDeleted`. Native diagnostics include root type, topology counts, signed physical volume, area, centroid, bounds, tolerances and face records. The supported CAE domain is one closed positive-volume solid without auxiliary topology. No arbitrary healing or topology-changing repair is performed.

Validation runs on STEP/primitive creation, Boolean inputs/outputs, transformed output, cached BREP acceptance and before Gmsh meshing. States distinguish VALID, INVALID, UNSUPPORTED, INCONCLUSIVE and KERNEL_ERROR. Analyzer validity does not guarantee every self-intersection is absent or that meshing will succeed. Open-shell, inverted, empty/corrupt BREP and extra-solid cases have real diagnostics. Failed native operations never publish new active geometry.

Topology schema 2 stores stable feature/operation UUIDs, dependencies, operation histories, ancestry, persistent face identity, geometry revision and verification descriptors. STEP source identity includes its immutable hash and unit conversion. No native pointer survives a session. Dependency evaluation is deterministic and independent of graph-node enumeration.

Before consulting an operation's local history slots, the evaluator verifies a complete unique bijection between actual reimported input faces and persistent records using area, centroid, bounds, inertia and orientation. A genuine BREP fixture reverses shell face enumeration and exercises this check. Slots and Gmsh tags are temporary keys. Non-unchanged IDs incorporate generating feature and transitive recipe revisions, including upstream edits; numeric signatures normalize JSON integer/float representation. Unchanged identities inherit only verified native ancestry. Reversed cavity tool faces are not unchanged merely because native shape lookup ignores orientation. Missing ancestry remains ambiguous.

The subsequent Gmsh import has a separate complete unique descriptor mapping and cross-checks volume, area, centroid, bounds, counts and boundary coverage. Legacy saved face strings remain opaque tokens verified against saved descriptors. There is no nearest-face fallback or index-based assignment.

Only verified unchanged native provenance preserves a condition. Modified/transformed/split/merged/deleted/ambiguous faces archive their configuration and create pending review. Consumed Boolean operand conditions are archived too. Pending conditions block a new solver deck. Explicit reassignment/clearing resolves review while retaining the archive. Undo/Redo and save/reopen preserve state. Unknown topology versions are rejected without mutating the document; unchanged solved projects reopen current.

## Transformations and geometry qualification

Similarity operations use real `BRepBuilderAPI_Transform`; general affine operations use `BRepBuilderAPI_GTransform`. Translation, XYZ/arbitrary-axis rotation, uniform scaling, reflection and qualified planar nonuniform scaling retain BREP geometry. Tests independently check determinant volume, centroid, similarity area, bounds and reflected planar outward normals. Normals use crossed surface derivatives and face orientation, including indirect reflected frames.

The curved nonuniform STEP cylinder is explicitly UNSUPPORTED because native computed volume misses the affine invariant by about **0.8615%**. It is rejected rather than approximated. Uniformly scaled/rotated/mirrored curved STEP fixtures pass. Ambiguous source units are rejected rather than inferred from dimensions.

`native-qualification.json`, `geometry-extra-matrix.json`, `protocol-and-invalid-geometry.json` and `persistent-history.json` record actual results: overlapping/coincident boxes, Fuse/Cut/Common, through/blind holes, thin pipe, nested cuts, nearly coincident faces, tiny features, tangent cylinders, STEP+primitive, STEP+STEP, rotations/scales/reflections, planar nonuniform transforms, invalid/open shells, inverted/corrupt BREP, sequential history and unrelated similar faces. Coarse thin-pipe meshing fails, then succeeds with recorded refined settings. Coarse nested-cut/tiny-feature mesh failures remain failures. Tangent cylinders are correctly rejected as nonmanifold/multiple-solid geometry. Rejected valid nonuniform geometry is a limitation, not a geometric PASS.

## CAE, GUI and isolation

Six new genuine CalculiX cases cover Fuse overlap, through-hole Cut and transformed STEP, each at TET4/TET10. `structural-numerical.json` retains actual jobs, exits, reactions and displacements. `independent-deck-audit.json` independently sums real INP loads/moments against reactions. Axial rectangular cases use an analytic reference; the hole case checks equilibrium without claiming exact continuum displacement. Pending assignments are tested before deck creation. Established TET10 mathematics, materials and solver coupling remain intact.

The campaign reruns CAD21 geometry/integration/lifecycle/STEP-modal-transient preservation; CAD22 mesh/numerical/persistence/independent/lifecycle; CAD23 unit/numerical/persistence/independent/lifecycle/shutdown/GUI; editor scan and the native default manifest. The receipt records actual commands, exits and immutable attempt paths. All 32 CAD23 numerical cases retain their reference assumptions, including approximately 0.0156% finest quadratic bending error relative to Euler?Bernoulli theory, not exact 3D continuum convergence. The default requirement remains 28/28 without weakened assertions.

Actual Godot screenshots at 1280?720 and 1920?1080 cover primitive/native validation, transformed STEP/history, transform preview, archived conditions requiring review, reassignment/remesh/CalculiX displacement and stress, and reopened current results. The receipt inventories PNG dimensions/hashes. Native validation and review views were visually inspected. The existing explorer, viewport, property panels and design language are used.

Workers launch suspended and enter Windows Job Objects before resume. Protections include kill-on-close, owner monitoring, cancellation, deadline/memory/log/output limits and atomic publication. Native limits are 768 MiB, default 40 s (maximum 120 s), 1 MiB request, 64 MiB input/output BREP and 16 MiB response. Filename-only job paths reject traversal. Response identity, schema, units and hashes are verified; source/runtime pin mismatch rejects work.

Lifecycle receipts cover cooperative cancellation during observed STEP/Cut operations, forced zero timeout, injected native TerminateProcess exit 77, abrupt Godot owner exit and genuine recovery. Actual native DWORD, launcher/Godot exits and surviving observed PIDs are retained. Injected termination demonstrates isolation; it does not reproduce a particular OCCT segfault. The historical Godot access violation remains unresolved.

## Retention, endurance and failed attempts

`UNICORE_JOB_QUOTA_BYTES` defaults to 2 GiB; `UNICORE_JOB_RETENTION_DAYS` to seven days, with a 600-second grace period. Only registered completed jobs in established namespaces are eligible. Active, historical/unregistered, PINNED, ARCHIVED and user project data are excluded. PID creation time protects owner identity; abandoned jobs are recovered. Cleanup uses containment/reparse checks, concurrency locking and recoverable metadata. Statistics distinguish protected and quota-accounted data. This is not a hard operating-system quota on all files.

The fixed native workload has 100 primitive/Boolean/transform cycles, ten STEP imports, ten alternating TET4/TET10 remeshes and serialized reload checks, with actual exits, post-cleanup host memory and observed orphan counts. The GUI workload has 60 edit/select/reassign/save/reopen cycles, alternating-order solves every fifth cycle and on the last, heartbeat, RSS/commit samples and disk/job counts. `endurance.json` and `gui-endurance.json` retain every measurement. GUI memory and boundary archives grow over this bounded run; no unlimited leak-free claim is made. The interrupted 32-of-60 attempt remains non-passing evidence.

Failed attempts remain retained: SDK ABI/build errors, coarse meshing failures, oversized initial validation dialog, numeric metadata-version parsing, reflected-normal measurement, source-pin mismatch during concurrent rebuild, archive collision, Windows completion-marker sharing and interrupted endurance. Completion marker publication now retries transient Windows locks; persistent locking leaves a warning and recoverable active marker. Solver launcher output/exit is retained separately from actual CalculiX output. The summary receipt lists failed campaign attempts as well as successful latest runs.

## Reproduction

Run from the repository root with Python 3.14 and the recorded MSYS2 prerequisites. The runner configures pinned Godot and isolated APPDATA/LOCALAPPDATA.

```powershell
$env:UNICORE_PYTHON='C:/Users/Victus/AppData/Local/Python/pythoncore-3.14-64/python.exe'
& $env:UNICORE_PYTHON native/occt/setup_sdk.py
powershell -ExecutionPolicy Bypass -File native/build_occt.ps1
& $env:UNICORE_PYTHON native/occt/audit_runtime.py
$env:UNICORE_CAD24_GUI_ENDURANCE_ITERATIONS='60'
& $env:UNICORE_PYTHON tests/run_cad24_completion.py
& $env:UNICORE_PYTHON tests/summarize_cad24_completion.py
```

Named modes may restrict the runner. Individual receipts, not the outer runner exit alone, determine acceptance. The summary refuses PASS when a required latest run, pin, iteration count, resolution or regression gate fails. Original PARTIAL receipts and all failed attempts remain preserved.


## Final measured outcome

All required latest campaigns passed, including the final editor scan and **28/28 default regressions**. The preserved CAD23 numerical record has **32 cases**; the new structural campaign has **six** genuine cases. Their maximum relative reaction imbalance is **2.44140625e-7**. Independent actual-deck force/moment auditing passed. All seven original binary pins are unchanged.

| New structural case | Order | Axial tip displacement (m) | Relative reaction imbalance |
| --- | --- | --- | --- |
| Fuse overlap | TET4 | 6.34920617e-8 | 6.10352e-8 |
| Fuse overlap | TET10 | 6.34920600e-8 | 6.10352e-8 |
| Through-hole Cut | TET4 | 1.08805447e-7 | 2.44141e-7 |
| Through-hole Cut | TET10 | 1.08926116e-7 | 1.22070e-7 |
| Transformed STEP | TET4 | 2.38095225e-7 | 6.10352e-8 |
| Transformed STEP | TET10 | 2.38095200e-7 | 5.60448e-15 |

The final 100-cycle native campaign took **434.02 seconds**. Host post-cleanup working set grew from **69,173,248 to 104,570,880 bytes**; maximum observed native peak commit was **23,937,024 bytes**. Every recorded native exit was zero and observed native orphan count was zero. The GUI 60-cycle campaign took **1057.96 seconds** and completed **13 real solves**. GUI sampled working set grew from **452,620,288 to 871,243,776 bytes**, with peak **885,030,912 bytes**. These are bounded-workload measurements, not proof of a plateau or leak-free behavior. The GUI endurance run precedes the final face-order/recipe-verification and inspector-cache fixes; the final build separately reran the native endurance, adversarial history, six numerical solves, lifecycle, GUI screenshots and regressions.

The inventory contains **16 actual screenshots**, eight workflow views at each requested resolution. Failed attempts and their original diagnostics remain in the completion folder. The original PARTIAL receipt remains unchanged. No background acceptance work is required after this receipt is sealed.
