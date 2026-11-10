# UniCORE engineering tools

Current numerical/material capabilities are documented in [Engineering kernel cycle](engineering-kernel-cycle.md). The recovery report below is a historical milestone snapshot.

Use the persistent **AI Sandbox / CAE Workbench** selector beside the UniCORE logo. **Back to AI Sandbox** and Escape return to the sandbox without discarding the engineering document. See [Recovery implementation and acceptance results](cae-recovery.md) for the current UI, camera controls, AI integration, measurements, and verification. These are UniCORE implementations; no Ansys product or solver is embedded.

## Available structural workflow

1. Create a **Box** in Geometry. Set dimensions in metres and click Apply dimensions.
2. Set Young's modulus in Pa, Poisson ratio, and density in kg/m³. Click Assign elastic material.
3. Select a box face by clicking it in face selection mode or choosing X-/X+/Y-/Y+/Z-/Z+. Click Fixed support.
4. Choose a loaded face, set the force vector in N in the inspector, and click Apply force. The vector is the **total face force**, distributed as uniform traction using consistent triangle area weights.
5. Generate a volume mesh. Divisions apply to each axis. Native meshing supports 1–16 divisions, 1–16 separate boxes, and at most 10,000 total nodes. Bodies remain disconnected and each needs its own fixed face.
6. Click Solve. C++ runs on a worker thread using a copied project snapshot. Cancel stops assembly/iteration; another solve can then run. Editing while solving prevents that older result from replacing current results.
7. Results shows displacement as colored deformed mesh edges over the undeformed solid. Blue means zero displacement; red means the current maximum, reported in metres. Set explicit magnification in Results. Inspector probes expose nodal displacement and reaction vectors, element stress, engineering strain and von Mises stress. Stress is constant per tetrahedron and is **not averaged**.
8. Save/Open .ucae files preserve model, mesh, results and diagnostics. Edited geometry, material, loads, support or changed mesh resolution makes old results unavailable for current-model display. Modeling commands support Undo/Redo.

Boxes, cylinders, spheres and hollow pipes support parametric modeling, transforms and persistence. Only unrotated, unscaled boxes can be structurally meshed/solved in this implementation. Sphere X is diameter; cylinder X is diameter and Y is height. Box X/Y/Z are its dimensions. Position editing and duplication are available. Right drag orbits; wheel zooms; Fit model accommodates translated bodies.

## Native implementation

- `native/src/kernels/structural_solver.hpp`: engine-independent double precision linear elasticity, constant-strain TET4 formulation, sparse assembly, Jacobi-preconditioned conjugate gradient, zero-displacement constraints, residual/reaction and stress/strain recovery.
- `native/src/bindings/structural_solver.*`: GDExtension input validation, box grid generation, six tetrahedra per hexahedral cell, consistent surface forces, structured error codes, cancellation and tool catalog.
- `UniCoreStructuralSolver.generate_mesh(project, divisions)` returns `{ok, mesh}` or `{ok:false, error}`.
- `solve_model(project)` regenerates trusted connectivity from geometry and mesh divisions; returns revision, backend, nodes, tetrahedra, displacement, reactions, stress, strain, von Mises, residual and iteration count.
- `cancel()` and `reset_cancel()` support worker lifecycle. Do not call multiple solves concurrently on one solver instance.
- `get_tool_catalog()` describes supported scope across domains.
- GDScript retains document/history, interface, background-job orchestration and rendering. Native capability flags include structural_solver, structural_api_version=1 and box_volume_mesher.

The normal build remains `native/build.ps1`. In this environment its SCons dependency is unreadable. `native/build_direct.ps1 -Target template_debug` (or template_release) compiles all bindings against the already built, pinned Godot C++ libraries using the existing Qt MinGW compiler. Both updated DLL configurations are built. Restart an already-running Godot process to load the new classes.

## Verification and limits

- Standalone C++ test: affine strain patch, six element rigid modes, element volume and invalid material rejection.
- Native bridge test: exact uniaxial cube with E=1000 Pa, nu=0, area=1 m², length=1 m, force=100 N. Expected displacement=0.1 m, stress=100 Pa, total reaction=-100 N; displacement tolerance 1e-8 m and reaction tolerance 1e-6 N.
- Cancellation, recovery, missing support/material rejection and save/reopen solve reproducibility.
- UI test: worker completion, result overlay/probes, stale-result suppression and Undo restoration.
- Cantilever diagnostic, 1 × 0.2 × 0.2 m steel beam, E=210 GPa, nu=0.3, 1000 N transverse force: divisions 2/4/8 give 1.59023e-6 / 4.19286e-6 / 8.07376e-6 m maximum displacement. Euler–Bernoulli tip reference is 1.19048e-5 m. This shows refinement trend, **not adequate bending accuracy**: the coarse TET4 formulation is stiff and the last measured value remains about 32% low. The beam reference also excludes shear and clamp effects. No production accuracy or full solver verification is claimed.
- Stress near clamp edges can be singular. Maximum stress is not a convergence criterion.
- Headless Godot's dummy renderer emits mesh_get_surface_count errors for mesh rendering; numerical checks and UI lifecycle tests run separately from graphical validation.

Run `.tools/structural_solver_test.exe`, or compile native/tests/structural_solver_test.cpp with the kernel include path. Godot scripts: `tests/test_native_structural_suite.gd`, `tests/test_native_structural_ui.gd`, `tests/test_cae_workspace.gd`. Existing gravity and particle metric regressions also pass with the rebuilt debug library.

## Remaining domains

The existing native gravity, molecular, quantum and nuclear studies are accessible in AI Sandbox mode. They do not simulate solids from the structural document. CFD, electromagnetics, semiconductor signoff, optics, fatigue, impact, nonlinear mechanics, thermal analysis, optimization and digital twins require their own implementations; their catalog entries explicitly say Not implemented. Advanced CAD, pressure/prescribed displacement, edge/vertex selections, result export and remote solving also remain future work. This change implements the first local structural tool and shared menu/bridge foundation, not the complete product portfolio in the reference list.
