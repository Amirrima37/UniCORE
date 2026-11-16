# External structural checkpoint 2: PARTIAL

## Workbench completion campaign — 2026-11-13

**PARTIAL acceptance; working vertical workflow implemented and demonstrated.**
The earlier infrastructure-only status below is historical and superseded here.
Actual existing Workbench now selects the pinned CalculiX 2.23 pack, generates
real Gmsh block/cylinder TET4 meshes, maps CAD physical regions to boundary
triangles/nodes, applies the existing fixed-support and total-face-force study
commands, executes CalculiX on a worker thread, imports actual DAT fields and
renders them in the existing viewport. Selection and results survive save/reopen.
Geometry/material/mesh/load mutations reject stale results in the acceptance test.

### Implementation and executable identity

Pinned executable/version/hashes below are unchanged. No new solver build was
needed. `calculix_workbench.gd` bridges
the canonical adapter to the existing Thread/solve/result lifecycle. Python's
`run_owned_solver.py` starts only the owned native ccx child, sets its isolated
working directory, captures separate stdout/stderr, polls termination and a
cancel file, enforces 120 seconds, terminates then waits (kills only its owned
child if needed), and atomically renames a terminal receipt. This is process
cancellation, not a CalculiX restart/checkpoint protocol. Exact progress is
unavailable; UI reports indeterminate status and elapsed time. Main-thread
publication follows successful termination, diagnostic checks and complete
field validation; changed live model signatures reject publication.

Critical observed behavior: an invalid C3D4 type test exits 0 and prints both
`*ERROR` and `Job finished`. Exit code and completion text alone are insufficient.
The new launcher rejects that case. Actual cancellation, invalid-deck failure
and successful recovery receipts are in `evidence/calculix/process-tests/`.

`gmsh_study.py` uses the actual pinned SDK API and embedded OCCT. It creates
physical surface groups, preserves original node/element tags and material IDs,
checks positive TET4 determinants and exact equality of CAD surface triangles
with the volume mesh exterior, and records CAD/mesh volumes and meshing settings.
One unrotated, unscaled Box or Cylinder is supported. No CAD-import claim.
Single-thread execution is explicit. A pre-generation volume/size budget bounds
mesh requests. Meshing currently blocks the UI during generation; solving does
not. Python 3.14 path defaults to the installed per-user interpreter; override
with `UNICORE_PYTHON` for other installations.

Repeated separate single-thread meshing processes produced identical hashes for
nodes, cells, original tags and boundary triangles for both solids. See
`evidence/calculix/mesh-repeatability/results.json`. The original smoke used two
threads and different size controls; the old 931/932 difference has not been
causally isolated. Count equality is not used as validity evidence.

### Genuine field mapping

All C3D4 elements have one constant-stress integration point. DAT supplies full
nodal U/RF and integration-point S; FRD is generated but is not used to invent
nodal stress. Stress order is xx,yy,zz,xy,xz,yz. Von Mises is computed from those
six actual components. Engineering strain is the isotropic compliance applied
to actual stress, explicitly marked in result metadata. Only constrained DOFs'
printed nodal forces are reported as support reactions. Displacement magnitude,
xyz components, stress components, deformed mesh, undeformed overlay, legend
and existing probes use the exact solved mesh. Original tags remain in the
saved study mesh. Unknown/incomplete/nonfinite field mappings reject.

### Numerical evidence

`evidence/calculix/gmsh-benchmarks.json`: E=210 GPa, L=1 m, square 0.1 m section,
F=1000 N. Axial nu=0 allows the exact uniform strain field with full end support.
Analytical FL/EA=4.7619047619e-7 m; measured 4.761905e-7 m at all three meshes,
relative error 5e-8 at DAT precision.

|TET4 cells|Cantilever tip mean (m)|Euler–Bernoulli relative error|
|---:|---:|---:|
|434|1.0029913e-4|47.34%|
|1818|1.5005415e-4|21.22%|
|3613|1.6026402e-4|15.86%|

Beam reference is 1.9047619e-4 m. This demonstrates the expected TET4 bending
stiffness and convergence trend; it is **not an accuracy PASS at the finest mesh**.
Beam shear and end effects also differ from the exact 3D continuum problem.
Original independent E/F scaling checks remain in `numerical.json`.

Same-mesh Extreme comparison, including tensor-order conversion:

|Solid|Relative displacement L2|Relative stress L2|Extreme residual|
|---|---:|---:|---:|
|Box|1.16e-7|1.94e-7|3.34e-11|
|Cylinder|2.22e-7|2.10e-7|6.18e-11|

Input decks, native outputs and receipts: `evidence/calculix/extreme-comparison/`.
CalculiX algebraic residual is explicitly unavailable, not fabricated as zero.
Support reaction equilibrium is also checked: relative imbalance 5.50e-8 (Box)
and 1.00e-7 (Cylinder), acceptance threshold 1e-5 unchanged. This check exposed
strict integer-versus-float membership after JSON import; normalizing boundary
IDs before lookup corrected the mapping. Earlier zero reaction displays were
incorrect; no force balance was inferred from those earlier displays.

### GUI and regression evidence

Real Vulkan Workbench screenshots at 1280x720 and 1920x1080 are in
`evidence/calculix/workbench/`: `Box`/`Cylinder` × `mesh`, `backend`, `execution`,
`displacement`, `von_mises`. Deformation is magnified and the original wireframe
is overlaid; physical results are unchanged. `Box.json` and `Cylinder.json` are
saved/reopened actual studies. Backend/support/load dialog and contour screenshots
were visually inspected. No mockup/image generation was used.

The old null-exit collector is superseded by the repaired Python runner. The
28-test post-integration run has 28 real zero exits and passing diagnostics:
`evidence/calculix/regressions-after-workbench/results.json`. Final receipts and
separate raw streams are under `regressions-final/`. Expected negative-test
engine errors are retained separately from script failures; warnings are counted.
Headless workflow tests emit existing dummy-renderer mesh warnings. Graphical
workflow runs completed without script errors. Historical Godot access-violation
resolution is not claimed.

### Remaining acceptance limitations

Meshing is synchronous. Workbench cancellation/recovery is automated through
the same adapter method invoked by the existing Cancel action; a literal GUI
button click is not separately automated. Deadline/resource policies
need stress testing; no per-child RAM hard limit is enforced. Component selector
values are mapped but not all have dedicated screenshot/probe assertions. Mesh
count variation in the old two-thread smoke is not fully isolated. Bending
accuracy and broader malformed-result cases need
additional acceptance coverage. Therefore the complete requested campaign is
**PARTIAL**, despite the demonstrated usable block/cylinder vertical workflow.

### Final reproduction and receipts

Final corrected run: **8/8 campaign steps completed with actual exit 0**, including
the graphical Workbench test and **28/28 default regressions with exit 0**.
Final regression interval: 2026-11-12 21:17:44–21:18:37 UTC (2026-11-13 Moscow).
These test receipts do not remove the full-acceptance limitations above.

Run `python tests/run_calculix_acceptance.py` for sequential exporter, patch,
graphical Workbench, owned-process, mesh-repeatability, same-mesh Extreme,
bar/cantilever and full default-regression checks. Machine receipt and separate
streams: `evidence/calculix/final-campaign/`. A passing benchmark process certifies
axial accuracy and records bending errors; it does not certify fine bending
accuracy. Failed earlier campaign logs are preserved in `campaign-before-*`.
`python tests/archive_calculix_evidence.py` copies only jobs whose input and DAT
hashes match the saved Workbench studies into `workbench/Box-job` and
`workbench/Cylinder-job`, including actual INP/DAT/FRD and process receipts.

Actual native Windows CalculiX 2.23 execution achieved. No Workbench integration
claim: do not enable this backend in the selector yet.

## Distribution and identity

Pinned Windows packaging repository:
https://github.com/calculix/CalculiX-Windows/tree/60c9a10b350ec813f4d493098f47f7a8b96cd276

Acquired `releases/CalculiX-2.23.0-win-x64.zip`, SHA-256
`79a674fdee735a22720bbd12bb9ccbadad1e8c8ad5b1de74e1c62f8808b2d395`.
Executable `.tools/engines/calculix/CalculiX-2.23.0-win-x64/bin/ccx.exe`, SHA-256
`27a9426a1ee2f72c38fbe892e0ffaf38e14867628ffd0235770261b6f3ec9c5f`.
Runtime banner: CalculiX 2.23, executable made November 15, 2025.
This is an installed prebuilt package, not a locally compiled solver. The
packaging commit is not represented as the solver's exact source revision.
The package contains the upstream ccx_2.23.pdf manual and GPL material.
Its README warns that the Windows package is not fully tested/validated;
independent local tests below do not certify all solver features.
No binary is tracked or redistributed by this change.

## Implemented adapter subset

`core/cae/calculix_backend.gd` extends the existing backend contract. Canonical
input schema 1: SI coordinates, zero-based TET4 arrays, one isotropic E/nu,
static analysis, explicit [node,axis,value] constraints and concentrated loads.
Export maps to one-based C3D4, NALL/EALL, elastic solid section, BOUNDARY,
STATIC/CLOAD, NODE PRINT U/RF and EL PRINT S. Original array IDs map by +1.
Positive connectivity determinant is required; no silent node swaps.

DAT parsing reads actual nodal displacement and force records and one stress
integration point per C3D4. Order: xx,yy,zz,xy,xz,yz. Force records are retained
as printed nodal forces; they include loaded free DOFs and are not all support
reactions. No stress averaging or FRD nodal interpretation is performed.
Duplicate/missing displacement and stress mappings and nonfinite values reject.
Immutable directories and input/binary/DAT SHA-256 are retained.

Execution is synchronous verification only. Owned asynchronous monitoring,
timeouts, cancellation and atomic successful-result publication are **pending**.
Provenance is initial byte-integrity checking, not complete study stale-result
validation. The adapter is deliberately absent from the available registry.
Unsupported model properties and conflicting constraints still need broader
validation; do not use this subset as a production study exporter.

## Numerical evidence

Real jobs and parsed results: `evidence/calculix/run_*/`.
Summary: `evidence/calculix/numerical.json`.
One positive unit-axis tetrahedron, volume 1/6; E=1000 Pa, nu=.25.
Constraints permit the exact constant uniaxial strain field. Unit x load at
the axial vertex gives sigma_xx=F/V=6 Pa, ux=6/E=.006 m and lateral contraction
-.0015 m. Reported relative axial displacement error is zero at DAT precision.
Doubling E gives .003 m; doubling F gives .012 m and sigma_xx=12 Pa.
Changed input bytes reject on import. These are analytical element patch tests,
**not** the requested prismatic bar, cantilever convergence or Gmsh study tests.
Initial DAT parsing failed on uppercase exponent validation; normalization to
lowercase e corrected it and the real campaign passed. Failure artifacts remain.

## Remaining mandatory acceptance

Gmsh production geometry/mesh mapping, boundary/material identity, 931/932 count
investigation; bar/block/cantilever refinement; Extreme comparison and equilibrium;
robust job lifecycle/cancellation/failure recovery; capability-aware Workbench
selection, visualization/probes, save/reopen/stale-study rejection; screenshots
at both requested resolutions. No GUI evidence is claimed. Existing historical
Godot crash verdict is unchanged.

## Default regression attempt

All 28 existing manifest scripts were launched with a 120-second process bound;
each finished. Logs are retained under `evidence/calculix/regressions/`.
The PowerShell Start-Process collector returned null ExitCode values, so this
attempt **does not establish a passing regression suite**. Its process-results
and log-review records preserve that limitation rather than converting null to
success. Re-run with the existing Python regression runner and verify diagnostics
using its expected-error rules before assigning a regression PASS.
