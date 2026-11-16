# Latest Stage 6 status: FUNCTIONAL PASS — STABILIZATION BLOCKED

Checkpoint 5 functional verification is recorded in **Checkpoint 5 — Final Stabilization and Acceptance** below. Four native configurations, restart, numerical references, the default regression manifest and representative Vulkan workflows pass. The historical access violation remains **UNRESOLVED**; Stage 6 is not declared complete. This status supersedes the older status banners below, which remain historical evidence.

# Historical Stage 6 status: Checkpoint 4 PASS; Stage 6 remains PARTIAL

The final **Checkpoint 4 completion** section supersedes earlier PARTIAL integration reports. The sphere thermal cutaway remains deferred as permitted. Checkpoint 5 has not been started; historical crash stabilization is not claimed.

# Latest Stage 6 status: PARTIAL - Checkpoint 4 integration increment

Checkpoint 4 remains PARTIAL; see its final section for implemented changes, actual UI evidence and remaining coverage. No Checkpoint 5 work was started. Earlier progress sections remain historical evidence.

# Latest Stage 6 status: PARTIAL; Checkpoint 3 pipe implementation

See the Checkpoint 3 section below for current pipe scope and evidence. Earlier statements that pipe meshing is unavailable are historical and superseded there. Checkpoint 4 has not been started.

# Stage 6 status: PARTIAL; Checkpoints 1 and 2 passed

Latest: real single-sphere TET4 support is implemented and validated at densities 1-4. See **Checkpoint 2 - real sphere TET4 volume meshing** below for current scope, measurements, screenshots and limitations. Pipe and final stabilization remain pending. Earlier progress sections are retained as historical evidence; their statements that sphere meshing is unimplemented are superseded by Checkpoint 2.

# Stage 6 Р В Р вЂ Р В РІР‚С™Р Р†Р вЂљРЎСљ partial: cylinder checkpoint

Implemented and numerically validated the cylinder mesher improvement and an additional tetrahedral shape metric. Sphere, hollow pipe, their Workbench integration and their numerical/graphical acceptance remain **planned, not implemented**. This report does not certify the full milestone.

## Algorithm and resource bounds

The old disk had 8*d sectors on every ring. At d=4, R=0.1 m, the inner ring chord was 0.00490 m against 0.1 m axial spacing. Its central and inner-ring prisms necessarily produced stretched tetrahedra.

The replacement uses 8*r sectors on ring r, radius R*r/d. An integer angular zipper triangulates successive rings; the central fan has eight triangles. Sorted global disk IDs split each extruded triangular prism into three tetrahedra, consistently choosing shared quadrilateral diagonals. Negative connectivity orientation is corrected using FP64 determinants. The outer polygon is unchanged: 8*d regularly spaced vertices. Axial intervals are ceil(transformed length / transformed radial spacing), with at least one interval. Rotation and translation are applied after local construction.

Disk node count is 1+4*d*(d+1). Disk triangle count is 8*d*d; tetrahedra number 24*d*d*axial_intervals. Ordering is deterministic. Limits remain density 1Р В Р вЂ Р В РІР‚С™Р Р†Р вЂљРЎС™8, 1Р В Р вЂ Р В РІР‚С™Р Р†Р вЂљРЎС™16 bodies and 10,000 aggregate nodes; axial intervals also have a 10,000 pre-allocation bound. Slender configurations may now be rejected where the old poor-quality mesh fit. No automatic coarsening hides that limit. Very short cylinders can still have poor axial aspect ratios; universal quality guarantees are unsupported.

Public generate API, material ownership, TET4 format, Top/Bottom/Lateral semantics and outer polygon geometry are preserved. Backend identifier becomes graded_polygonal_cylinder_v2. IDs change on remeshing; existing provenance protects against reusing old results. Numerical kernels, solver tolerances, native grammar and checkpoint grammar were not edited.

## Metrics and measured comparison

New `mean_ratio` is q = 12*(3*abs(V))^(2/3) / sum(six squared edge lengths). A regular tetrahedron has q=1 and flattening tends to zero. Permutations leave this unsigned shape metric unchanged; signed determinant, signed volume and inversion remain separate. Independent regular and right tetrahedron fixtures test the formula and odd/even permutations. Calculations use the existing Vector3 display precision; this is not an FP64 quality evaluator.

`edge_ratio` explicitly aliases longest/shortest edge. Legacy `aspect_ratio` and vertex-0 `scaled_jacobian` remain compatible; the latter is ordering dependent. Warning thresholds remain unchanged, and mean ratio has no newly invented warning threshold. The existing UI still calls edge ratio aspect_ratio; new mean-ratio UI selection remains incomplete.

Reference: diameter 0.2 m, length 0.4 m, density 4.

|Measurement|Old|New|
|---|---:|---:|
|Nodes|645|1377|
|TET4|2688|6144|
|Edge ratio min|5.258|1.804|
|Edge ratio p25|7.058|1.894|
|Edge ratio median|10.540|1.945|
|Edge ratio p75|21.033|1.989|
|Edge ratio max|21.080|2.003|
|Edge ratio >5|2688|0|
|Vertex-0 scaled Jacobian min|0.01148|0.29098|
|Vertex-0 scaled Jacobian median|0.18117|0.42147|
|Inverted/degenerate/nonfinite|0|0|

New mean ratio minimum 0.70012, median 0.75805. Node growth 2.13x and element growth 2.29x are explicit costs. [Distribution evidence](stage6-cylinder-quality.json); historical [old evidence](stage5-cylinder-quality.json) is preserved. New tests check exact repeated nodes/connectivity/regions/ownership, unique tetrahedra, positive FP64 volume, face multiplicities one or two, exclusive exterior-region coverage and use of every node. A separate graph traversal for connectedness remains outstanding; construction uses a connected disk extruded through shared layers.

## Numerical references and regressions

Existing cylinder FEM checks pass at densities 1, 2, 3, including rotation/translation, scaled short/slender geometry, pressure, structural export/import and thermal export/import. Axial structural fixture uses nu=0: displacement F*L/(E*A_polygon). Reactions sum to -1 N within approximately 3.1e-12 N. Circle displacement relative errors decrease 11.072%, 2.617%, 1.152%; these are polygon geometry errors for this exactly representable axial field, not evidence of arbitrary structural convergence.

Thermal reference uses prescribed end temperatures and insulated lateral wall: T linear along the axis, heat rate k*A_polygon*deltaT/L. Maximum nodal temperature error is below 2.5e-8 K. Circle heat-rate errors decrease 9.968%, 2.550%, 1.138%. Reference-cylinder polygon volume error at density 4 remains 1-sin(pi/16)/(pi/16), about 0.6413%. Meshing does not change the exterior polygon approximation. Detailed refreshed numerical rows are in stage4-cylinder-numerical.json.

Default manifest **28/28 passed**, including native structural, thermal, radiation, Extreme equivalence and advanced workflows: [results](stage6-regression/results.json). Focused **9/9 passed**: topology/quality/repeatability, cylinder analytical FEM, Stage 5 quality/provenance/display/probes, Stage 5.1 cache/equivalence, and app shell: [results](stage6-checks/results.json). App shell exits 0 after 91 assertions. No new checkpoint/restart-specific invocation was made. Focused analytical meshing times were approximately 8/97/210 ms at density 1/2/3, single runs, not a performance benchmark. No HPC campaign ran.

## Graphical inspection

Actual Vulkan Godot captures: [1280x720](stage6-cylinder-quality-1280.png), [1920x1080](stage6-cylinder-quality-1920.png). Both were opened and inspected. Generated exterior triangles and quality colors are visible without evident holes or panel overlap. Legend lower entries require inspector scrolling; the cylinder occupies a small viewport area and existing text encoding artifacts remain. Initial premature blank captures were replaced after explicitly waiting for asynchronous mesh inspection preparation. Captures are mesh inspection only, not claimed as solved result evidence.

## Checkpoint status and remaining work

Checkpoint 1: mesher and numerical checks passed; independent shape metric implemented. Remaining acceptance refinements include mean-ratio UI integration, a separate connected-component traversal, old/new mean-ratio distributions, more exhaustive invalid/nonfinite transform tests and dedicated remesh condition-persistence checks. Graphical evidence has the limitations above.

Checkpoints 2Р В Р вЂ Р В РІР‚С™Р Р†Р вЂљРЎС™5: incomplete. No sphere or annular pipe TET4 implementation or numerical validation is claimed. No arbitrary CAD/Boolean solids, adaptive FEM, contact, nonlinear materials, fluid meshing or CFD is added. Existing normal-adapter limitations and Extreme routing remain in force. Stage 6 is **partial**.


## Checkpoint 1 continuation ? quality integration and independent topology

Implemented: Mesh inspection now offers explicit longest/shortest edge ratio and TET4 mean ratio; labels identify the ordering-dependent vertex-0 scaled Jacobian. Signed volume and determinant retain separate meanings. Finite-only min/max/mean/median, missing counts and five equal-width distribution bins appear in the quality legend. Existing warning counts and thresholds are unchanged; mean ratio has no invented cutoff. HEX8 mean ratio is unavailable and appears as missing. Nonfinite quality records expose both new metric keys, preserving missing-data rendering.

The cylinder generator rejects nonfinite and malformed position, rotation and scale before allocation. Existing zero/negative scale and unequal radial-scale rejection remains. The accepted meshing algorithm itself is unchanged.

Independent topology traversal now checks face-sharing connectedness, opposite shared-face winding, multiplicity one/two, unique exterior coverage, positive FP64 determinants, no unused nodes, no duplicate cells and material ownership. Rotated/translated density 1?8 meshes pass with exactly repeated nodes, cells and region arrays. Density 8 fits the existing limit at 9,537 nodes and 49,152 TET4; it is not a limit violation. [Per-density measurements](stage6-topology.json). Invalid tests cover NaN and both infinities in each transform, malformed transform vectors, zero/negative/unequal radial scales, zero/negative/nonfinite/tiny/huge lengths. Extremely slender input is rejected by subdivision/node bounds; extremely small volumes are rejected by the existing determinant floor. Very short but nondegenerate geometry can still produce quality warnings.

A real exported structural result is accepted before editing. Radius, length, rotation, translation and density edits each change the mesh, preserve Bottom support/Top pressure and both end-temperature conditions, rebuild real face mappings, and reject importing the old result. This verifies semantic assignments rather than preserving obsolete node numbers. Existing provenance and probe fixtures also pass. The structural and thermal analytical cylinder references were rerun unchanged.

### Bounded before/after performance

The test-only legacy fixture reconstructs the documented Stage 4 disk/extrusion algorithm. It reproduces historical density-4 node/element counts and edge distribution exactly to the displayed precision. Production does not route through this fixture. One process runs legacy then graded at densities 2 and 4, with one structural and one thermal job each, sequentially, one solver thread, 256 MB configured budget. Material: E=1000 Pa, nu=0, k=10 W/(m K), density=cp=1. Radius=0.1 m, length=0.4 m. This is a small axial benchmark, not a broad performance claim. [Measured output](stage6-cylinder-performance.json).

|Mesher / density|Nodes / TET4|Generation ms|Structural export+launch ms / native solve ms|Thermal export+launch ms / native solve ms|
|---|---:|---:|---:|---:|
|legacy / 2|99 / 288|19.135|90.440 / 11.3038|104.870 / 0.5827|
|legacy / 4|645 / 2688|154.360|396.189 / 91.0224|349.526 / 6.0861|
|graded / 2|225 / 768|46.602|139.841 / 13.8670|145.098 / 1.8350|
|graded / 4|1377 / 6144|320.283|951.611 / 176.4033|996.866 / 13.5875|

Density-4 old/new mean-ratio min: 0.095307 / 0.700121; median: 0.195564 / 0.758051. This independently demonstrates lower-tail shape improvement. The latest legacy generation measurement is 154.360 ms (supersedes the approximate intermediate progress update). All eight benchmark jobs imported with valid provenance. Native relative residuals are retained in the JSON; no solver tolerance was changed. Export+launch includes snapshot/provenance serialization and process startup, not pure file-write time. End-to-end export/solve/poll times are separately retained.

Memory: Godot tracked static memory and process-cumulative static peak are measured, not Windows working-set or native-solver peak. The graded density-4 retained delta was 1,998,816 bytes and cumulative static peak 35,332,884 bytes. Previous cases, source loads and allocator release affect these values; one negative retained delta illustrates why they must not be interpreted as per-mesher peak memory or proof of memory neutrality. No native working-set comparison is claimed.

### Failures retained and reliability limits

The initial topology run exceeded a 120-second bound and was stopped. A diagnostic rerun timed out at 60 seconds after densities 1?7 had passed: the test incorrectly expected density 8 rejection. Correcting that expectation produced a clean full sweep. Those attempts remain failures, not passes. The first benchmark timed out after a failed assertion; a diagnostic rerun exited 1 and identified a material record without k. The final benchmark uses explicit structural/thermal material properties and exits cleanly. [Failed diagnostic logs](stage6-completion-checks/topology.log), [material validation failure](stage6-completion-checks/performance-final.log), [successful benchmark](stage6-completion-checks/benchmark_stage6_cylinder-verified.log). No failure evidence or crash dump was deleted.

Actual mean-ratio screenshots were recaptured and opened at both requested sizes using the existing cylinder screenshot links above. The mesh is framed larger, summaries/distributions are visible and controls do not overlap. Full legend/palette/warning explanations require inspector scrolling. Existing encoding artifacts remain. No solved sphere/pipe screenshot is claimed.

Historical 0xC0000005 remains an unresolved reliability concern outside this checkpoint. The earlier listener correction is preserved; no speculative lifetime/native fix was introduced. Clean app-shell runs here do not establish that the reported subsequent matching-offset crashes are fixed. No new dump stack, instruction comparison or symbolized mapping was obtained in this continuation. That investigation remains mandatory before a stabilized Stage 6 verdict.

Production files changed in this continuation: cylinder_mesher.gd, mesh_display.gd, mesh_inspection.gd and cae_workspace.gd. Tests: expanded test_stage6_cylinder.gd, new test_stage6_topology.gd, test_stage6_remesh.gd, benchmark_stage6_cylinder.gd and test-only fixtures/stage6_cylinder_v1.gd; updated capture_stage6_cylinder.gd. Unrelated working-tree edits remain in place. No native source/build changes were required; Release/Debug/no-OpenMP builds and checkpoint/restart-specific reruns remain pending Checkpoint 5.


### Checkpoint 1 verdict

**PASS for the cylinder checkpoint; Stage 6 overall PARTIAL.** Final default manifest: **28/28**, clean process exits and no script errors: [results](stage6-completion-regression/results.json). Focused scripts: **10/10**; benchmark: **8/8 sequential structural/thermal jobs**; graphical capture: **1/1** process producing two inspected images. App-shell baseline plus two additional repetitions: **3/3** clean exits, 91 assertions each, 9.440 / 11.646 / 10.048 seconds. [Consolidated checkpoint evidence](stage6-completion-checks/checkpoint1-summary.json). The final topology sweep took 30.150 seconds; all density 1?8 cases passed. The comparison is bounded and retains all failed attempts described above.

Remaining checkpoints 2?5 are not complete. Sphere/pipe meshing and FEM validation, their complete Workbench integration, persistence evidence, native build matrix and the renewed historical crash investigation remain pending. This continuation is delivered at the requested incremental checkpoint boundary; it is not a Stage 6 completion or release-readiness claim.


## Checkpoint 2 - real sphere TET4 volume meshing

**PASS within the bounded scope below. Stage 6 remains PARTIAL. Checkpoint 3 was not started.** This section supersedes earlier statements that sphere meshing was unimplemented. The accepted cylinder mesher and quality calculations were not edited in this checkpoint.

### Implemented architecture and scope

`sphere_mesher.gd` maps a structured grid in [-1,1]^3 into a ball. For local cube coordinates x,y,z, X=R*x*sqrt(1-y*y/2-z*z/2+y*y*z*z/3), with cyclic expressions for Y and Z. Every cube boundary maps to radius R. A shared global grid and the existing six-tetrahedron cube-diagonal split give conforming volume connectivity. This is a volume mesh with interior nodes, not a surface fan or display primitive. Scalar FP64 arrays hold coordinates and determinants. Negative order is corrected; nonfinite determinants or determinants <=1e-24 m^3 reject the entire mesh. Positive signed volumes remain separately checked by tests.

Supported: one sphere, one isotropic material, radius, translation, Euler rotation and positive uniform scale. Local axes rotate with the part. Nonuniform/zero/negative/nonfinite scaling, malformed transforms, invalid radii, mixed/multiple bodies and HEX8 are rejected. Sphere density is explicitly limited to **1-4**, with n=2*d intervals per cube axis: (n+1)^3 nodes and 6*n^3 TET4. Maximum supported size is 729 nodes / 3072 elements, estimated before allocation; no adaptive loops or recursion. Higher densities are deliberately unsupported pending corner-quality improvements. This is not an industrial general sphere mesher or a universal quality guarantee.

Workbench Sphere creation now supplies a radius rather than the pre-existing invalid length parameter. Parameter/material editing, mesh generation, quality inspection, real region markers and Extreme routing use existing components. Normal Godot adapters remain box-only. The Mesh workspace disables sphere HEX8 and bounds density to four. The analysis dialog and condition catalog add **Sphere uniform expansion**, stored as a prescribed OuterSurface displacement with `radial_strain`. The exporter computes u_j=strain*(x_j-center_j) on actual exterior nodes, then writes ordinary prescribed DOFs using the unchanged job grammar. The dedicated strain control uses a small numeric range and fine step to avoid loss of small values in the generic large-range SpinBox. Condition editing, removal, persistence, undo and redo use the existing document architecture.

No native kernel, solver tolerance, ABI, job/checkpoint grammar or cylinder algorithm was changed. No new retained anonymous subscription was introduced.

### Surface semantics and ownership

OuterSurface contains every topological exterior triangle and only exterior nodes. PositiveY / NegativeY are local axial hemispheres, selected by the sign of the sum of local grid y coordinates over each exterior face. The grid contains the equator, so no triangle straddles it. Hemisphere faces partition OuterSurface; equatorial nodes are shared. OuterSurface is intentionally their parent, so assigning both parent and child loads can double-load faces; conflicting prescribed temperatures are rejected by the existing exporter. Conditions are semantic, not hardcoded node IDs. Rotation preserves local hemisphere identity.

Tests independently check positive determinants, outward exterior normals, face multiplicities one/two, opposite shared-face winding, connected-component traversal, unique tetrahedra, no unused nodes, material ownership, complete exterior coverage and exact repeated node/connectivity/region ordering. Membership-based exporter resolution is compared against explicit semantic triangle sets. Uniform scale and rigid transformations are tested, including a rotated/translated numerical case at density 2. Bounds follow the mapped coordinates; exterior node radii are independently checked under scale/rotation/translation. [Contract evidence](stage6-sphere-checks/test_stage6_sphere_contract-verified.log).

### Geometry and numerical references

Radius R=0.1 m. Geometry references are V=4*pi*R^3/3 and A=4*pi*R^2, compared with summed signed tetrahedral volumes and triangle areas. Pressure integration uses actual outward triangle area vectors: a closed surface at 1 Pa has approximately zero resultant. These geometric errors are distinct from solving the FEM equations on the polyhedron.

Structural: E=1000 Pa, nu=0.25, imposed uniform expansion strain epsilon=0.001 on OuterSurface. Exact field u=epsilon*(x-center), normal stresses E*epsilon/(1-2*nu)=2 Pa, zero shear. This full displacement boundary eliminates all rigid modes while retaining interior unknowns. It tests affine reproduction, not arbitrary load convergence. Maximum displacement component error across the density sweep is below 1.55e-13 m; maximum stress component error is below 6.61e-9 Pa. Structural residuals are below 7.08e-11 and total reaction components below 1.1e-13 N.

Thermal: k=10 W/(m K), uniform source q=6000 W/m^3 and OuterSurface T=300 K. Smooth-sphere references are T(r)=300+q*(R^2-r^2)/(6*k), conductive flux vector q*(x-center)/3 and outward heat q*V. Boundary nodes lie on the sphere but planar facet interiors do not: temperature errors below combine boundary geometry approximation and discretization error, which are not separately quantified. Heat reactions balance the **polyhedral** source volume. The flux measure is volume-weighted error sampled at tetrahedron centroids relative to the analytical flux at those centroids; it is not an exactly integrated continuum L2 norm.

|Density|Nodes / TET4|Volume error %|Area error %|Max temperature error K|Centroid flux relative RMS|Mean ratio min / median|Generation ms|
|---|---:|---:|---:|---:|---:|---:|---:|
|1|27 / 48|23.35870|12.02150|0.18589914|0.707305|0.493390 / 0.790953|1.533|
|2|125 / 384|6.50558|3.24389|0.06075615|0.383996|0.272382 / 0.711574|17.521|
|3|343 / 1296|2.95343|1.46468|0.02915168|0.264112|0.183813 / 0.693853|42.643|
|4|729 / 3072|1.67399|0.82868|0.01704612|0.201381|0.136107 / 0.684098|109.289|

[Full measured outputs](stage6-sphere-numerical.json). Thermal energy relative errors are below 1.25e-13; residuals below 2.59e-11. At density 4 heat reaction is -24.71202244 W, balancing source heat in the faceted solid. The maximum component flux error is 120.71 / 187.56 / 145.99 / 146.07 W/m^2 across densities 1-4: it is **not monotonic**. Local corner gradients remain inaccurate even as temperature and centroid-weighted flux measures improve. Do not use this validation to claim accurate pointwise surface flux or stress-concentration predictions.

An additional real pressure solve uses a rotated/translated, uniformly scaled sphere, 1 Pa inward pressure on OuterSurface and NegativeY clamped. It produces finite displacement (maximum 2.16113214e-4 m), FP64 reaction resultant norm 6.94e-11 N, residual 8.45e-11. This constrained case is not compared to a free hydrostatic sphere solution. [Pressure evidence](stage6-sphere-pressure.json).

At density 4 the maximum edge ratio is 4.96754 and no element exceeds five. Minimum mean ratio is 0.136107, median 0.684098. There are **516 legacy quality warnings among 3072 elements**, retained unchanged; corner distortion is a real limitation. No mean-ratio threshold was invented or warning suppressed. Center cells avoid the central-fan degeneration, but mapped cube corners get worse as density increases. No claim of uniformly high mesh quality is made.

Generation timings in the table are single observations, not a benchmark or speedup claim. No sphere peak-memory measurement was made; explicit node/element limits bound allocations. Numerical validation runs one native job at a time, one thread, 256 MB configured budget, with 15-second per-job polling limits and outer subprocess timeouts.

### Integration, provenance and verification

Four structural and four thermal reference solves use the normal document -> mesh -> native export -> Extreme solve -> verified import chain. A separate pressure solve and two graphical solves exercise the same backend. Project save/reopen preserves the structural sphere and accepts its matching result. Radius edits reject old results; undo restores matching provenance, redo rejects again. Exact repeated mesh arrays are verified without comparing nondeterministic generation timing metadata. Existing provenance, cache and probe regression scripts pass. Sphere-specific remeshing of every possible condition and interactive picking at every deformation scale remain broader Checkpoint 4 work.

Focused final coverage: 10 distinct test scripts passed, plus one successful graphical script. Full default manifest **28/28 passed**. App shell: **91 assertions, exit 0**, 11.504 seconds in this checkpoint. [Focused logs](stage6-sphere-checks/focused-results.json), [final checks](stage6-sphere-checks/final-results.json), [latest numerical/contract checks](stage6-sphere-checks/verified-results.json), [default regressions](stage6-sphere-regression/results.json), [consolidated evidence](stage6-sphere-checks/checkpoint2-summary.json). Existing headless dummy-renderer diagnostics remain; clean exit is not a claim that those logs contain no diagnostics.

Failed graphical attempts are retained. They stopped after the rejected Sphere creation left no selected body; reading the persistent Godot engine log identified the invalid Nil dialog access. The first diagnostic source instrumentation attempt also failed to instantiate the temporarily instrumented script; production source was restored byte-for-byte in finally. No such instrumentation remains. The final fixture verifies creation, dialog fields, exact strain entry, markers and both real solve/render paths. An earlier capture reused a previous-sized framebuffer; the fixture now forces a draw and asserts each saved image's dimensions. Intermediate strain snapping was also caught and corrected before final capture. These attempts are not counted as successful runs or evidence of a repaired historical native crash.

### Graphical evidence and limitations

All ten final Vulkan screenshots were opened and inspected. They show actual generated volume-mesh boundaries and imported native fields. Sphere framing is enlarged, region markers follow the local hemisphere, legends show physical units and panels do not overlap. The viewport legend partially overlays the model at this framing; the inspector scrolls. Existing encoding artifacts persist. Thermal extrema labels remain visible through the surface and are close together; temperature surface coloring is correctly uniform 300 K because all exterior nodes are prescribed. The hotter interior is validated numerically, not painted onto the exterior. No interior thermal section renderer was added. Lower-rim purple/magenta-looking pixels in the flux capture are retained as a visual limitation; no nonfinite solver flux was accepted by the importer, and no numerical data was altered to hide them.

|View|1280 x 720|1920 x 1080|
|---|---|---|
|mesh|[image](stage6-sphere-mesh-1280.png)|[image](stage6-sphere-mesh-1920.png)|
|hemisphere|[image](stage6-sphere-hemisphere-1280.png)|[image](stage6-sphere-hemisphere-1920.png)|
|displacement|[image](stage6-sphere-displacement-1280.png)|[image](stage6-sphere-displacement-1920.png)|
|temperature|[image](stage6-sphere-temperature-1280.png)|[image](stage6-sphere-temperature-1920.png)|
|heat_flux|[image](stage6-sphere-heat_flux-1280.png)|[image](stage6-sphere-heat_flux-1920.png)|

Changed production files: new core/cae/sphere_mesher.gd; extended cae_document.gd, extreme_jobs.gd, condition_catalog.gd, ui/cae/cae_workspace.gd and analysis_editor.gd. New tests: test_stage6_sphere.gd, test_stage6_sphere_contract.gd, test_stage6_sphere_dialog.gd and capture_stage6_sphere.gd. Unrelated working-tree edits were preserved.

Implemented/validated: bounded single-sphere geometry, semantic surfaces, structural expansion reference, steady thermal source reference, constrained pressure workflow, basic project/undo/provenance and actual visualization. Partially validated: local flux accuracy and complete sphere-specific interaction coverage. Unsupported: ellipsoids, multiple/mixed spheres, arbitrary affine transforms, higher densities, contact, Boolean solids and CFD. Transient sphere checkpoint/restart and new Release/Debug/no-OpenMP build matrix were not tested here; no compatibility claim is added. Historical Godot access-violation investigation remains unresolved; this clean app-shell run does not establish a universal fix. Pipe implementation and final Stage 6 stabilization remain pending.


## Checkpoint 3 - annular pipe TET4 volume mesh

Implemented: one disconnected pipe wall with inner/outer radii (also diameter and wall-thickness editing), length, density, material, translation, Euler rotation and positive equal radial X/Z scaling. Positive axial scaling is supported. Native numerical kernels, tolerances, job/checkpoint formats and accepted cylinder/sphere meshers are unchanged. New pipe code uses shared FP64 arithmetic and the same conforming sorted-vertex prism split. The Workbench now creates, edits, meshes, selects semantic regions and routes pipe solves through Extreme CPU. Box-only normal adapters are not used for pipes. Mixed/multiple bodies, elliptical sections, gravity export and CFD are unsupported.

### Algorithm, bore and bounds

The annular cross-section has d radial intervals and N circumferential sectors. N=max(16*d,16*ceil(2*pi*Ro*d/((Ro-Ri)*16))). Axial intervals are max(1,ceil(transformed length / transformed radial spacing)). All rings use the same angular stations; each annular quadrilateral is split into two triangles, then extruded and split into three conforming tetrahedra. Unique array-index nodes and global planar vertex ordering avoid seam duplicates and mismatched prism diagonals. Negative ordering is corrected using signed determinants; nonfinite or <=1e-24 m^3 determinants reject generation.

Node estimate=(d+1)*N*(axial+1); TET4 estimate=6*d*N*axial. Density is 1-8, one pipe only, at most 10,000 nodes and 50,000 tetrahedra. Angular and axial requests are bounded before integer conversion/allocation. Excessive thin/long configurations reject explicitly; there is no silent coarsening. Inputs require finite dimensions/transforms, positive scale and 0<Ri<Ro.

The bore is an empty **regular polygonal prism**, approximating a circular bore. Its inner chord lies at Ri*cos(pi/N), so its facets do not coincide with the ideal circular surface between vertices. An independent half-plane test checks every tetrahedron's projected vertices against its sector's inner chord. Convexity then excludes the whole tetrahedron from the polygonal bore, rather than checking centroids alone. No core elements or hidden structural fill are generated.

### Regions and pressure direction

InnerWall and OuterWall are the innermost/outermost rings along all layers; InletEnd is local Y=-L/2 and OutletEnd local Y=+L/2. Every exterior face belongs to exactly one region; shared edge nodes may belong to two. Triangle lists come from actual TET4 exterior topology. Inner normals point into the bore, outer normals away from the axis, end normals along -/+ the transformed local axis. Tests independently verify these signs and polygon reference areas.

A necessary pipe-specific exporter correction preserves TET4 exterior winding: the existing center-dot-normal heuristic would reverse the inner wall. It is bypassed only for Pipe. Positive pressure acts as -p*n_material, therefore pushes the inner wall away from the bore. A real inner-pressure solve confirms positive radial expansion and balanced reactions. This change does not alter cylinder/sphere pressure handling.

### Topology, invalid input and determinism

Tests perform face-sharing connected-component traversal, face multiplicity one/two, opposite interior winding, exterior uniqueness/coverage, no unused nodes or duplicate tetrahedra, positive signed volumes, material ownership, exact repeated arrays and geometric bounds through the bore half-plane checks. A rotated/translated density-2 case validates coordinate transforms against Godot's independent Basis. Thin and thick meshes run through the same topology checks. Invalid/nonfinite inner dimensions and nonfinite transform components reject; additional mesher guards cover nonpositive length, radial scaling and resource limits. Not every malformed serialized input combination was separately fuzz-tested.

The pressure project is saved/reopened with matching native-result provenance accepted. Changing the inner radius remeshes, preserves InnerWall pressure assignment and rejects the old result. No stale node IDs are substituted. Full persistence/interaction coverage remains Checkpoint 4 work.

### Structural reference

To avoid comparing a clamped short pipe to an incompatible infinite-cylinder Lam? reference, the analytical structural benchmark is axial extension with E=1000 Pa, nu=0, L=0.1 m, Ri=0.05 m, Ro=0.1 m. InletEnd is fixed; OutletEnd carries a 1 N axial resultant (density 4 uses equivalent end pressure). The exact linear-elastic field has u_out=F*L/(E*A_polygon) and axial stress F/A_polygon. Nu=0 avoids an inlet Poisson boundary layer. Displacement and projected element stress are checked, including rotated loading. This is not a Lam?/radial-stress-distribution validation.

Maximum measured relative displacement error versus polygon reference is below 3.63e-13; axial stress error below 4.11e-8 Pa; axial reaction mismatch below 1.26e-11 N. The pressure workflow separately uses Ri=0.05, Ro=0.1, L=0.04, E=1000, nu=0, clamped InletEnd and 1 Pa on InnerWall. Sum of outlet radial position dot displacement is positive (1.74381885e-4 m^2), reaction resultant norm 7.52e-11 N and relative residual 9.35e-11. It validates load direction and equilibrium, not the unconstrained Lam? solution.

### Radial thermal reference

Ri/Ro/L as in the axial benchmark, constant k=10 W/(m K), inner wall 400 K, outer wall 300 K, and **insulated end faces** (zero flux). Thus the smooth circular finite pipe has the exact axial-invariant reference T(r)=300+100*ln(Ro/r)/ln(Ro/Ri), q_r=1000/(r*ln(2)), Q=2*pi*k*L*100/ln(2). This does not assume an arbitrary short pipe behaves like an infinite pipe: its insulated ends make this reference consistent. Polygonal surface approximation and TET4 discretization both contribute to errors.

Native heat reactions are positive on the hot inner wall (power entering material), negative on the outer wall; their sum checks energy conservation. Every element's conductive flux has positive dot product with its radial position. The centroid flux metric below is an unweighted RMS of component errors relative to analytical centroid flux, not an exactly integrated L2 error. Density 1 has no free radial temperature nodes: its zero nodal temperature error is only boundary reproduction. The density 2-to-4 interior error decreases.

|Density|Nodes / TET4|Volume error %|Max temperature error K|Heat-rate error %|Centroid flux relative RMS|Mean ratio min / median|Generation ms|Native structural / thermal solve ms|
|---|---:|---:|---:|---:|---:|---:|---:|---:|
|1|96 / 192|2.550464|0.000000|5.329159|0.164023|0.503526 / 0.716583|15.903|2.6501 / 0.6341|
|2|480 / 1536|0.641315|0.834319|1.407852|0.085273|0.519592 / 0.677502|79.952|29.8947 / 1.8117|
|4|2880 / 12288|0.160561|0.266562|0.359212|0.043460|0.526362 / 0.671866|764.027|328.9840 / 13.3979|

[Full numerical measurements](stage6-pipe-numerical.json). Density-4 hot-wall input is 909.728184 W; smooth-cylinder reference approximately 906.472028 W. Absolute energy imbalance is below 8.29e-11 W; structural residuals below 8.85e-11 and thermal residuals below 8.08e-11. Temperature endpoints are imposed exactly. Volume and annular end areas have relative error 1-sin(2*pi/N)/(2*pi/N), falling 2.55046% -> 0.641315% -> 0.160561%. Inner/outer lateral areas have relative error 1-sin(pi/N)/(pi/N), falling approximately 0.641315% -> 0.160561% -> 0.040155%. Independently summed face areas and normal signs are checked against polygon formulas, not display surfaces.

### Thin-wall quality and resource constraints

All following contract cases have Ro=0.1 m and L=0.04 m. No quality thresholds were changed.

|Ri|Density|Nodes / TET4|Mean ratio min / median|Maximum edge ratio|Legacy warnings|Generation ms|
|---|---:|---:|---:|---:|---:|---:|
|0.05|1|64 / 96|0.513956 / 0.737914|3.573849|0|6.204|
|0.05|2|288 / 768|0.532306 / 0.679021|3.488396|0|48.869|
|0.05|4|1600 / 6144|0.540269 / 0.686838|3.448655|0|367.880|
|0.09|1|640 / 1536|0.675494 / 0.761704|1.917022|0|92.377|
|0.09|2|3456 / 12288|0.681649 / 0.755669|1.902071|0|868.864|
|0.09|4|Rejected: resource limit|-|-|-|-|
|0.099|1|Rejected: resource limit|-|-|-|-|
|0.099|2|Rejected: resource limit|-|-|-|-|
|0.099|4|Rejected: resource limit|-|-|-|-|

[Contract and pressure evidence](stage6-pipe-contract.json). Initial fixed-sector experiments admitted Ri/Ro=0.99 meshes with mean ratio as low as 0.01416, edge ratio 39.22 and all elements warned. Those poor results are retained in [initial evidence](stage6-pipe-contract-first.json). Thickness-aware angular sizing now rejects these test cases under the node bound instead of returning that poor mesh. Ri/Ro=0.9 remains supported at densities 1/2 with good measured quality; density 4 exceeds the node limit. Arbitrarily thin pipe walls are **not supported within these bounds**. No universal quality guarantee is claimed for all lengths, radius ratios or extreme scaling.

Timings are single measurements, not a comparative benchmark. Jobs use one thread and a 256 MB configured solver budget, with explicit outer subprocess timeouts and 15-second polling deadlines. Peak working-set memory and export-only time were not measured. No native build or HPC campaign ran. No new checkpoint/restart compatibility claim is made.

### Workbench, screenshots and failures

Creation, radius/diameter/wall/length editing, materials, four region selectors, conditions, mesh quality and automatic Extreme CPU routing reuse the current UI. Real structural and thermal native results are imported with existing provenance and finite-field checks and rendered without fabricated arrays. The dedicated screenshots show quality, the open bore, InnerWall selection, true-scale displacement, temperature and element conductive flux. Marker depth testing is disabled as in existing semantic markers, so the selected inner region remains visible through the near outer wall.

Ten images at exactly 1280x720 / 1920x1080 were opened and inspected. Mesh and result views have no panel overlap; legends can overlay the model and inspector details require scrolling. Existing character-encoding artifacts and saturated purple colors remain. Initial structural captures were cropped by scale 100; they were replaced by physical scale 1 captures and reinspected. The bore is clear in the mesh view; far inner-wall surfaces can project into the apparent opening in result views, so topology checks rather than a single projected image establish hollowness. No synthetic smoothing or fake field data was added.

|View|1280 x 720|1920 x 1080|
|---|---|---|
|mesh|[image](stage6-pipe-mesh-1280.png)|[image](stage6-pipe-mesh-1920.png)|
|inner_wall|[image](stage6-pipe-inner_wall-1280.png)|[image](stage6-pipe-inner_wall-1920.png)|
|displacement|[image](stage6-pipe-displacement-1280.png)|[image](stage6-pipe-displacement-1920.png)|
|temperature|[image](stage6-pipe-temperature-1280.png)|[image](stage6-pipe-temperature-1920.png)|
|heat_flux|[image](stage6-pipe-heat_flux-1280.png)|[image](stage6-pipe-heat_flux-1920.png)|

A test-only GDScript type-inference parse error in the first thin-wall contract test exited 1; it was corrected with an explicit float annotation. [Failed log](stage6-pipe-checks/test_stage6_pipe_contract.log) is preserved. Failed/poor-quality experiments are not counted as passing final tests. Final pressure/bore/resource/persistence contract exits 0. Both accepted cylinder and sphere focused tests, provenance/cache tests and two app-shell runs pass. App shell prints 91 assertions and exits 0 in 8.577 / 8.396 seconds; this does not establish a fix for the historical native access violation.

Production files: new core/cae/pipe_mesher.gd; narrow extensions to cae_document.gd, extreme_jobs.gd and ui/cae/cae_workspace.gd. Tests: test_stage6_pipe.gd, test_stage6_pipe_contract.gd, pipe_topology_fixture.gd and capture_stage6_pipe.gd. Existing cylinder/sphere meshers, FEM kernels and job grammar were preserved, as were unrelated working-tree changes.

Known remaining work: Lam?-compatible radial stress/displacement benchmark, wider thin-wall/length study, outer-wall pressure reference, separately verified convection/radiation, exhaustive input/persistence/picking cases, native build matrix and historical crash investigation. The pipe is a linear structural/thermal solid wall, not a fluid volume. Checkpoint 4 is not started; Stage 6 is not declared complete or release-ready.


### Checkpoint 3 verdict

**PASS for the bounded single-pipe implementation and references above; Stage 6 remains PARTIAL.** Default regression manifest **28/28** passed: [results](stage6-pipe-regression/results.json). Focused scripts **7/7** passed (pipe numerical, pipe contract, sphere numerical, cylinder quality, provenance, Stage 5.1 cache and app shell), plus one graphical script producing ten dimension-checked inspected screenshots. Two bounded app-shell runs exit 0 with 91 assertions each. [Consolidated evidence](stage6-pipe-checks/checkpoint3-summary.json). Independent FP64 Python recalculation also verifies both recorded annular end areas at each density against the polygon formula (relative tolerance 1e-10); area convergence is recorded in the summary. The earlier test parse failure and poor fixed-sector thin-wall evidence remain preserved, not included in final pass counts.

Checkpoint 4 was not started. Independent review of this checkpoint is required before expanding scope. The accepted cylinder/sphere algorithms, native kernels and input grammar remain intact; the historical crash remains unresolved and no release-readiness claim is made.


## Checkpoint 4 - Workbench integration increment (PARTIAL)

The accepted meshers, geometry bounds, quality thresholds, solver kernels/tolerances, input formats and provenance algorithms were preserved. This increment closes a condition-conflict gap and verifies real Workbench launch/import actions. It does **not** certify every requested interactive operation.

### Implemented changes

New `core/cae/condition_conflicts.gd` rejects ambiguous sphere pressure/force overlap on the same surface or parent/child patches. PositiveY and NegativeY remain disjoint face-load targets (their shared equatorial nodes do not make their triangles overlap). Sphere thermal parent/child combinations reject rather than implicitly adding conditions twice. Repeating a condition of the same kind/region still edits/replaces the existing record, as before. Other established same-face thermal combinations and non-sphere additive force/pressure handling were not redesigned.

`cae_document.gd` checks semantic conflicts before committing a command, so rejected assignments leave data/revision/undo state unchanged. Validation with a mesh additionally detects differing prescribed temperatures on shared nodes, including the sphere equator. This mesh-dependent conflict is reported before export; it can exist provisionally before a mesh is available. Existing numerical prescribed-displacement conflict checking remains in the exporter. Persisted older ambiguous sphere conditions are retained but fail validation; no load is silently dropped.

`cae_workspace.gd` records the most recent launched directory and tags each existing Open Results button with its directory and a tooltip. This makes UI automation target the correct persisted job instead of guessing the newest global result. No result-validation bypass was added. The Results inspector adds **Show / hide viewport legend**, connected to an owner-bound method, to uncover the model without changing scalar values, range or units. Existing anonymous subscriptions were not replaced speculatively, and no new retained anonymous subscription was added for this control.

### Actual UI-driven integration evidence

`test_stage6_workbench.gd` instantiates the real Workbench, invokes its actual creation/command handlers, selects every semantic region and checks that its marker exists, invokes Solve and verifies it routes to Extreme CPU without a normal-adapter thread, emits the actual **Start independent job** button, waits for completion, and emits the matching **Open completed results** button. Six native studies run sequentially in the successful matrix: structural and steady thermal for each of cylinder, sphere and pipe, density 2. Structural setup is axial extension for cylinder/pipe and uniform expansion for sphere. The new pipe thermal UI case is **axial conduction**, not the radial benchmark from Checkpoint 3. The sphere thermal case uses uniform source and fixed exterior temperature.

Creation, parameter/material/condition setup are exercised through shared Workbench handlers rather than synthesized OS mouse/keyboard events or every input dialog. The Start/Open/legend controls are actual Button signal paths. This is stronger coverage than direct manager launch/import, but does not establish full manual interaction coverage.

|Geometry|Study|Nodes / elements|Native relative residual|
|---|---|---:|---:|
|Cylinder|static_structural|75 / 192|9.70939e-11|
|Cylinder|steady_thermal|75 / 192|4.10511e-11|
|Sphere|static_structural|125 / 384|7.43383e-15|
|Sphere|steady_thermal|125 / 384|1.16774e-15|
|Pipe|static_structural|480 / 1536|7.26594e-11|
|Pipe|steady_thermal|480 / 1536|8.76943e-11|

[Measured matrix](stage6-ui-results.json). Residuals describe solving the assembled equations, not geometric/FEM approximation accuracy. Independent physical reference errors remain those from the rerun sphere and pipe numerical tests and the earlier accepted checkpoints; this UI matrix does not independently recompute reaction/energy references for every case. Imported native fields are finite and provenance-verified by the unchanged importer. Structural displacement and von Mises selection plus thermal temperature rendering are exercised, and legend visibility is toggled and asserted. The existing stress tensor remains available through element inspection; a new scalar stress-component selector was not implemented here.

### Persistence and provenance

For all six studies, save/reopen accepts the exact matching result through normal provenance verification. Rotation, translation, uniform scale and material changes are each followed by regeneration and stale import rejection. Undo restores a matching snapshot and accepted import; redo rejects again; undo restores it once more. This is **24 edit/remesh/undo/redo sequences**. Both structural and thermal sphere/pipe projects are covered, extending beyond the earlier single radius edit. Material edits change E/k and name. Region markers are exercised before these edit sequences; exhaustive marker/picking correctness after every edit remains pending. Previous radius/load/mesh-order provenance fixtures are rerun, not weakened.

### Visual verification and limitations

Eight fresh Vulkan images were opened and inspected at 1280x720 and 1920x1080. They show actual results imported by the Workbench button path, preserving all earlier screenshot files. Units, original mesh sizes and real scalar ranges are visible. No panel overlap or missing exterior faces was apparent. Legend position can still obscure the model, but the new inspector control hides it. Existing tooltip popups, encoding artifacts, saturated surface colors and close extrema labels remain visible. Temperature on a prescribed sphere exterior is correctly constant even though its interior is hotter.

|View|1280 x 720|1920 x 1080|
|---|---|---|
|Sphere static_structural|[image](stage6-ui-Sphere-static_structural-1280.png)|[image](stage6-ui-Sphere-static_structural-1920.png)|
|Sphere steady_thermal|[image](stage6-ui-Sphere-steady_thermal-1280.png)|[image](stage6-ui-Sphere-steady_thermal-1920.png)|
|Pipe static_structural|[image](stage6-ui-Pipe-static_structural-1280.png)|[image](stage6-ui-Pipe-static_structural-1920.png)|
|Pipe steady_thermal|[image](stage6-ui-Pipe-steady_thermal-1280.png)|[image](stage6-ui-Pipe-steady_thermal-1920.png)|

The existing inspection section exposes cell faces for mesh inspection. Applying it to solved thermal fields requires preserving source element ownership, original nodal values, spatial picking and cache invalidation on the newly exposed faces. That complete path was not implemented/validated in this increment. **No interior thermal contour or cutaway is claimed.** Existing exterior scalar interpolation and unaveraged element values are unchanged.

### Failures, reliability and remaining coverage

Two graphical matrix attempts timed out (90 and 60 seconds). The retained engine log for the second contains `Resumed function '_initialize()' after await, but script is gone` and `frame_post_draw` disconnect diagnostics. The test's screenshot wait was replaced with explicit forced drawing after process frames. The successful final run completes six studies and all persistence assertions in 66.080 seconds, exit 0, without those engine-log diagnostics. This is an automation adjustment, not a proven repair or source-function mapping for the historical 0xC0000005 fault. No crash evidence was deleted or speculative native/lifecycle correction applied. One earlier focused-test runner overlapped part of the failing graphical attempt; final UI jobs ran sequentially without a concurrent native test runner. No performance-comparison claim is based on the overlapped attempts.

The focused suite covers atomic overlap rejection/shared-node temperature conflict, accepted sphere and pipe numerical references, cylinder quality, existing provenance, Stage 5.1 cache, and app shell. App shell exits 0 after 91 assertions in 10.260 seconds. Existing headless renderer diagnostics remain distinguishable from script errors and process failures. [Focused results](stage6-ui-checks/focused.json), [failed UI run](stage6-ui-checks/ui-attempt2.json), [engine diagnostics](stage6-ui-checks/ui-engine.log), [successful UI run](stage6-ui-checks/ui-final.json), [successful engine log](stage6-ui-checks/ui-final-engine.log).

**Checkpoint 4 verdict: PARTIAL.** Remaining mandatory coverage includes cancellation and native failure reporting through UI controls; full condition edit/remove input-dialog coverage; dedicated node/element and pipe-inner-wall surface picking/probes; new nonfinite-result injection tests tied to these UI projects; load/density/geometry-dimension edit matrices beyond prior fixtures; all-region checks after remesh/reload; and full heat-flux/vector/component-field interaction verification. No complete-interaction or release-readiness claim is made. Sphere density-4 warnings and the pipe axial/Lam? distinction remain unchanged. Native build matrix and renewed historical crash investigation remain future stabilization work; Checkpoint 5 was not begun.

Production files changed: new condition_conflicts.gd, narrow changes to cae_document.gd and cae_workspace.gd. Tests: new test_stage6_condition_conflicts.gd and test_stage6_workbench.gd, new logs/results and eight screenshots. Accepted mesher and kernel sources were not changed. Unrelated working-tree changes were retained.


Final checkpoint verification: **28/28 default regressions**, **7/7 focused scripts**, plus **1/1 six-study UI integration script** exit successfully. Thus eight distinct focused/integration scripts pass, while the two earlier graphical attempts remain recorded failures. All eight new PNG dimensions were independently checked from their headers. [Default results](stage6-ui-regression/results.json), [checkpoint summary](stage6-ui-checks/checkpoint4-summary.json). The UI matrix takes 66.080 seconds; this is total test runtime, not solver performance. The historical native crash remains open. Checkpoint 4 is delivered **PARTIAL**, and no Checkpoint 5 work was started.


## Checkpoint 4 completion - supported interaction coverage PASS

This section supersedes the previous Checkpoint 4 PARTIAL verdict. The completion claim covers representative supported user-facing interactions, not every possible parameter combination or generic engine reliability. Cylinder, sphere and pipe meshing algorithms, density/resource limits, numerical kernels, tolerances, native input grammar and SHA-256 provenance protections were not changed. Sphere's 516 density-4 warnings and minimum mean ratio near 0.136 remain real limitations; the pipe axial benchmark is still not a Lame radial-stress benchmark.

### Cancellation and failure handling

A real defect was found in `extreme_jobs.gd::status`: native `running.lock` is opened with exclusive sharing and DELETE_ON_CLOSE. Godot's file-existence/readability probe can report it absent while the solver process is alive. The old OR condition then mislabeled a live Running job Restartable/Interrupted, hiding its cancellation control. Running-state detection now uses the recorded PID's process liveness rather than treating lock-file readability as proof of termination. No native ownership-lock or numerical code changed.

`test_stage6_failure_ui.gd` creates a bounded pipe transient job (density 6, within the existing limits, one thread / 256 MiB configuration, 200 existing-supported time steps) through the Workbench Start control. It observes Running, presses the actual job-specific Cancel control, observes Cancelled, verifies the recorded native PID exits within a five-second bound, and confirms the cancelled result cannot be imported and the project is unchanged. A fresh small valid job then solves/imports successfully. Cancellation is cooperative; the asynchronous native exit code is not retrieved, so no measured exit-code-3 claim is made.

Importer failure paths now set explicit messages for non-Completed states (including cancellation/native failure), missing results, malformed project/result JSON and native ok=false. JSON parse failures use a parser object and a clear UI error rather than a silent empty dictionary. Missing executable paths reject before allocating/exporting a job; a service dependency path defaults to the unchanged bundled executable. The test injects an absent service executable path rather than renaming or replacing the shared binary. Other failure messages are exercised through actual Open Results buttons.

Malformed output, a direct in-memory NaN mandatory field, and a JSON-null/non-numeric mandatory field are rejected. JSON cannot represent a valid finite-number NaN: an earlier test incorrectly expected it to parse as a numeric value, and that failed assertion/log is retained. A deliberately invalid native input in an isolated diagnostic job produces actual native exit **2** and Failed status. The UI rejects it, preserves the active project and subsequently launches/imports another valid solve. Valid job snapshots/input bytes are not modified for these negative cases. [Measured failure/recovery outcomes](stage6-ui-failure-results.json), [final process-quiescence check](stage6-ui-completion/failure-quiescence.json), [engine log](stage6-ui-completion/failure-quiescence-engine.log). The final bounded failure suite exits 0 in **48.140 s**, including several UI job-list rebuilds; this is test runtime, not native solve time.

### Atomic input dialogs and editing

A second defect was that the analysis dialog emitted SetAnalysis before attempting its condition. A rejected condition could therefore change the study/revision/undo history. The dialog now emits a condition request carrying settings and arguments. New document command ApplyStudyBoundary applies both to an isolated staging document and commits one undoable revision only if both validate. Its Workbench listener is owner-bound. Legacy boundary_chosen remains an observation signal, without a second Workbench mutation path.

Prescribed-displacement controls and the condition inspector use fine-step small-range numeric controls with greater/lesser input allowed. This avoids the loss of small values caused by snapping against the previous +/-1e12 range. Uniform-expansion strain retains its dedicated dialog control. The tests explicitly enter/edit 0.001 -> 0.002 m (and dimensionless strain) and compare to 1e-12, without changing stored solver values through display formatting. These are input-control fixes, not new nonlinear physics or numerical tolerances.

`test_stage6_dialog_ui.gd` exercises actual analysis input controls and Apply buttons for all three primitives: support, force, pressure, prescribed displacement, sphere expansion where applicable, temperature, heat flux, convection, source and radiation. It edits via the condition inspector's SpinBoxes/Apply Values, verifies replacement rather than duplication, removes via Delete Condition, and saves/reopens a semantic temperature assignment. Negative temperature with different pending study settings and overlapping sphere parent/child conditions leave document data, revision and undo history unchanged. Headless UI control testing is programmatic signal/input-value automation, not a claim of OS-level mouse/keyboard coverage. The successful expanded dialog test exits 0 in **4.208 s**. No new curved-surface radiation/convection analytical benchmark is implied by condition-UI coverage.

### Viewport picking, probes and fields

The six-study graphical Workbench matrix is repeated for cylinder/sphere/pipe, structural and steady thermal. It uses the actual Start/Open Results buttons. Exact equality of imported solver nodes/connectivity and the TET4 mesh is asserted. Native fields remain associated with original solver IDs.

The test drives the real camera, projects physical exterior-face points into viewport coordinates and invokes the actual click/inspection handler. For every semantic region it checks that the closest actual mesh hit belongs to that region, material owner and original element ID. The element inspector's displayed stress tensor or conductive-flux vector must contain the exact stored array for that element. Node-mode clicks are also exercised. Camera views from above/below expose the pipe's InnerWall through the opening and both end faces; an exterior view tests OuterWall. Decorative marker meshes are not part of the volume-face BVH. All region checks repeat after rotated remeshing. These are representative visible hits, not exhaustive pixel/edge tests.

Thermal result inspectors now expose owner-bound Pick Solver Node/Element actions, as structural results already did. Structural probing after setting deformation scale 100 resets to original geometry (scale 0), as the existing documented contract requires; picking arbitrarily exaggerated coordinates is not newly claimed. Sphere parent and both hemisphere regions, and all four pipe regions, are covered under the same mechanism.

Through actual existing controls, the matrix switches displacement/von Mises and temperature/element heat-flux magnitude, toggles flux arrows and normalization from their current states and verifies state restoration. A complementary saved-study test exercises Kelvin/Celsius, palette switching, manual physical range and automatic reset, arrow stride, isolines, fixed/per-frame range, automatic deformation scaling and true scale. Stored nodal temperature arrays remain unchanged by display controls. Stress remains unaveraged; no element-to-node stress smoothing or manufactured interior contour is added. Existing legend visibility and job-specific import identification are preserved.

The final six-study picking/field matrix exits **0**, no script/lifecycle errors in its retained engine log, in **73.806 s**. [Final matrix log](stage6-ui-completion/matrix-final-engine.log), [measured six-study fields/residuals](stage6-ui-results.json). The earlier independent physics references remain unchanged; UI residuals are not substituted for FEM/geometric error estimates.

### Persistence, remeshing and provenance

The expanded matrix verifies radius, rotation, translation, uniform scaling and material edits across all six studies: **30** edit/regenerate/stale-reject/undo-accept/redo-reject sequences. Mesh-density changes cause **six** further stale rejections. A separate test uses six recent verified study archives and the actual condition inspector to edit structural load/expansion or thermal conditions, checks stale rejection, remeshes, checks every semantic region remains nonempty, saves/reopens, compares canonical serialized geometry/material/condition/group data, and checks undo/redo provenance: **six** additional load/condition sequences without launching new solver jobs. [Load and field-control verification](stage6-ui-completion/load-verified.json), [six archive outcomes](stage6-ui-completion/load-verified-engine.log). This test exits 0 in **8.946 s**. JSON numeric-type normalization is used as in existing provenance logic; in-memory integer-versus-float dictionary identity is not a persistence requirement.

### Bounded lifecycle diagnosis

`diagnose_stage6_render_wait.gd` reproduces the two diagnostics without the Workbench, native FEM objects, project changes or object deletion: await frame_post_draw, then call force_draw directly from its resumed callback. The retained SceneTree/root remains alive and the process still reaches its completion print. The log contains both **script is gone** and **nonexistent frame_post_draw disconnect** messages, despite process exit 0. That diagnostic run is deliberately classified as not clean. A process-frame-wait/force_draw control exits 0 without these messages (**2.162 s**). [Signal reproducer](stage6-ui-completion/render-signal-engine.log), [clean control](stage6-ui-completion/render-control-engine.log).

Re-entering the rendering signal is sufficient to reproduce the observed automation diagnostics; Workbench object deletion is not necessary for this reproduction. This does not identify the precise Godot native defect or prove all unrelated lifetime paths safe. The narrow correction is confined to screenshot automation: wait for process frames, then force drawing outside an awaited frame_post_draw callback. The Workbench matrix and legacy Stage 6 sphere/pipe capture scripts use that sequence; prior images are preserved. This is **not** a fix or causal attribution for historical 0xC0000005 / offset 0x518504. No dump was removed, no engine/extension ownership was changed speculatively, and Checkpoint 5 investigation has not begun.

### Verification and preserved failures

Final **10/10 focused/integration scripts exit 0**, including cancellation/failure UI, expanded dialogs, six-study picking/fields, six-archive persistence, condition conflicts, sphere dialog, provenance, cache, probes and app shell. The render control is an additional diagnostic control, not folded into that count. Final app shell: **91 assertions, exit 0**, **9.917 s**. The complete default manifest ran once after production changes stabilized: **28/28 passed**. Existing headless dummy-renderer diagnostics remain; clean process exit is not a claim of globally error-free logs.

Retained failures include pre-fix cancellation tests that could not observe Running; a test-only type-inference error; the invalid NaN-as-JSON expectation; an incorrect flux-arrow default-state assertion; an incorrect stale-result deformation assertion inside a helper (exit 0 but engine script errors, correctly counted as failure); and archive test mistakes involving JSON numeric normalization and reversing the already newest-first job list. All corrected final tests check actual exit codes and engine script diagnostics. These failures are not silently counted as passes. The isolated render-signal diagnostic likewise exits 0 but is explicitly not clean.

### Screenshots, deferred renderer and scope

Eight updated actual Vulkan screenshots at 1280x720 and 1920x1080 were opened and inspected using the existing Checkpoint 4 image links. Their prior versions are backed up in [previous-screenshots](stage6-ui-completion/previous-screenshots/). Probes deliberately show original geometry scale 0. Both structural/thermal regions and real units/ranges render; no missing volume faces or panel overlap was apparent. Existing encoding artifacts, close thermal extrema labels, small-window framing and a status label sometimes retaining asynchronous preparation text remain practical limitations. Legends can be hidden with the already validated control. No fabricated temperature/stress data was introduced.

A sphere cutaway remains **deferred**, as permitted for this checkpoint. The current mesh-inspection section is not a validated thermal interior renderer; source-element ownership, picking and interpolation on newly exposed faces would require additional rendering work. Hot interior temperatures remain available through numerical probes and stored fields, not falsely painted on the exterior.

**Checkpoint 4 verdict: PASS for the supported representative workflows and required interaction/failure cases above. Stage 6 remains PARTIAL.** Large historical job lists still rebuild synchronously; no responsiveness or peak-memory benchmark is claimed. The historical access violation, native build matrix, broader physical-reference coverage and final stabilization remain outside this checkpoint. Do not interpret the passing interaction suite as universal CAD/physics capability or release readiness. Checkpoint 5 has not been started.

Production changes in this completion: `extreme_jobs.gd`, `cae_document.gd`, `analysis_editor.gd`, `cae_workspace.gd`. Tests added/expanded: `test_stage6_failure_ui.gd`, `test_stage6_dialog_ui.gd`, `test_stage6_load_persistence.gd`, `test_stage6_workbench.gd`, `diagnose_stage6_render_wait.gd` and the two existing Stage 6 graphical capture scripts. Accepted mesher/kernel sources and unrelated working changes were preserved.


Final completion evidence: [summary and exact final exit codes](stage6-ui-completion/checkpoint4-complete-summary.json), [28-script regression manifest](stage6-ui-completion/regression/results.json), [successful final matrix and rendering diagnostic controls](stage6-ui-completion/verification.json), [dialog final run](stage6-ui-completion/complete.json), [load/field-control final run](stage6-ui-completion/load-verified.json), [app-shell/provenance/cache/probe checks](stage6-ui-completion/final-checks.json). Some batch files intentionally retain earlier failed attempts; the summary selects the latest successful run of each named test without deleting those failures.

## Checkpoint 5 — Final Stabilization and Acceptance

**2026-11-12. Verdict: FUNCTIONAL PASS — STABILIZATION BLOCKED.** The supported representative geometry, numerical and UI workflows pass the checks below. The historical Windows access violation remains a credible unresolved release concern. Stage 6 cannot be declared complete. Earlier Checkpoint 1–4 verdicts retain their documented scopes; this section supersedes statements that Checkpoint 5 has not started. Stage 7 was not started.

### Changes and evidence preservation

No production source, meshing algorithm, kernel, tolerance, ABI, native grammar, checkpoint format or provenance validation was changed in this checkpoint. No speculative lifecycle fix was applied. Added test-only runners: `stage6_acceptance_runner.py`, `stage6_dump_inventory.py`, `test_stage6_native_matrix.gd`, `stage6_restart_acceptance.py`, `stage6_lame_reference.py`, `capture_stage6_final_cylinder.gd` and `stage6_finalize_evidence.py` under `tests/`. The new cylinder capture derives from the existing Stage 5 fixture, writes separate output paths and uses process-frame waits followed by force_draw outside frame_post_draw callbacks. Existing capture fixtures were preserved.

Fixed-path fixtures were backed up before running. Changed numerical files/screenshots were archived under [refreshed](stage6-final/refreshed/), and historical originals restored byte-for-byte. Identical fresh screenshots are also archived. See [restoration receipt](stage6-final/restored-historical-files.json), [historical evidence inventory](stage6-final/historical-artifacts.json) and [image dimensions/hashes](stage6-final/images.json). Earlier failed attempts, legacy cylinder quality comparisons and crash files were retained. Unrelated working-tree changes were not reverted.

### Historical access violation: UNRESOLVED

Read the retained [investigation](GODOT_CRASH_INVESTIGATION.md), Stage 5/5.1 reports, EventBus/ModuleManager/AnalysisDrawer teardown paths and Workbench deferred preparation/solve cleanup. The earlier bound-method correction remains supported for its controlled reproduction: the historical trace stops during invalid-callable inspection, its bound-method control passes, and automatic extension loading was not required for that reproduction. That limited finding does not establish the cause of every later matching-offset crash.

New read-only inspection found two raw AMD64 dumps outside the repository in `C:/Users/Victus/AppData/Local/CrashDumps/`. They were not copied, deleted or replaced. [Inventory](stage6-final/dump-inventory.json) records their full paths, sizes, SHA-256 hashes, modules, exception contexts, instruction bytes and raw stack candidates. Together they occupy approximately 663 MB; **no new dump was generated**.

|Dump suffix|Exception / executable offset|RAX|RCX|Invalid read|
|---|---|---|---|---|
|13660.dmp|0xc0000005 / 0x518504|0x159abb2af80|0x159b01b1b40|0x159abb2afe8|
|5172.dmp|0xc0000005 / 0x518504|0x12f90428560|0x12f96f89080|0x12f904285c8|

Both contexts have RIP `0x7ff7ec408504`. Dump bytes confirm `48 8b 41 20` immediately before `48 8b 40 68`: load `[rcx+0x20]`, then fault reading `[rax+0x68]`. The saved bytes at RCX+0x20 equal the respective nonzero RAX values. The fault addresses equal RAX+0x68 and are absent from the captured readable memory ranges. This confirms an invalid indirect read, not the allocation history or a proven use-after-free.

Both loaded engine modules have the same path, base, image size 116,379,648 and timestamp zero, with no engine CodeView record. The current engine identifies as **4.0.stable.official.92bee43ad**, executable size 114,434,448, SHA-256 `dbc5b785ac1df4878d15e527b7d41f16c83a1107958762ac03c0c7ac35daad5c`. Matching metadata/instructions support a common build/site; a zero timestamp and absent dump image hash do not independently authenticate the complete historical executable bytes.

The top saved stack word maps to engine offset `0x3fcbebb` in both dumps; other shared candidates include `0x3ff2882`, `0x44a33be`, `0x430b426` and `0x4dc092`. Other raw words differ. These are **raw stack words, not unwound frames**; they can include stale pointers/data. No complete symbolized stack comparison is claimed. The registers supplied in the earlier WinDbg narrative differ from these two dumps, so they must not be represented as a fresh analysis of the same context.

Repository/.tools searches found no matching engine PDB or symbolized build. No installed cdb/WinDbg command or Windows Kits x64 debugger was found at the checked locations. The retained addr2line result is unknown (`??`); function/source resolution is **NOT TESTED: matching symbols unavailable**. No Embree/OIDN export was used as a substitute function attribution. The available dumps cannot establish whether the reported later failures happened before or after a particular listener change. Stale Object/callable state, deferred cleanup, extension lifetime and an engine defect remain hypotheses for the broader recurrence.

New bounded controls: destroyed-owner listener regression exits 0 in **1.596 s**; unchanged app shell reports **91 Passed, 0 Failed**, exits 0 in **7.778 s**; graphical process-frame/force_draw control exits 0 in **6.275 s**. [Lifecycle receipts](stage6-final/lifecycle.json). Workbench teardown additionally passes after six real imported studies and after cancellation/failure recovery. Workbench `_exit_tree` cancels preparation jobs and joins started preparation/normal solve threads; the reviewed AnalysisDrawer and ModuleManager subscriptions are owner-bound. This inspection found no new demonstrable invalid-lifetime behavior justifying a production edit. New extension-disabled or subsystem-removal crash reproductions were not performed: the corrected current shutdown path did not fail; historical one-at-a-time isolation evidence is retained above. Native extension/result visualization interactions are exercised by the default manifest and Vulkan matrix, not proven universally safe by them.

Initial launches using default APPDATA returned 3221225477 before any engine banner or assertions, including the rendering-only control. A workspace APPDATA control then passed. These startup failures have **no captured fault site/stack** and are not classified as the historical shutdown reproduction or silently counted as passes. [Original launch receipts](stage6-final/lifecycle-default-appdata-failed.json). All subsequent Godot invocations used the writable `.tools/cae-appdata` directory. No platform permission/settings change was made. The historical render-signal reproducer was not rerun; its earlier independent evidence remains distinct from the access violation.

Clean controls are bounded observations, not proof of a repaired crash. There is no new pre-fix/post-fix pair because no new defect was isolated or fixed. **Release stabilization remains blocked pending a reproducible later fault with an unwound context and matching symbols, or equivalent direct lifetime evidence.**

### Native compatibility and restart

Compiler: `C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe`, MinGW-Builds x86_64-posix-seh GCC **13.1.0**. Existing direct build infrastructure: `native/extreme/build.ps1`; common flags `-std=c++17 -municode -static -ffp-contract=off -I<root>/native/src`, source `native/extreme/main.cpp`, link `-lpsapi`. OpenMP configurations add `-fopenmp`; Debug adds `-O0 -g`, Release `-O2`. This is the standalone Extreme matrix; no extension rebuild or new ABI is claimed.

|Configuration|Executable|Build exit / seconds|Structural / steady thermal / verified import|
|---|---|---|---|
|Release + default OpenMP|unicore_solver.exe|0 / 27.829|PASS / PASS / PASS|
|Debug + OpenMP|unicore_solver_debug.exe|0 / 16.120|PASS / PASS / PASS|
|Release serial fallback|unicore_solver_noomp.exe|0 / 18.158|PASS / PASS / PASS|
|Debug serial fallback|unicore_solver_debug_noomp.exe|0 / 16.716|PASS / PASS / PASS|

Build logs are empty on successful compilation/linking, with exit 0. [Three-build receipts, flags/commands and executable hashes](stage6-final/build.json); [Debug serial build and final matrix](stage6-final/references.json). Initial PowerShell execution-policy failures are retained in [failed receipts](stage6-final/build-policy-failed.json); the correction was process-local `-ExecutionPolicy Bypass` on the existing build invocation, not a production/build-source change.

Final matrix: eight small Stage 6 cylinder TET4 jobs, two threads for OpenMP and one for serial, 256 MiB configured budget. Each configuration checks finite imported fields through the unchanged provenance importer, axial structural displacement, reaction equilibrium, linear thermal temperature, heat balance and recorded PID termination. Established axial fixture guards remain 1e-5 for field error and 1e-6 for balance. The additional 1e-8 residual sanity guard is looser than the unchanged approximately 1e-10 solve target and is not a new continuum accuracy claim. Final matrix exits 0 in **3.561 s**. [Measured fields](stage6-final/native-matrix-fields.json), [archived normal jobs](stage6-final/native-jobs/). Alternate executables were selected through the existing job-service executable property; actual Workbench Start/Open buttons were separately verified with the default executable, not with four distinct UI selectors.

The existing `UNICORE_JOB 1` / `UNICORE_STATE 1` formats are unchanged. A density-1 Stage 6 cylinder thermal export is used as the mesh/material/boundary source for a standalone transient job (dt=0.01 s, three steps, initial 300 K). Normal CLI solve exits 0; supported pause-after-one-step exits **3** and writes a valid checkpoint. All four builds resume it and match the uninterrupted final nodal temperature within the established **1e-7 K** restart guard. Corrupt checkpoint header exits **2**; changed input bytes with an old checkpoint exit **2**; structural restart exits **2** (`RESTART_ONLY_TRANSIENT_THERMAL`); a new valid job after these failures exits 0. [Commands, exit codes and differences](stage6-final/restart/results.json), [inputs/states/results](stage6-final/restart/). The final outer restart script exits 0 in **1.101 s**. This is CLI restart compatibility; no new Workbench transient-restart import feature is claimed.

Cancellation is separately checked by the existing real Workbench failure fixture: Running → Cancelled, PID stops, cancelled import rejects, malformed/nonfinite fields and native failure reject without project mutation, then a fresh valid job imports. It exits 0 in **12.939 s**. The actual invalid native input exits **2**. Process cancellation is not checkpoint-capable interruption, and asynchronous cancellation is not assigned an invented native exit code. [Log](stage6-final/test_stage6_failure_ui.log). At final quiescence no Godot or unicore solver process remained.

### Geometry and numerical acceptance

All existing geometry/reference tests were rerun unchanged. [Detailed commands, assertions and diagnostics](stage6-final/all-test-receipts.json); fresh numerical files are archived in [refreshed](stage6-final/refreshed/), with unchanged deterministic outputs also represented by their retained original files/logs.

|Geometry|Verified scope|Result|
|---|---|---|
|Cylinder|Density 1–8 topology/face-sharing connectedness, positive volume, conforming winding, regions, exact repeatability, quality distributions; axial structural/thermal references, pressure/equilibrium, remesh/provenance|PASS|
|Sphere|Closed exterior/hemisphere partition, positive TET4/outward normals, repeatability, analytical volume/area; expansion, source heating, pressure resultant, imported fields|PASS within prior density 1–4 scope|
|Pipe|Empty polygonal bore, conforming topology, four surfaces/normal signs; inner-pressure direction, axial structural and logarithmic radial thermal references, balance, thin-wall rejection, deterministic/provenance checks|PASS within prior resource bounds|

The historical before/after cylinder comparison remains intact; no new performance or quality improvement is claimed. Sphere density 4 still has **516 legacy warnings**, minimum mean ratio approximately **0.1361**, maximum nodal temperature error **0.017046 K**, centroid-weighted relative flux error **0.20138**, maximum flux component error **146.071 W/m²**. Decreasing temperature error does not establish accurate pointwise flux. Pipe density 4: 2,880 nodes / 12,288 TET4, minimum mean ratio **0.52636**, nodal temperature error **0.266562 K**, heat-rate error **0.359212%**, energy imbalance approximately **8.28e-11 W**. These reproduce the established references without changing their thresholds.

### Additional Lamé-compatible pipe reference

New **test-only plane-strain** benchmark uses actual accepted Stage 6 pipe meshes at densities 1, 2 and 4: Ri=a=0.05 m, Ro=b=0.1 m, L=0.1 m, E=1000 Pa, nu=0.25, internal pressure pi=1 Pa, external pressure po=0. Axial displacement uy=0 at every node enforces plane strain. In-plane symmetry imposes ux=0 at x=0 and uz=0 at z=0, removing rigid modes with constraints consistent with the radial solution. There is no clamped end; end faces have no in-plane tractions. Rotated archived meshes are transformed back into local coordinates before constructing these isolated CLI inputs. The source snapshot supplies geometry only; its original loads/results are not reused. This does not add new UI boundary-condition capabilities.

With A=(pi*a²-po*b²)/(b²-a²), B=a²*b²*(pi-po)/(b²-a²): sigma_r=A-B/r², sigma_theta=A+B/r², sigma_y=2*nu*A; u_r=(1+nu)*[(1-2*nu)*A*r+B/r]/E. This is the plane-strain idealization described in [MIT structural mechanics notes, section 4](https://ocw.mit.edu/courses/22-314j-structural-mechanics-in-nuclear-power-technology-fall-2006/137e6469e37e9d347b7b3b69292da2f3_l4_2.pdf). Pressure uses actual inner-facet material normals. Polygonal boundary and FEM errors both contribute.

The acceptance criterion was written before execution: nodal displacement RMS and volume-weighted centroid radial/hoop stress RMS errors must each decrease over densities 1,2,4. It establishes refinement, not a specified absolute engineering accuracy. Residual sanity uses 1e-8 without changing the solver. Stress metrics sample centroids and are not exact continuum L2 norms.

|Density|Nodes / TET4|Displacement relative RMS|Radial stress relative RMS|Hoop stress relative RMS|
|---|---:|---:|---:|---:|
|1|96 / 192|0.236292|0.938998|0.410023|
|2|480 / 1536|0.085964|0.542019|0.272597|
|4|2880 / 12288|0.024468|0.289161|0.152326|

All three native processes exit 0; residuals remain below 9.35e-11. [Complete commands/errors](stage6-final/lame/results.json), [reproducible native inputs and raw results](stage6-final/lame/). The outer script exits 0 in **3.359 s**. Radial stress remains inaccurate on the finest mesh; the earlier axial patch test is not substituted for this pressure reference. Densities outside this bounded sweep are **NOT TESTED** for this reference. Independent pressure direction/equilibrium remains covered by the unchanged contract test.

### Regression, graphics and diagnostics

Complete default manifest: **28/28 pass**, outer exit 0, **67.798 s**, after production state was established. [Raw manifest results/logs](stage6-final/regression/results.json). Focused batch initially passes 16/17 with one failed cache attempt; after restoring its four existing archived job dependencies into workspace APPDATA, the same cache fixture exits 0 in **4.035 s**, yielding **17/17 distinct focused scripts passed on their final executions**. Field equivalence exits 0 in **2.762 s**. The initial cache assertion/120.024-second timeout remains recorded in [focused results](stage6-final/focused.json) and [engine failure](stage6-final/cache-fixture-failed-engine.log). Its waiting Godot child was explicitly stopped after the console wrapper timed out; subsequent invocations use the engine executable directly. No numerical code was changed to repair this harness dependency.

Six-study actual Vulkan Workbench matrix exits 0 in **38.970 s**: Start/Open controls, cylinder/sphere/pipe structural and thermal, matching original solver nodes/elements, all semantic-region element/node hits including InnerWall, original stored tensor/flux probe ownership, field switching/arrows, save/reopen, 30 geometry/material edit/undo/redo sequences and six mesh-density stale rejections. Saved-study load/condition edits and field controls exit 0 in **6.986 s**. [Graphical receipts](stage6-final/graphics.json), [matrix engine log](stage6-final/test_stage6_workbench-engine.log). These logs contain no script or frame_post_draw lifetime diagnostics; representative programmatic UI controls are not exhaustive OS mouse/keyboard testing.

Sixteen fresh PNGs were opened and inspected, dimension-checked at **1280×720 / 1920×1080**, using Vulkan Forward+ on AMD Radeon RX 6550M. Eight sphere/pipe displacement/temperature images: [fresh captures](stage6-final/refreshed/); eight cylinder displacement/von Mises/temperature/element-flux images: `stage6-final/cylinder-{displacement,von_mises,temperature,heat_flux}-{1280,1920}.png`. Cylinder capture exits 0 in **16.961 s**; its thermal array reference has maximum temperature error **4.19e-8 K**, flux-vector error **1.29e-5 W/m²**, expected axial flux **-3750 W/m²**. [Numerical capture receipt](stage6-final/cylinder-display-numerical.json).

No missing exterior faces or obvious inverted normals were apparent. The pipe opening/inner wall is visible and picking is asserted against actual topology. Legends use actual units/ranges and field values; sphere prescribed exterior temperature remains constant while its interior is hotter. Retained visual limitations: encoding artifacts, sphere extrema labels close together, small thermal endpoint text, legends partly covering geometry, stale preparation status text, and exaggerated automatic cylinder deformation. The cylinder legend explicitly reports that display scale. The sphere thermal cutaway remains deferred. Sphere/pipe stress/flux switching and exact stored values are asserted in the Vulkan matrix; separate fresh screenshots of every sphere/pipe component field were not generated.

The app shell still emits its previously documented duplicate resized-connection and headless dummy-renderer diagnostics. Several headless display/persistence tests retain dummy `mesh_get_surface_count` messages. These are reported in receipts and logs, not suppressed or described as error-free. The successful cache, graphical matrix, cylinder capture, native matrix and render control have no new lifecycle diagnostics. An exit-zero script error is a failure: the failed cache attempt is not folded into passing counts.

### Resource observations and reproducibility

All native jobs were sequential, bounded and configured at 256 MiB; reference jobs use one thread except the final OpenMP compatibility matrix uses two. Expensive native tests did not overlap graphical Workbench tests. No uncontrolled stress loop or HPC benchmark was run. Single observations: density-4 pipe generation **676.712 ms**, structural native solve **346.850 ms**, thermal native solve **20.173 ms**; six-study UI time **38.970 s** includes UI/persistence/probing and is not pure solver time. No native peak-working-set measurement was made, and no Godot static counter is presented as process memory. No speedup conclusion is drawn from earlier runs with different job-list histories.

Exact expanded child commands, exit codes, assertions, durations, diagnostics and artifact paths are in [63 test/build receipts](stage6-final/all-test-receipts.json); restart and Lamé native subprocesses have their own detailed command receipts linked above. Reproduction from the repository root (PowerShell):

```powershell
$py = 'C:/Users/Victus/AppData/Local/Python/bin/python.exe'
& $py tests/stage6_dump_inventory.py
& $py tests/stage6_acceptance_runner.py lifecycle
& $py tests/stage6_acceptance_runner.py build
& $py tests/stage6_acceptance_runner.py focused
& $py tests/stage6_acceptance_runner.py regression
& $py tests/stage6_acceptance_runner.py graphics
& $py tests/stage6_acceptance_runner.py references
& $py tests/stage6_finalize_evidence.py
```

The `references` phase builds Debug serial, runs the final eight-job compatibility matrix and four-build restart check, then Lamé, cache and cylinder graphics. Existing Stage 5.1 cache/equivalence fixtures require the four jobs listed in `.tools/stage51-fixtures.json`; in this execution those existing directories were copied from original APPDATA into `.tools/cae-appdata/Godot/app_userdata/UniCORE/extreme_jobs/`. Missing dependencies must fail rather than be replaced with fabricated fields. New final normal-job exports are archived under `stage6-final/native-jobs/`; restart/Lamé jobs retain their complete inputs/results. Historical dump paths remain local external evidence.

### Final Stage 6 verdict

**FUNCTIONAL PASS — STABILIZATION BLOCKED.** Geometry, bounded numerical references, four native build configurations, checkpoint compatibility, cancellation/recovery, default regressions and representative UI/rendering acceptance pass. Confidence is high for these enumerated small supported workflows, not for general CAD, arbitrary meshes, pointwise curved-surface stresses/fluxes or unrestricted performance.

The historical `0xc0000005 / 0x518504` access violation is **UNRESOLVED**. Two independently preserved contexts confirm the invalid read site; current clean exits neither identify the broader root cause nor refute later recurrence. Matching symbols, a reliable later-crash reproduction and an unwound native stack remain unavailable. Stage 6 is not certified complete or release-stable, and the existing limited listener correction is not relabeled a universal crash fix.

Final tooling checks: all five new Python helper files compile with `py_compile` (exit 0). Whole-worktree `git diff --check` exits 2 for an existing trailing blank line in `ui/cae/cae_workspace.gd:1862`; that production file was not changed in Checkpoint 5. [Exact formatting-check receipt](stage6-final/worktree-format-check.json). No cleanup of unrelated working edits was performed.
