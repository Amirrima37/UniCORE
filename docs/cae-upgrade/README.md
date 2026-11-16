# CAE performance, visualization and radiation validation

Implementation is in the existing CAE workspace and native solver. Debug and release GDExtension DLLs were rebuilt using native/build_direct.ps1. Graphical tests used Godot 4.0 stable, Vulkan Forward+, AMD Radeon RX 6550M. Screenshots temperature.png, heat_flux.png and radiative_heat_flux.png are actual application framebuffer captures.

## Mesh preparation

Baseline profiling at 4096 HEX8 cells: quality 218.400 ms, exterior faces 132.364 ms, BVH 152.576 ms, connectivity 7.594 ms; complete preparation 561.607 ms. After cached face bounds/centers and integer topology keys, an observed synchronous run took 419.682 ms (BVH 40.611 ms). These are individual wall-clock samples, not statistical speedup guarantees.

Large models now use cancellable background preparation with generation IDs. Document mesh revisions replace arrays; retained source revisions are copied to an independent snapshot in bounded 2 ms main-thread slices. Workers compute topology, quality, connectivity, BVH, vertex/index and contour buffers. ArrayMesh resources are created on the main thread. Obsolete generations are discarded, and workers are cancelled/joined during teardown. Selection and camera movement do not regenerate geometry. Section jobs reuse immutable quality/connectivity/full-surface caches; tests verify this reuse. The section remains a cell-boundary X section.

Headless benchmark measurements below include asynchronous snapshot copying and worker completion. Frame gaps measure SceneTree heartbeat, not rendered FPS. Resource times are CPU submission measurements; they are not GPU completion timings. Static memory is whole-process Godot static allocation, not RSS or GPU memory. Synthetic grids exceed the existing production mesher's 10000-node safety limit without changing that numerical solver limit.

| Elements | Nodes | Generation ms | Async preparation wall ms | Max heartbeat gap ms | Picking p95 ms | Static bytes |
|---:|---:|---:|---:|---:|---:|---:|
|4096|4913|5.274|529.985|8.108|0.173|31083728|
|10000|11466|12.162|1238.259|8.537|0.379|47666792|
|50000|54621|62.241|9675.224|8.544|0.398|150504960|
|100000|106641|219.827|17432.087|8.618|0.311|274681832|

Full measurements: baseline.json and large-mesh.json. No FPS claim is made. Preparation of 100000 cells still takes seconds, but no longer occupies the scene thread continuously. Huge model generation itself was benchmarked separately and remains synchronous. Memory use and Variant-heavy quality evaluation remain opportunities for native acceleration.

## Viewport and postprocessing

The grid has optional visibility, adjustable opacity and camera-distance fading with depth testing. Mesh inspector groups are collapsible. Engineering values use fixed precision or scientific notation without changing stored values. Viridis, cividis, diverging and temperature maps, manual mesh/thermal bounds and discrete bands are available. Invalid/inverted/degenerate quality diagnostics keep explicit colors.

Temperature is interpolated as a scalar on linear FEM faces in a shader before color mapping. Conductive flux is element-centered and not averaged across material boundaries. Surface arrows sample actual solver flux, with density, magnitude scaling and normalization controls. The current conductivity model is isotropic scalar k: q=-k grad(T); anisotropic conductivity is not added or claimed. Temperature conversion K/C affects display only. Min/max labels, node probes, final gradient readouts, isolines, history graphs, actual-state playback, playback speed and fixed/per-frame ranges are implemented. An eight-entry surface cache and bounded material cache reduce repeated uploads on replay. Historical conductive and radiative flux are computed from stored solution states in native code. Legacy saved results without those history fields explicitly report their absence.

## Radiation formulation and SI units

Gray diffuse radiation to prescribed isothermal surroundings has outward-positive flux eps*sigma*(T^4-Tsur^4), sigma=5.670374419e-8 W/(m^2 K^4). Temperatures inside the solver are Kelvin, flux W/m^2, heat rates W, conductivity W/(m K). There is no surface-to-surface/view-factor enclosure model.

Surface residual is integral Ni*q_rad dA. Its consistent tangent is integral Ni*Nj*4*eps*sigma*T^3 dA. A seven-point degree-five triangle rule integrates these polynomial contributions. Newton uses the existing sparse PCG infrastructure, nonnegative-temperature backtracking, a 60-iteration limit, cancellation and explicit line-search/nonconvergence errors. Convergence uses free-node residual norm scaled by physical applied/radiative loads, tolerance 1e-9; transient storage terms are not used to artificially inflate that scale. Residual history and iteration totals are exported. Transient radiation uses lumped-capacity backward Euler with Newton at each step.

Emissivity must be finite and in [0,1]; surroundings must be finite nonnegative Kelvin. Material-linked emissivity is explicit and missing properties cause validation failure. Convection and radiation can coexist on a face. Result fields include radiative_heat_flux, radiative_power_W, surface_emissivity, radiation_group_power_W, radiation_loss_W and separate conduction/convection/storage diagnostics. Fixed-temperature reactions represent supplied boundary heat. Energy balance is sum(reactions)+applied-convection-radiation-storage; relative errors are exported separately.

## Numerical evidence

See radiation-native.txt for full precision results and native/tests/thermal_radiation_test.cpp for executable benchmarks.

* A: prescribed 600 K surface, 300 K surroundings, eps=.8: analytical 5511.603935268 W/m^2. Native and binding comparisons pass.
* B/C: convection+radiation equilibrium with manufactured uniform 600 K solution converges from 200 K and 1000 K in 4 and 6 Newton iterations. Relative energy errors about 2.37e-10 and 4.18e-12.
* D: cooling tetrahedron, k=1e6, volumetric heat capacity=1000, initial 600 K, surroundings 300 K, eps=.8; initial Bi approximately 2.76e-6 justifies the lumped reference. RK4 with 200000 steps gives 585.170450389 K at 0.2 s. Backward Euler errors are 0.0075297 K at dt=.002 and 0.0037682 K at dt=.001. Final energy error at dt=.001 is approximately -1.52e-8 W.
* E: heat balance is checked in prescribed-temperature, equilibrium and transient cases. The consistent surface tangent also passes a central finite-difference check on nonuniform nodal temperatures.

Actual graphical coupled model: 556.378217213 to 600 K; convection 25.637821721 W; radiation 39.794852459 W; imbalance about -2.64e-12 W. See radiation-coupled.json. Material temperature-range warnings remain visible rather than extrapolation being hidden.

## Regression investigation

Final main manifest: 26/26 passed (manifest-regression.json). Extended run: 51/52 passed, with one unresolved app-shell access violation. Three previous failures were runner misclassification of deliberately invalid anonymous scripts; exact expected diagnostic counts and zero-failed-assertion summaries are now required, and unexpected runtime/script errors still fail. Multiplayer used an offline mock without its required test key; the test setup is corrected. Maxwell velocity rescaling left a float32 momentum residual; stored momentum now receives a rounding correction without weakening the temperature or momentum assertions.

The app-shell failure is an existing baseline defect: all 91 assertions pass, then process exit is 0xC0000005 in both headless and graphical runs. Windows Application Error identifies Godot_v4.0-stable_win64.exe at offset 0x518504 as the faulting module. Under GDB the same test exits normally and logs invalid ObjectDB-slot diagnostics; no fault stack could be obtained. A deferred-teardown experiment did not fix the crash and was reverted. Evidence supports a timing-sensitive lifecycle failure, but does not prove its root cause or exonerate every extension interaction. It remains failing, not suppressed. Raw GDB output is app-shell-gdb.log; extended-regression.json retains every suite result.

Graphical capture scripts exercise mesh modes, node/element selection, sectioning, projection, thermal/radiation fields, real flux arrows, and transient playback. Tests call application handlers; an exhaustive physical-mouse test was not performed. No sandbox cache/permission error occurred. Nuclear, molecular, structural HEX8/TET4, steady/transient thermal, material and AI/CAE regression results are included in the saved summaries.

## Remaining limits

The app-shell access violation remains unresolved. Large-model timings are synthetic CPU/heartbeat measurements, not proof of smooth rendering at arbitrary model complexity. Production numerical meshing limits are preserved. Only isotropic conduction and radiation to prescribed surroundings are implemented. Section axes and clipping geometry remain as before. Manual-scale/palette changes can require new contour buffers; preparation caches are bounded, not unlimited. No claim is made that the complete extended suite is green.
