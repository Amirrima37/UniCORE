# CalculiX quick stabilization — PARTIAL

Existing dirty tree and HEAD 13e40a5a565a273485aa80ea14ed110df36136a2 retained.
No kernel, solver pack or prior numerical fixture removed.

Observed campaign: 8/8 steps exit 0, including graphical block/cylinder tests,
solver cancellation/recovery, repeated mesh identity, same-mesh Extreme comparison,
axial/cantilever calculations and the full default runner. Default runner records
28/28 successful actual exits; interval 21:26:34–21:27:28 UTC, 2026-11-12.
These existing tests do not establish the new dedicated mesh lifecycle cases.

Implemented:

- Workbench Gmsh generation now runs in a Thread, with the actual pinned SDK
  executing in a separate owned Python child. Main-thread polling shows elapsed
  indeterminate status. Concurrent mesh/solve launches reject.
- Publication waits for complete worker return and compares parts, analysis and
  mesh density against the immutable launch snapshot. Only complete current
  meshes replace the document. Existing physical-group/orientation checks remain.
- Owned mesh launcher supports cancellation requests and a configurable adapter
  `mesh_timeout_seconds` (120 default), terminates/waits only its child, and
  atomically publishes terminal receipt. Existing Cancel dispatches to that adapter.
- DAT import rejects files over 32 MiB before reading the text into memory.

Changed implementation: `ui/cae/cae_workspace.gd`,
`core/cae/calculix_workbench.gd`, `core/cae/calculix_backend.gd`,
`scripts/engines/run_owned_mesh.py`. Updated actual Workbench test awaits
asynchronous publication before starting its solver acceptance workflow.

Reproduction: `python tests/run_calculix_acceptance.py`. Raw streams, actual
exit codes and timestamps: `evidence/calculix/final-campaign/`; default manifest
receipt: `evidence/calculix/regressions-final/`. Graphical captures remain in
`evidence/calculix/workbench/` at both requested resolutions.

Not yet verified: cancellation during actual meshing, mesh timeout, dedicated
stale-worker/overlap tests, expanded corrupted-DAT cases. No Windows Job Object
or hard per-job RAM limit implemented. Solver logs/output are still not bounded
on disk. Parser file limit is not a complete peak-memory guarantee. GUI polish
and explicit missing-color/component assertions remain unchanged. Therefore no
full stabilization PASS is claimed. Original bending discrepancy and historical
Godot access violation verdict remain unchanged. Stop here; CAD expansion has
not begun.
