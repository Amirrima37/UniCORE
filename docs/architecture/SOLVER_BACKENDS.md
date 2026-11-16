# Backend contract — initial partial implementation

Current CalculiX Workbench path: analysis selector persists `backend=calculix`.
Pinned binary plus Gmsh/Python presence enables the experimental static TET4
entry. `calculix_workbench.gd` adapts study regions/materials to the canonical
exporter, launches a Python-owned native solver process off the Godot main
thread, and maps genuine DAT fields into the existing result renderer.
Cancellation uses a job-owned request file; terminal receipts follow child wait.
Failed/changed/cancelled jobs publish no result. Extreme remains unchanged.
Earlier notes saying no Workbench path exists are superseded by this section.

Checkpoint 2 adds `calculix_backend.gd`: canonical TET4 validation, input deck,
isolated preparation, synchronous actual solver execution and DAT parsing.
It remains outside registry discovery because production job lifecycle and
Workbench acceptance are incomplete. See CALCULIX_CHECKPOINT2.md.

`core/cae/solver_backend.gd` defines a fail-closed orchestration interface.
It is not a functional external adapter. Registry discovery currently returns
only the existing Extreme CPU installation and explicitly distinguishes file
presence from numerical validation. Existing execution remains unchanged.
The analysis dialog exposes dependency status. External selection is withheld.

Next: implement an Extreme adapter delegating to extreme_jobs.gd, then a
CalculiX adapter with strict model validation, immutable preparation, owned
process monitoring/cancellation, DAT/FRD import and atomic publication.
Version, capability and validation evidence must precede external availability.
