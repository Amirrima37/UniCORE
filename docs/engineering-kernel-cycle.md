# Engineering kernel cycle: implemented capabilities and verification

This report supersedes the numerical limitations snapshot in `cae-recovery.md` for the capabilities listed below. The existing CAD workspace, mode controller, provider/AgentBrain, native physics cores and structural entry point remain in use. This is an incremental development build, not an ANSYS-equivalent or production-certified solver.

## Audit and foundation

Before this cycle the structural kernel contained only constant-strain TET4 stiffness and recovery. The mesh's HEX8 label described connectivity that was subdivided into six tetrahedra per cell, not a hexahedral formulation. Materials were untyped dictionaries with E, nu and density. Supports were full zero-displacement faces, loads were area-weighted total face forces, bodies were independent, and transforms were rejected. Sparse assembly used unordered-map rows and each PCG iteration traversed them. Units were SI internally, with mm/degrees editing in Godot.

Existing reusable implementations: gravity, molecular, nuclear, quantum, particle reductions, analytical primitive geometry/mass/inertia, worker cancellation, revision-aware project/result storage and field overlays. No Eigen, SuiteSparse, Gmsh or other numerical/meshing library was installed or introduced by this cycle. The numerical code uses C++17/STL and the existing pinned Godot 4.0 C++ bindings.

Logical separation now includes `native/src/math/sparse_pcg.hpp`, structural and thermal kernels under `kernels/`, source-backed JSON material records, validated GDExtension material and solver APIs, independent analysis meshes/boundary groups, and Godot orchestration/postprocessing. Unimplemented architecture branches remain requirements, not empty classes pretending to solve physics.

## Milestone 1: material library and validation

Changed: `data/materials/library.json`, `core/cae/material_library.gd`, `ui/cae/material_editor.gd`, `native/src/bindings/geometry_tools.*`, document and workspace material integration.

The library contains 33 named records across all requested material categories. **Six records have sourced numerical properties**: structural carbon steel, stainless 304/316, aluminum 6061-T6/7075-T6, and Ti-6Al-4V. The other 27 explicitly retain null properties; they are editable records awaiting a qualified grade/product/state and reliable sources, not analysis-ready defaults. Fluids/steam have no invented thermodynamic constants or validity envelopes. Reinforced concrete and timber retain composite/orthotropic model tags and cannot be passed to the isotropic structural solver as if equivalent to a metal.

The schema includes all requested mechanical, thermal, fluid and electromagnetic property keys and units; model type, property-source metadata, reference temperature, validity range where supplied, assumptions, and source URLs. Null means unspecified. NIST mechanical records use the published mean values, not design allowables. Independently measured G/K values are not mixed into an inconsistent E/nu law: derived G/K are calculated from E/nu and conflicting supplied isotropic values are rejected. There are no implemented temperature curves or damage/plasticity laws.

Verified sources:

- [NBS/NIST NSRDS-NBS-61 Vol. V](https://srd.nist.gov/NSRDS/NSRDS-NBS-61-V.pdf): tables 2/3/4 SI, alloy-property mean values. Example 6061-T6: density 2710 kg/m³, E=69.6 GPa, nu=0.331. These statistical reference values are not guaranteed product properties.
- [SCI steel material properties](https://steelconstruction.info/topics/design/steel-material-properties/): ambient E, nu and expansion. Density/strength are intentionally not filled from an unrelated generic value.
- [Outokumpu Core datasheet](https://www.outokumpu.com/en/products/product-ranges/-/media/files/products/core/outokumpu-core-range-datasheet.pdf): table 7, 304/4301 reference properties.
- [Outokumpu Supra datasheet](https://www.outokumpu.com/-/media/files/products/supra/outokumpu-supra-range-datasheet.pdf): table 7, 316/4401 reference properties. These stainless records supply conductivity, density and heat capacity for thermal studies but **do not supply nu**. Structural readiness therefore reports nu missing instead of inventing it.

Use **Materials → Library / custom materials**. Search, inspect/edit the SI JSON definition, duplicate, create, save custom records to user storage, import/export JSON, and assign a complete snapshot to a body. This is a schema-level editor, not a polished form for every constitutive model. Native `validate_material(material, analysis)` distinguishes valid definitions from analysis readiness and returns missing keys/errors. Assignments persist with sources, trigger project revisions, and invalidate dependent results. Legacy materials without new metadata remain accepted.

Validation: `test_materials_thermal_ui.gd` checks library search, custom definition creation, assignment, source persistence, native missing-nu detection, unsupported orthotropic mechanics, thermal solving and save/reopen. Values imported from uncurated records remain blocked from analyses requiring them.

## Milestone 2: structural formulation, transformations and boundary conditions

Changed: `kernels/structural_solver.hpp`, structural bindings, shared `math/sparse_pcg.hpp`, document commands and `ui/cae/analysis_editor.gd`.

The same solver now accepts TET4 and a real trilinear HEX8 formulation with **full 2×2×2 Gauss integration**, Jacobian/gradient transformation, 24-DOF stiffness, and center stress/strain recovery. No reduced integration/hourglass stabilization is claimed. TET4 retains its constant fields. Both formulations share sparse assembly, CSR-compressed PCG iteration, prescribed-value elimination, residual checking and reaction recovery. A per-component rigid-mode rank check rejects underconstrained components, including zero-load cases that might otherwise return a misleading zero displacement. Inverted/degenerate cells are rejected. Symmetric-tensor principal stresses are recovered with a small Jacobi eigenvalue iteration.

Positive physical scale and Godot-compatible Y-X-Z Euler rotation are incorporated into **solver node coordinates**. Geometric face IDs stay local to the part; force/gravity/prescribed-displacement vectors are global. Bodies remain independent, including touching bodies. There is no automatic bonding/contact.

Supported conditions:

- Fixed face: all three global components zero.
- Prescribed face displacement: all three global values in metres; conflicting constraints are rejected.
- Total face force: consistent area distribution, with uniform quad weights for HEX8 and triangle weights for TET4.
- Pressure: Pa, positive inward along the actual transformed outward face normal.
- Gravity: global m/s², requiring positive density; volume-consistent nodal body force.

### Measured structural validation

`native/tests/hex8_test.cpp`: unit-cube volume/Jacobian, Gauss integration, stiffness symmetry, six rigid modes, affine strain patch, principal stresses under pure shear, inverted connectivity and underconstraint rejection. `test_structural_expansion.gd`: exact uniaxial displacement, pressure sign, rotated-force invariance, physical scale effect, nonzero displacement constraints, gravity reaction balance and bending convergence. The legacy structural suite still passes.

| Cantilever resolution per axis | HEX8 maximum displacement (m) | Difference from Euler–Bernoulli |
|---|---:|---:|
| 2 | 3.47891463e-6 | 70.78% low |
| 4 | 7.39687375e-6 | 37.87% low |
| 8 | 1.043760827e-5 | 12.32% low |
| 16 | 1.170200671e-5 | **1.70% low** |

Reference: 1×0.2×0.2 m beam, E=210 GPa, nu=0.3, transverse 1000 N, fixed end; Euler–Bernoulli displacement 1.19047619e-5 m. The regression requires the 16-division value to lie within 3% of that reference. The coarse TET4 8-division value remains 8.07376094e-6 m, about 32% low. Thus the existing bending limitation is improved for this benchmark with refinement; it is **not universally resolved**. The reference excludes clamp/shear effects, and stress maxima at clamped edges need separate convergence treatment.

The nu=0 axial cube (E=1000 Pa, total force=100 N, area/length=1) gives u=0.1 m with reported relative displacement error zero at printed precision. Rotation/scale and pressure tolerances are 1e-7 m; reaction balance tolerance 1e-6 N. Solver residual tolerance is checked independently from the recursive CG estimate.

## Milestone 3: mesh metadata and actual postprocessing

The native box mesher remains independent of Godot rendering meshes. It now returns transformed nodes, HEX8 cell connectivity, material/body region IDs, local named-face boundary groups and quality metadata: minimum Jacobian, aspect ratio, total volume, inverted/degenerate counts, component count and warnings. For these structured affine boxes, volume/Jacobian/aspect checks are exact analytical geometry checks, not a claim of general warped/imported mesh validation. HEX8 integration independently checks determinants at each Gauss point.

Limits remain 16 divisions per axis and 10,000 total nodes. AI `GenerateMesh(target_size)` converts positive metres to a uniform-per-axis grid whose largest spacing is no greater than the request; it rejects requests beyond the limit. No local refinement or adaptive mesh engine is implemented. Multiple bodies are explicitly reported disconnected.

**Simulation → Study / boundary setup** selects supported analysis/formulation and edits actual geometric boundary conditions. Unsupported analyses are not enabled. Conditions can be cleared on the selected body. The tree/status show validation issues and mesh statistics/quality. **Results** exposes real displacement, von Mises, temperature, probes and JSON field export. Stress visualization is an elementwise edge overlay, with unaveraged center values; it is not a smoothed stress surface. Structural probes/export include tensor/principal values and reactions. Temperature uses the external faces of the actual TET4 mesh, with linear nodal interpolation and no hidden interior-face overdraw. Blue/red bounds and units are displayed.

Gmsh was evaluated at the interface level: its [official site](https://gmsh.info/) supplies a Windows SDK and describes GPL/commercial distribution terms. Its ABI, redistribution/packaging and project licensing compatibility have **not** been validated, so it was not embedded or downloaded as a new dependency. Eigen/SuiteSparse/PETSc remain candidate evaluations in the registry, not installed dependencies.

## Milestone 4: independent thermal domain

Changed: `kernels/thermal_solver.hpp`, `bindings/thermal_solver.*`, registration/capabilities, analysis/document commands, worker dispatch, thermal probes/contours/history.

Steady conduction uses scalar linear TET4 stiffness `k V grad(N_i)·grad(N_j)`, consistent volumetric sources, prescribed temperatures, inward heat flux, and consistent triangular convection matrices. Heat flux recovery is `-k grad(T)` per tetrahedron. Each disconnected steady body requires a temperature or positive convection anchor; pure unreferenced Neumann problems are rejected. Kelvin, W/m³, W/m² and W/m²/K are explicit. Temperature constraints that conflict at a shared node are rejected.

Transient conduction uses lumped rho*cp capacity and backward Euler. Settings require positive dt, 1–200 integer steps and nonnegative initial Kelvin temperature. Returned history contains sampled complete temperature fields/times, final heat flux/reactions, residuals and discrete energy-balance information. History temperature frames can be viewed; flux probes remain explicitly final-time. Cancellation is checked in assembly and linear iterations. Properties are constant reference values, not temperature-dependent laws. Out-of-range/unspecified-temperature applicability is flagged in results; material curves and thermal-structural transfer remain unimplemented.

Measured checks (`test_native_thermal_suite.gd`):

| Case | Measured result / acceptance |
|---|---|
| Unit slab, k=10, 300/400 K ends | max linear-profile error ~4e-13 K; tolerance 1e-6 K |
| Fourier heat flux | -1000 W/m² axial, transverse near zero; tolerance 1e-5 W/m² |
| Steady energy balance | ~1.3e-12 W; tolerance 1e-5 W |
| k=10 slab plus h=10 convection | exposed surface 350 K; tolerance 1e-5 K |
| Inward 100 W/m² with 300 K opposite face | maximum 310 K; tolerance 1e-5 K |
| Insulated uniform heating, Q=20, rho*cp=10, t=1 s | 302 K; tolerance 1e-6 K, discrete energy tolerance 1e-5 W |
| Transient nonuniform slab, diffusivity=1, 8 divisions, dt=.001, t=.05 | center differs from Fourier series 377.231160686 K by **0.663877605 K**; tolerance 1.5 K |
| Missing anchor, cancellation and recovery | explicit errors / successful recovery |

This is limited benchmark coverage for a development thermal solver. It does not establish general transient convergence, temperature-dependent behavior, fluid convection or coupled multiphysics accuracy.

## Milestones 5–7: supported workflow, existing AI and preserved long-term scope

The existing AgentBrain now understands validated material assignment by library name, structural/thermal setup commands, global target mesh size, SolveAnalysis, and CreateResultView. Commands share the manual document definitions and the same worker kernel. Model batches remain atomic; unsupported physics, invalid units/parameters, stale responses and missing conditions are rejected. The AI cannot supply a fabricated field or substitute a different physics type. `test_cae_analysis_commands.gd` checks a full material→thermal conditions→mesh→worker solve→temperature view command batch. Provider-driven CAD tests use the existing mock transport; live provider accuracy is not claimed.

`data/engineering_capabilities.json` preserves **59 reference families** across all previously supplied domains, including the specialized structural/fluid/electronics/semiconductor/optics/system/platform tools. Each record lists purpose, methods, reusable infrastructure, missing infrastructure, library candidates, dependencies, priority, validation requirements and current status. Product names are capability references only. CFD, modal/dynamic/nonlinear mechanics, contact/fatigue, electromagnetic and optical solvers remain unavailable. No dummy controls claim they work.

## Build and regression evidence

Both Windows x86-64 debug/release DLLs were rebuilt with `native/build_direct.ps1` against the pinned Godot C++ archives. No new external numerical dependency was introduced. `native/run_regressions.py` now includes the engineering cycle in its manifest and fails on script runtime errors even when a script returns exit code zero. This uncovered a pre-existing detached-scene sandbox camera lookup; its guard was fixed without changing physics calculations.

The explicit 22-script manifest covers original physics/integrators/interactions/native domains plus structural/thermal/material/UI/AI/navigation checks. Logs and JSON results: `.tools/engineering-cycle-regression/`. Standalone C++ tests cover TET4, HEX8 and geometry metrics. Native tests execute on the updated debug library; the release binary is built but not a separately exported application certification.

Rendered captures were inspected with the actual OpenGL compatibility renderer: `.tools/thermal-results.png` and `.tools/engineering-materials.png`. Known Godot 4.0 headless dummy-renderer `mesh_get_surface_count` teardown diagnostics remain; the graphical capture has no script/runtime errors. Existing negative-input tests can intentionally emit errors; the runner records those separately from script exceptions.

Heavy solving stays on a worker and changes no scene objects there. Native phase reporting distinguishes meshing/validation, assembly, linear solve and recovery; the UI polls at most five times per second. The CAD cache, hidden viewport disabling and AI Sandbox mode controller are retained.

## Remaining work and next gates

- Qualify the 27 incomplete material records with product/state/temperature-specific primary data; implement their required constitutive laws rather than defaulting to metal elasticity.
- Connected interfaces/contact and curved-volume meshing; local/adaptive refinement and imported-mesh quality/connectivity validation.
- Beam/truss/shell and higher-order elements; stronger bending and stress convergence campaigns; modal and transient structural methods.
- Temperature-dependent data interpolation, more spatial/time thermal benchmarks and verified one-way thermal expansion transfer.
- A dedicated conservative incompressible laminar CFD foundation with Poiseuille/cavity and conservation benchmarks. **No CFD solver was added in this cycle.**
- Professional material form editors, stress surfaces, vector arrows, section views and remote execution. The JSON material editor is functional but intentionally schema-level.

The current implementation closes the defined material/static-structural development-cycle foundation and continues into a validated independent thermal milestone. It does not finish the broader multiphysics roadmap.

## Mesh inspection increment (2026-11-10)
Added `core/cae/mesh_inspection.gd`, extended `mesh_display.gd`, integrated Mesh inspection menu in `cae_workspace.gd`, and added `tests/test_mesh_inspection.gd`.
Exterior ray/triangle picking reports zero-based element connectivity, exposed-face nodes, SI coordinates, material region, boundary membership and local quality. Node picking requires proximity within 14 pixels. Quality surfaces use actual element-centered values with numerical blue/red bounds. Metrics: signed volume, minimum sampled determinant, edge-length aspect ratio and explicitly defined scaled-Jacobian distortion. HEX8 uses eight Gauss samples; these do not certify positivity everywhere in a warped element. TET4 determinant is constant; its corner scaled Jacobian is ordering dependent. Inversion and scale-relative degeneracy flags are inspection diagnostics.
Headless analytical unit cube/tetrahedron, inverted/degenerate tetrahedron, shared-face removal and contour construction tests passed in Godot 4.0. No native code changed or native rebuild performed. Graphical Vulkan editor launched, but cache write restrictions caused errors; interactive picking and contour appearance are not visually verified. Surface extraction/metrics are cached; ray picking remains linear in exposed triangles. Interior node picking, selection highlighting, a continuous graphical color bar, IDs and large-mesh spatial acceleration remain outstanding.
