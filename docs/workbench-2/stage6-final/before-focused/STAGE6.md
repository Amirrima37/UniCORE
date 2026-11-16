# Latest Stage 6 status: Checkpoint 4 PASS; Stage 6 remains PARTIAL

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
