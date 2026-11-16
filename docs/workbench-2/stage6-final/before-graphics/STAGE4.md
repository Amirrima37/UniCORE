# Stage 4 — cylinder geometry to TET4 FEM

## Scope and architecture

[Pre-change audit](STAGE4-AUDIT.md) was written before architecture edits. Stage 4 adds an independently validated cylinder path through the existing standalone CPU solver. The normal Godot solver adapters remain box-only: their regeneration and fixed per-body HEX8 loops were deliberately not rewritten. The workbench Solve action directs cylinder projects to Extreme CPU, where generation, launch, monitoring and result import are functional. This is a bounded geometry-to-FEM increment, not completion of normal-adapter cylinder integration.

No native solver formulation, tolerance, job grammar or material law changed. No third-party meshing dependency was added. Box meshing and normal solves retain their previous path.

## Meshing algorithm and validity

`core/cae/cylinder_mesher.gd` generates a polygonal approximation to a circular cylinder along local Y. Density d selects 8d circumferential sectors, d concentric radial rings and d axial intervals. The center fan and consistently divided annular quadrilaterals form the disk triangulation. Each extruded triangular prism is divided into three tetrahedra using sorted planar vertex IDs. Neighboring prisms therefore choose the same diagonal on their common quadrilateral; no duplicate seam or disconnected centerline is introduced.

Coordinates use scalar floating-point arrays. Dimensions, positive scale, position and YXZ Euler rotation match the existing primitive convention (R_y R_x R_z). X/Z radial scales must agree; elliptical sections are rejected. The path accepts cylinder-only documents, 1–16 disconnected bodies, density 1–8, and at most 10,000 nodes. HEX8 cylinder requests, mixed box/cylinder geometry, spheres and pipes are rejected explicitly. Cylinder gravity is blocked because the existing exporter gravity branch assumes structured HEX8 ownership.

For each tetrahedron, negative ordering is corrected by a node swap. Nonfinite determinants and determinants at or below 1e-24 m³ are rejected before publication. The mesh stores minimum determinant, edge aspect ratio, total volume, zero accepted inversions/degeneracies, ownership and generation duration. Existing inspection independently recomputes element quality and can show quality warnings: positivity is not a claim of optimal element shape, especially on inner rings and extreme aspect ratios. No adaptive sizing or industrial-quality general mesher is claimed.

The geometry is genuinely cylindrical/polyhedral volume, not a box replacement. Its boundary is faceted: circle approximation error is explicitly measured below. Display-surface tessellation remains separate and may be smoother than the FEM boundary.

## Physical boundary regions and export

Stable semantic IDs are `Bottom`, `Top` and `Lateral`, relative to local Y. End-cap groups contain their whole cross-section; lateral groups contain the outer radial ring at all layers. The document also stores `surface_regions` with actual exterior triangle connectivity, derived from generated cells rather than display-triangle IDs. Shared cap/lateral edge nodes may belong to both groups, but every exterior triangle belongs to exactly one physical region in the tests.

The existing exporter extracts topological exterior faces and resolves group membership against actual solver nodes. It already accepts TET4 connectivity and material-region ownership; no new numerical export format was necessary. Force, prescribed displacement, fixed support, cap pressure and existing thermal targets use these semantic groups. Total face forces remain area-weighted, and pressure follows actual facet normals. Circle end-cap pressure integrates over polygonal area, not an invented exact circular area. Arbitrary multiple structural load cases and deactivating persisted conditions remain outside scope.

Conditions can be created through the existing analysis dialog, which receives the correct region list. The viewport region selector and condition tree show the cylinder IDs; marker rendering uses actual mesh triangles after generation. Cylinder surface selection is semantic through the selector/tree, not persistent triangle picking. Body picking remains available. The mesh workspace disables cylinder HEX8, bounds density to 8 and identifies the Extreme CPU backend. Node/element statistics and inspection operate directly on the cylinder tetrahedra before and after solving.

## Analytical verification

`tests/test_cylinder_fem.gd` exports real standalone jobs and compares computed fields, rather than checking termination alone. Radius 0.2 m, length 1 m, E=1000 Pa, nu=0, axial resultant 1 N; bottom fixed. Nu=0 deliberately avoids clamped-end Poisson boundary layers, giving the exact affine axial solution for this fixture. The reference is u=FL/(EA), with A both the generated polygon area and the true circle area. One refinement uses rotated/translated geometry and global force components along the rotated cylinder axis. Another replaces force with end pressure chosen to give a unit resultant over the polygon.

Steady conduction uses k=10 W/(m K), bottom/top temperatures 300/400 K, insulated lateral faces (an exported zero-flux condition). The exact solution is linear in local axial position, with heat rate k A ΔT/L. Lateral boundary-face export is validated by native acceptance. Nonzero cylinder convection/radiation, transient cylinder restart and bending are not separately validated in this increment.

Acceptance: displacement versus polygon rod and heat rate versus polygon conduction each within 1e-5 relative; reaction/resultant balance within 1e-6 N; nodal temperature within 1e-5 K; volume versus polygon reference within 1e-12 m³; positive orientation for every tet; all exterior faces mapped exactly once. Circle errors must decrease with refinement. These tolerances are test comparisons, not modified solver tolerances.

|Density|Nodes|TET4|Circular displacement error|Circular heat-rate error|
|---:|---:|---:|---:|---:|
|1|18|24|11.0721%|9.9684%|
|2|99|288|2.6172%|2.5505%|
|3|292|1080|1.1515%|1.1384%|

All three support reactions are -1 N to within approximately 4e-14 N. Maximum nodal temperature errors are below 1.3e-9 K. The remaining circle error is dominated by polygon area, not a claim of general FEM convergence for arbitrary stress fields. This axial patch does not validate bending, stress concentrations or near-incompressibility.

Additional geometry cases cover lengths 0.05 and 2 m at densities 1,2,4 with three-axis rotation and translation. Unequal radial scaling is rejected. Unconstrained setup is rejected by document validation; the constrained axial solve and balanced reactions check constraint sanity. A separate eigenvalue/rigid-mode spectrum calculation was not added. [Raw numerical results](stage4-cylinder-numerical.json) retain precision and generation timings.

## Tests, screenshots and performance

The default regression manifest passed 28/28 with no script errors: [logs/results](stage4-regression/results.json). The [targeted validation](stage4-checks/results.json) reruns Stage 2 workbench, Stage 3 structural/thermal/radiation plus configured job/checkpoint/restart tests, cylinder numerical verification and graphical captures. Stage 3 checkpoint tests remain box fixtures; cylinder restart is not claimed by those passes. Existing native kernels/binaries were not rebuilt because no native source changed.

Actual Godot Vulkan framebuffer captures were opened and inspected:

- [Cylinder condition target at 1280 × 720](stage4-cylinder-1280.png)
- [Cylinder condition target at 1920 × 1080](stage4-cylinder-1920.png)
- [Prepared cylinder FEM surface and mesh statistics](stage4-cylinder-mesh.png)

The mesh screenshot shows 645 nodes, 2688 TET4, HEX8=0, inverted=0 and degenerate=0. Existing quality diagnostics report warnings; those are not hidden. Long tree labels ellipsize with tooltips. The initial mesh capture caught asynchronous preparation before completion; the capture now waits for preparation before saving. Graphical runs contain no script errors. Historical app-shell **0xC0000005 remains unresolved**, not suppressed, and is outside the default manifest. Headless compatibility tests retain documented dummy-renderer warnings.

Small-case generation timings are stored per run in the numerical JSON (approximately 1–65 ms for densities 1–3 on this host). These are single observations, not benchmarks or speedup claims. Generation is currently synchronous; largest allowed density and multi-body latency were not profiled. Existing mesh visualization preparation uses its background path. No large HPC campaign ran.

## Modified files and remaining geometry work

New: `core/cae/cylinder_mesher.gd`, `tests/test_cylinder_fem.gd`, `tests/capture_workbench4.gd`, the audit, this report and saved evidence. Extended: document dispatch/region validation, analysis-dialog region lists, workbench meshing/backend guidance/region markers. The existing exporter is reused without native changes.

Remaining: normal Godot adapter connectivity/ownership redesign and independent validation; mixed box/cylinder documents; robust generalized gravity export; nonzero curved-surface thermal/pressure reference cases; bending and broader Poisson ratios; large-aspect quality improvements; asynchronous generation; expanded high-density performance coverage; and physical mouse/keyboard workflow automation. Sphere, pipe, Boolean operations, general CAD solids and arbitrary curved-surface meshing remain unavailable.

Supplemental final geometry checks also compare the rotated axis against Godot's independent `Basis.from_euler` display basis (1e-6 vector tolerance, accounting for display float precision) and verify scaled polygon volume within 1e-10 relative for positive uniform radial / independent axial scaling. These checks pass. The initial cylinder test exposed one remaining spaced box-only support/load guard; it was corrected before the recorded numerical passes.
