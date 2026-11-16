# CAD & Meshing 2.4 — PARTIAL

Native OCCT validation and per-face history have **not** been established. This checkpoint does not satisfy production acceptance. No native calls or topology-history results are fabricated. No assemblies or contact work was introduced.

The existing dirty repository was preserved on branch `master`, HEAD `13e40a5a565a273485aa80ea14ed110df36136a2`. The pre-edit porcelain inventory is `evidence/cad24/working-tree-before.txt`. Much of the existing CAD implementation was already untracked. Git diff against HEAD consequently does not describe this checkpoint's scope. Pre-edit source hashes were not captured; this is an evidence limitation. Executable and DLL hashes are measured before/after the campaign in `final-receipt.json`. The prior recorded baseline was CAD23's 28/28; the new campaign records actual reruns separately.

Architecture decision: retain A, the pinned Gmsh workflow, with explicitly inconclusive native qualification. C, Gmsh meshing plus a separately owned native OCCT executable, is the appropriate future route once a supported SDK is provisioned. B would unnecessarily duplicate the meshing path. There is no evidence of a supported public OCCT ABI in the bundled Gmsh DLL. No internal symbols were linked, binaries replaced, downloads performed, or GDExtension code added.

Local searches covered repository `.tools`, common `C:/OpenCASCADE`, `C:/local`, `C:/vcpkg`, `D:/msys64`, `D:/Applications`, and `D:/Downloads` for native headers/libraries including `BRepCheck_Analyzer.hxx`, `TopoDS_Shape.hxx`, and `TKBRep` import/runtime libraries. None were found. Python `OCC`, `OCP`, and `cadquery` are absent. This is a bounded local inventory, not proof that no SDK exists anywhere on the machine. The pinned public Gmsh wrapper offers real Boolean operations, mass properties, rigid transforms and BREP serialization, but no public invocation of the following required native APIs:

- `BRepCheck_Analyzer`, `ShapeFix_Shape`, `TopExp_Explorer`, `TopTools_IndexedMapOfShape`.
- `BRepAlgoAPI_Fuse/Cut/Common` operation objects and `Modified/Generated/IsDeleted` histories.
- `BRepBuilderAPI_Transform/GTransform`, `BRepGProp`, or `BRepTools` as directly supported C++ APIs.

The existing Gmsh operations may internally use OCCT classes; that does not provide independent validation or expose operation history. OCCT 7.8.1 remains the previously identified embedded version; no separate runtime, license bundle, build settings, or ABI compatibility is asserted. A separately provisioned OCCT SDK would need those records before integration. Analyzer validity alone would still not prove absence of all self-intersections or guarantee meshing success.

Exact production changes:

- `scripts/engines/cad_model.py`: serializes versioned `cad_validation` with status `inconclusive`, explicitly unavailable native qualification, actual Gmsh sanity checks, and versioned descriptor-only topology metadata with graph revision, feature IDs and volume ancestry.
- `core/cae/cae_document.gd`: archives displaced support/load/pressure/prescribed/thermal configurations. New CAD24 evaluations conservatively clear support/load assignments even when descriptors match, because genuine history is unavailable. Pending assignments require explicit reassignment; existing ApplySupport/ApplyLoad commands resolve their own pending entries. ClearAnalysisConditions explicitly discards pending requirements while preserving the historical archive. Existing Undo/Redo and persistence carry these records.
- `core/cae/calculix_workbench.gd`: blocks unresolved pending conditions before solver deck creation. Existing empty-face and physical-group guards remain.
- `ui/cae/cae_workspace.gd`: existing CAD properties display inconclusive native status, missing history and archived boundary configuration. Existing viewport selection and assignment controls remain in use.

New tests: `tests/cad24_boundary.gd`, `tests/run_cad24.py`. The boundary test uses the real evaluated fused-box fixture, verifies invalidation despite matching face descriptors, archival, explicit reassignment and save/reopen. It does not simulate native history. The campaign retains logs, commands, actual exits, wall time and binary hashes in `evidence/cad24/final-receipt.json`. Historical runner outputs remain in their existing checkpoint folders; new top-level attempt logs identify each invocation.

The graph evaluator still uses conservative descriptors to rematch cached BREP faces, not a general persistent naming algorithm. Legacy unchanged projects are not migrated or invalidated merely by opening. New evaluation metadata distinguishes the new conservative boundary policy; it does not retrofit provenance onto old saves. Arbitrary imported/Boolean scaling, reflection and nonuniform curved transformations remain rejected. Existing rigid translations/rotations remain supported; no new native transformation qualification is claimed. Source STEP units/hashes and existing TET10 mathematics are unchanged.

Acceptance limitations: the requested broad CAD24 geometry matrix, native validation stages, genuine history, native transformations, native-worker crash campaign, sustained-memory study and configurable aggregate retention are not implemented. Existing owned worker Job Objects, cancellation, timeout, memory/output bounds and shutdown checks are rerun, not redesigned. Historical acceptance evidence is retained; aggregate disk use remains unbounded. Short lifecycle runs do not establish leak-free behavior. GUI captures from the rerun exercise the existing Workbench, not a completed native validation/reassignment workflow. Missing criteria prevent PASS regardless of preservation results.

Reproduce from the repository root:

```powershell
& 'C:/Users/Victus/AppData/Local/Python/pythoncore-3.14-64/python.exe' tests/run_cad24.py
```

The campaign includes CAD21 geometry/integration/lifecycle/STEP-modal-transient preservation, CAD22 validation/persistence/independent/lifecycle, CAD23 unit/numerical/persistence/independent/lifecycle/shutdown/GUI, editor scan and the default manifest. Failed attempts remain retained. Exact outcomes are in the receipt; absence of a test result is not a pass. CAD2.5 has not begun.

Completed execution: all 17 preservation campaign steps exited 0, all **28/28 default regressions passed**, and all seven pinned executable/DLL hashes were unchanged. The separate CAD24 boundary test and final editor scan exited 0. All 32 CAD23 numerical cases passed; the finest quadratic bending comparison reproduced relative error 0.0001557543 (0.01557543%) and reaction imbalance 6.07496e-7. These compare to Euler–Bernoulli theory, not exact 3D continuum convergence. Current numerical records with genuine solver-job paths and resource measurements are copied into `evidence/cad24/cad23-numerical.json`.

The GUI preservation campaign exited 0 and captured both requested resolutions. The final receipt lists current-run image dimensions and SHA-256 hashes. The 1280x720 selected-face capture was visually inspected: actual rendered STEP-cut body, highlighted face, operation tree and TET10 statistics are present. This does not establish a complete CAD24 native-validation GUI workflow. `native-access.json` records public API/package inspection. `boundary-receipt.json` and `final-scan-receipt.json` record final dedicated checks. A first boundary-test invocation outside the isolated APPDATA environment emitted log-path errors; its retained output was followed by a successful run in the configured environment.

Final decision: **PARTIAL**. Preservation passes; the explicitly listed missing native and production reliability criteria remain unmet.
