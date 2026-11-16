# Mesh inspection validation

Open Mesh inspection from the CAE menu. Solid, wireframe, combined, nodes, elements, quality and invalid-element modes use the existing numerical mesh. Selection highlights are a separate draw object; selection does not rebuild mesh surfaces. Solid/edge/node buffers use indexed ArrayMesh surfaces. Rendering caches are invalidated on document changes and section changes. The X section keeps cells whose center lies below the threshold, then extracts their exterior, including newly exposed internal nodes. This is a cell-boundary section, not a planar cut through cells. Set 1 to restore the full mesh.

Node mode draws exposed nodes with a solid depth occluder. Picking uses camera rays, a surface-face BVH and pixel-space node tolerance. It runs on clicks, not mouse movement. World coordinates and original zero-based FEM IDs are preserved. Regeneration clears the selection. Focus changes the orbit target to the selected cell center.

## Numerical definitions

* Jacobian: signed minimum determinant. HEX8 uses the same trilinear derivatives and eight 2x2x2 Gauss points as the C++ structural kernel; volume is the signed sum of these determinants. Maximum determinant is also shown in entity information.
* TET4: determinant of [p1-p0, p2-p0, p3-p0]; signed volume = determinant / 6.
* Scaled Jacobian: determinant divided by the product of the three derivative-column lengths, minimized over the same samples; TET4 uses corner 0. This is dimensionless and is not an ideal-tetrahedron-normalized metric.
* Distortion: 1 - scaled Jacobian.
* Edge aspect ratio: longest topological edge / shortest edge. This is distinct from the native HEX8 derivative-column aspect diagnostic.
* Jacobian and volume units: m^3. Other metrics are dimensionless. Mesh coordinates come from the FEM mesh, in metres.
* Degenerate: abs(minimum determinant) <= longest_edge^3 * 1e-12. Inverted: minimum determinant < 0. Nonfinite input is invalid. Warning: scaled Jacobian < 0.2 or edge aspect > 5. These are display diagnostics, not solver acceptance tolerances.

Contours are element-centered, unaveraged, with actual finite whole-mesh bounds. Numerical min/mid/max ticks accompany the gradient. Tiny relative ranges below 1e-6 use the midpoint color to avoid amplifying floating-point noise. Nonfinite values are magenta, inverted purple, degenerate yellow, warning orange; these override the gradient. Nonfinite coordinates cannot be meaningfully positioned in the viewport; the invalid count and inspection diagnostics remain the evidence for those cells.

## Verification

Godot 4.0 stable, Vulkan Forward+, AMD Radeon RX 6550M. `tests/capture_mesh_inspection.gd` launches the application workspace (not the editor), exercises seven modes, node/element picking and highlight assertions, camera/projection changes, section rendering, selection invalidation on regeneration, and TET4 rendering. PNGs in this directory are actual framebuffer captures, visually inspected during development. Automation calls UI handlers; physical mouse gestures and exhaustive interaction sequences were not manually tested.

`tests/test_mesh_inspection.gd` covers regular/distorted HEX8, TET4, inversion, degeneracy, nonfinite input, shared faces, connectivity, cache reuse, section exposure of an internal node, empty sections and contour bounds. Generated mesh volume and minimum Jacobian are compared with native mesher diagnostics when available. Native C++ files are unchanged; no extension rebuild was needed.

The complete existing regression runner (`native/run_regressions.py --all-suites`) ran 48 suites: 42 passed, 6 failed. Structural, thermal, CAE shell/recovery/material/AI and native solver suites passed. Failures: adversarial momentum drift, app-shell process exit 3221225477 after 91 passing assertions, diagnostic-logger and self-repair parse diagnostics, multiplayer mock workflow, validator parse diagnostics. These failures are outside the mesh implementation; the full runner is not green. Raw summary: regression-results.json; logs remain under .tools/mesh-regression.

`tests/test_mesh_result_integration.gd` also passed in the graphical application: structural, steady thermal and transient thermal solves; quality/result switching; immutable result fields; thermal inspection uses the actual solver TET4 connectivity rather than mesher HEX8 connectivity. The 22 original manifest suites were rerun successfully after integration changes. Both new mesh tests are now included in the regression manifest. Final manifest run: 24/24 passed; see final-regression-results.json.

## Performance

`tests/benchmark_mesh_inspection.gd`: headless CPU measurements, 100 element ray queries aimed at the model, p95 latency. Preparation includes quality evaluation, exterior extraction, BVH, solid/edge buffers and one contour. Memory is Godot static allocation delta, not process RSS or GPU memory. FPS was not measured.

| Nodes | Elements | Mesh generation ms | Preparation ms | Pick p95 ms | Static allocation delta bytes |
|---:|---:|---:|---:|---:|---:|
|125|64|0.159|12.047|0.301|312584|
|729|512|1.19|83.078|0.715|1294992|
|4913|4096|6.092|557.677|0.646|7906192|

Preparation remains synchronous and can pause the UI for larger meshes. Sections rebuild rendering topology and the BVH, not numerical FEM data. Arbitrary section axes, continuous planar clipping, million-element performance and GPU memory profiling are not covered.

## Changed source files

* core/cae/mesh_display.gd
* core/cae/mesh_inspection.gd
* ui/cae/cae_workspace.gd
* tests/test_mesh_inspection.gd
* tests/test_mesh_result_integration.gd
* tests/benchmark_mesh_inspection.gd
* tests/capture_mesh_inspection.gd
* tests/native_regression_manifest.json
* docs/mesh-inspection/ (this report, measurements, summaries and captured images)
