# Stage 7 — Advanced Physics & Solver Expansion

## Godot 4.7.2 Workbench migration — 2026-11-13

The existing Workbench now launches graphically with the supplied 4.7.2 runtime and rebuilt GDExtension. Actual 1280×720 and 1920×1080 captures show the existing shell, geometry, mesh, backend, displacement and von Mises views for real Box/Cylinder Gmsh → CalculiX studies. The 28 default regressions pass; four native build configurations pass 3,132 assertions; the extended transient/modal numerical campaign passes 31,615 assertions; five shell startup/shutdown cycles exit 0. This is a **PARTIAL migration**: imported STEP → CalculiX remains a separate incomplete feature, and exhaustive interaction coverage is pending. See [migration evidence](../architecture/GODOT_4_7_2_MIGRATION.md).

## CalculiX Workbench campaign — 2026-11-13

**PARTIAL overall acceptance; actual block/cylinder vertical workflow delivered.**
Real Gmsh meshes now reach CalculiX through the existing Workbench; off-main-thread
solve, owned cancellation/timeout receipt, actual displacement/stress rendering,
save/reopen/stale-data checks and Vulkan screenshots at both resolutions exist.
28/28 post-integration regressions have recorded exit 0. Axial error 5e-8;
same-mesh Extreme displacement/stress agreement ~2e-7; bending refinement improves
but finest error remains 15.86%. See current
[evidence and limitations](../architecture/CALCULIX_CHECKPOINT2.md). Native modal,
transient, static and thermal implementations remain preserved. No historical
crash-resolution claim is made.

## External CalculiX checkpoint 2 — PARTIAL

Real native Windows CalculiX 2.23 installed and executed; canonical TET4 exporter
and integration-point DAT parser pass analytical patch and E/F scaling checks.
Workbench selection/visualization, Gmsh production mesh path and full lifecycle
acceptance remain incomplete. See [checkpoint evidence](../architecture/CALCULIX_CHECKPOINT2.md).
Native modal/transient checkpoints and historical crash evidence remain intact.

## External-engine migration checkpoint (2026-11-12)

Architecture migration started in the same dirty working tree. See
[validation matrix](../architecture/VALIDATION_MATRIX.md). Phase A/B PARTIAL:
real Gmsh 4.15.2 SDK execution, OCCT volume-6 block and 932 TET4 smoke,
initial backend contract and Workbench dependency status. No external physics
backend is Workbench integrated. Previous native checkpoints and crash evidence
are preserved; this checkpoint makes no crash-resolution claim.

Latest: **Checkpoint 2 PASS for bounded native constrained TET4 transient dynamics**; see its section below. Stage 7 remains in progress. Structural restart and transient Workbench UI are deferred; the historical Godot crash remains unresolved.

## Checkpoint 1 — Native modal structural analysis

**PASS — CHECKPOINT 1 COMPLETE**, for the bounded native constrained TET4 scope below. Only modal analysis is in scope. No transient structural, harmonic, buckling, nonlinear, CFD or electromagnetic implementation has begun. Workbench modal UI is deferred. Stage 6's historical crash verdict is unchanged.

### Repository continuity and audit

Root: `C:/Users/Victus/Desktop/UniCORE-main`. Branch `master`, HEAD `13e40a5a565a273485aa80ea14ed110df36136a2`. The existing working tree already contained substantial tracked and untracked Stage 4–6 work. [Initial status, HEAD and hashes](stage7-checkpoint1/baseline.json) and baseline copies of the three modified Extreme infrastructure files are retained. No repository creation, reset, checkout or cleanup was performed.

Read the Stage 4, Stage 5, Stage 5.1, Stage 6 and crash investigation records. Stage 6 remains **FUNCTIONAL PASS — STABILIZATION BLOCKED**. Historical `0xc0000005`, Godot executable offset `0x518504`, remains **UNRESOLVED**. Standalone numerical work does not change that verdict.

Audit: `native/src/kernels/structural_solver.hpp` defines node coordinates, TET4/HEX8 connectivity, isotropic E/nu and DOF order `3*node+[x,y,z]`. TET4 stiffness uses positive determinant >1e-24, constant engineering-strain B, isotropic 3D D, and volume integration; HEX8 uses validated 2×2×2 Gauss integration and center stress recovery. Static solve assembles sparse hash rows, checks constrained rigid-body rank per component, then delegates to free/free PCG with prescribed-displacement RHS contributions. Existing defaults are 20,000 PCG iterations, relative/absolute 1e-10, post-check residual 1e-7. None of these existing calculations or defaults was edited.

Reused: TET4 stiffness and geometry validation, structural rigid-mode constraint rank validation, sparse assembly representation, CSR interface and IC(0)/Jacobi preconditioner, finite-number parser, output ownership/atomic publication, memory/cancellation monitor, version-1 fingerprint fields and regression infrastructure. New: consistent structural mass, explicit free-DOF modal reduction, sparse block eigensolver, version-2 modal parsing and computed modal serialization. The modal inner linear solve has a separately configured tolerance and does not modify static/thermal solver options.

Material audit: `data/materials/library.json` already declares SI density in kg/m^3; some records deliberately contain null density. `core/cae/material_library.gd` delegates material validation to the native validator. Existing static native job rows serialize only E and nu, while transient thermal rows contain volumetric heat capacity. Modal rows require a separate positive finite density; legacy static/thermal jobs remain valid and receive no invented density. No shared material ABI or library record was changed.

### Mathematical architecture and implemented scope

The constrained generalized eigenproblem is K_ff phi = lambda M_ff phi. TET4 stiffness calls the unchanged structural element routine. Consistent mass is rho*V/20 times the four-node scalar matrix with diagonal 2 and off-diagonal 1, expanded with the identity in the three translational components. Different components have zero mass coupling. Physical integrated mass is reported once per body, not the sum over three translational directions.

Homogeneous fixed DOFs are removed from both matrices. Full output vectors restore exact zeros at constrained DOFs. Nonzero prescribed values, static excitation, free-free/underconstrained components, invalid density/geometry and unsupported cells reject. No penalty support or hidden stiffness is introduced. Support reactions are not part of the free-DOF eigenpair residual.

TET4 modal is implemented. HEX8 modal is explicitly deferred despite the existing validated static integration scheme: a separate mass integration and its tests were not included in this bounded checkpoint. Free-free modal is deferred because the inverse iteration needs nonsingular positive-definite K. No six-rigid-mode result is fabricated. Workbench modal controls/import/rendering are deferred; the user-facing Workbench remains structural/thermal.

### Eigenvalue algorithm

`native/src/math/symmetric_modes.hpp` implements bounded sparse block inverse iteration on K^-1 M with mass reorthogonalization and a Rayleigh–Ritz projection. The deterministic starting block uses a fixed integer PRNG seed, with dimension min(active DOFs, max(2*requested_modes, requested_modes+6)). Two-pass mass Gram–Schmidt controls loss of orthogonality. Each inverse action is an IC(0)-preconditioned CG solve; existing explicit fallback to Jacobi is reported. There is no assembled dense inverse and no full dense FEM eigendecomposition. Cyclic Jacobi operates only on the at-most-24-dimensional Ritz matrix. The algorithm is a custom implementation, not a wrapped/vetted third-party eigensolver. It is intended for bounded supported problems, not an unrestricted industrial spectral backend.

Inner recurrence tolerance is 1e-12 relative to RHS; explicit true-residual acceptance is 1e-9. A first slender-beam attempt exposed recurrence drift and correctly failed `MODAL_INNER_TRUE_RESIDUAL`. Modal CSR multiplication now accumulates in long double and CG replaces/restarts from the true residual if the recurrence falsely reports convergence. Neither threshold was relaxed. The failed attempt remains in `numerical-attempt1/`.

Matrix construction checks finite entries, symmetry and positive diagonals. The structural input additionally enforces positive material stiffness, nondegenerate TET4 and constrained rigid modes; CG checks positive curvature. Mass-inner-product checks reject invalid/rank-deficient subspaces. This is not a full sparse inertia certificate for arbitrary supplied matrix pencils or pathological hinged meshes. Nonconvergence, curvature/rank failure, invalid eigenpairs, wall timeout and cancellation return explicit errors. A matching small dense independent reference is used only in tests.

Modes are sorted by ascending eigenvalue, mass normalized (phi^T M phi=1), and signed so the largest absolute component is positive. Repeated eigenvectors need not be unique; tests compare the invariant subspace using mass-weighted singular values. The returned generalized residual is independently computed as ||Kphi-lambda Mphi||/(||Kphi||+abs(lambda)||Mphi||); nonpositive/nonfinite eigenvalues and invalid/zero denominators reject. Orthogonality is checked at 1e-9 before publication. Relative shapes have units kg^-1/2 under this normalization, and are not physical operating displacement amplitudes.

### Job and result formats

Existing `UNICORE_JOB 1` and `UNICORE_STATE 1` grammars remain unchanged. The new grammar is:

```text
UNICORE_JOB 2 modal_structural
node_count element_count
x y z                         # node_count rows, SI meters
4 n0 n1 n2 n3 E nu density     # element_count rows; zero-based IDs; Pa, -, kg/m^3
fixed prescribed              # 3*node_count rows in xyz order; fixed=0/1; prescribed=0
MODAL requested_modes iteration_limit residual_tolerance wall_limit_seconds
```

Comments above explain the layout and are not accepted input syntax. Modal jobs do not contain static force columns, thermal surface rows or the version-1 SOLVER trailer. Unknown/trailing fields, fractional counts, unsupported version/type combinations and out-of-range settings reject. CLI static linear overrides and modal pause/restart reject explicitly. Modal checkpoint/restart is unsupported; thermal checkpoint behavior is preserved.

Results retain the existing outer schema/provenance fields and add `modal_schema:1`, exact `job_sha256`, mode index, lambda in rad²/s², omega in rad/s, frequency in Hz, full original-node-order displacement eigenvectors, generalized residual and convergence status. They include coordinates, connectivity, per-element E/nu/density, active original DOF IDs, normalization/units, matrix sizes, iteration counts and timings. Existing FNV input identity remains alongside SHA-256. Windows system CNG (`bcrypt`) computes the modal SHA-256; this is a system library linked by the existing direct/CMake builds, not a new third-party runtime package. SHA protects byte identity, not an adversarially signed result. No modal output is passed through the existing structural-only Workbench importer.

Modal inputs are copied into a bounded **8 MiB immutable binary snapshot** before numerical parsing. Header, numeric fields and trailer are parsed from that same snapshot; both FNV and SHA-256 describe those exact bytes. Editing the source path later cannot relabel old computed modes with the edited job's identity. Consumers must compare the result digest to the job/snapshot being requested, as the existing Workbench importer does for its supported analyses. A prospective modal UI importer must retain this requirement. Legacy version-1 parsing remains on its original stream path.

Final review identified and corrected a potential edit-during-solve provenance race before acceptance. The first snapshot build failed Windows CRLF input because a text-mode stream translated bytes; that failed process and build are retained under `builds-snapshot-final/`. Snapshot reads now use a separate binary stream and tests cover both LF and CRLF. `builds-verified/` supersedes earlier directories with `final` in their names for the final production source state.

### Bounds and verification plan

Hard bounds: 2,000 nodes / 6,000 full DOFs, 12,000 TET4, 1–12 modes, 1–500 eigen iterations, at most 20,000 CG iterations per inverse action, positive wall limit <=60 seconds, residual tolerance 1e-9–1e-5. Normal validation requests 1e-7. Allocation estimates and the existing process working-set budget/cancellation monitor remain active. Native tests configure 256 MiB and one thread. Peak working set comes from Windows GetProcessMemoryInfo, not Godot counters.

Verification includes exact matrix pencils and repeated subspaces, independent Python affine-basis FEM assembly, SciPy LAPACK/ARPACK generalized spectra, mass/scaling checks, slender cantilever refinement, an exactly compatible longitudinal continuum reference, actual Stage 6 cylinder meshes, invalid inputs, cancellation/recovery, all four native builds, legacy jobs and the complete existing default manifest. NumPy/SciPy are test-only dependencies already installed in this environment; the shipped executable does not depend on Python. [SciPy generalized eigensolver semantics](https://docs.scipy.org/doc/scipy/reference/generated/scipy.linalg.eigh.html); [cantilever reference assumptions](https://emweb.unl.edu/mechanics-pages/scott-whitney/325hweb/beams.htm).

### Final numerical acceptance — 2026-11-12

The final source state is identified by [source SHA-256 hashes and summary](stage7-checkpoint1/summary.json). Direct solver verification uses NumPy **2.5.2** and SciPy **1.18.1** only in the test environment. Python independently derives TET4 shape gradients by inverting the affine interpolation matrix, assembles K and M with SciPy sparse matrices, eliminates the specified DOFs, and computes reference spectra using LAPACK generalized `eigh` for small systems and ARPACK shift-invert with SuperLU for larger fixtures. This does not reuse the native element B matrix, native inverse action or native eigensolver.

The C++ matrix/mass test exits 0 with **582 checks / 0 failures**. Cases include a non-diagonal generalized pencil with known repeated eigenvalues 2,2,9; independent repeated-eigenspace projections; the known sine spectrum of a 30-row Dirichlet second-difference matrix with M=3I; deterministic ordering/sign-normalized repeatability; symmetry, indefinite K, rank-deficient M, nonfinite entries, nonconvergence, cancellation and wall-time rejection. Mass checks cover total integrated translational mass, symmetry, component blocks, positive quadratic forms, translation, even node permutation and cubic geometric scaling. The initial test compilation had a mixed float/double initializer-list error; explicitly typed invalid-density test values corrected that test-only issue. Numerical fixture thresholds were not relaxed.

[Final numerical receipt](stage7-checkpoint1/numerical-verified/results.json): **40 operations, 5,995 Python assertions**, including expected negative process exits and per-element volume checks; this is not 5,995 independent physical benchmarks. [Mixed-material receipt](stage7-checkpoint1/materials-verified/results.json): **3 operations, 52 assertions**. [Provenance receipt](stage7-checkpoint1/provenance-verified/results.json): **2 operations, 8 assertions**. All three outer validation invocations exit 0. The C++ test compile/execute takes 7.672 / 1.340 seconds; the headless real-mesher fixture exits 0 in 1.397 seconds. No Godot script errors appeared in that fixture.

Every positive modal job checks node/connectivity correspondence, exact-zero constrained components, units, positive frequencies, SHA-256 against the exported bytes, integrated physical mass, independent mass orthogonality, Rayleigh energy, explicitly recomputed eigenpair residual and an independently solved FEM spectrum/subspace. Maximum observed relative eigenvalue disagreement in the main numerical sweep is approximately **7.66e-10**; maximum independently recomputed residual is **6.63e-8**, below the predeclared 1e-7 target. The mixed E/nu/density-per-element fixture agrees within **9.74e-11** in eigenvalues and has maximum residual **7.16e-8**. Same-input FEM vectors reproduce exactly within the same configuration; no arbitrary sign comparison is imposed on the independent reference vectors.

Physical scaling tests use all three requested modes: E×4 gives f×2, rho×4 gives f×0.5, and all coordinates×2 gives f×0.5, within the predeclared 1e-7 ratio guard. Twelve requested modes are also solved and compared independently. These are genuine mass-dependent FEM results.

#### Cantilever and compatible continuum references

The solid cantilever has L=1 m, square side 0.05 m (L/side=20), E=2e9 Pa, nu=0.3, rho=1000 kg/m³, a fully fixed root face and otherwise traction-free boundary. Euler–Bernoulli assumes slender, small-strain bending without shear deformation/rotary inertia; its first frequency is **11.422608 Hz**, using beta=1.875104068711961 and I/A=side²/12. A 3D elastic root boundary and shear effects differ slightly from that idealization. More significantly, coarse linear TET4 meshes over-stiffen bending. The two lowest FEM modes are reported separately because mesh anisotropy splits the continuum bending pair.

|Cross-section subdivisions / axial layers|Nodes / TET4|First two FEM frequencies Hz|Maximum relative error against EB|
|---|---:|---:|---:|
|1 / 10|44 / 60|30.110120 / 34.936321|205.852%|
|2 / 20|189 / 480|18.217485 / 20.475172|79.251%|
|3 / 30|496 / 1620|14.889698 / 16.181578|41.663%|

**The finest bending mesh is not an accurate engineering beam model.** Acceptance here is the predeclared decrease in continuum-reference error plus independent agreement with the assembled 3D FEM eigenproblem, not an invented post-hoc absolute match. No beam accuracy tolerance was relaxed or tuned after observing these values. This validates eigensolver correctness and refinement direction; further mesh refinement or better bending elements are required for precise cantilever predictions.

A second reference avoids the 1D/3D bending mismatch: a homogeneous longitudinal bar with nu=0, ux=uz=0 throughout, uy=0 at the root and a traction-free tip. Its axial-invariant 3D continuum solution has f1=sqrt(E/rho)/(4L)=**353.553391 Hz**. Those transverse constraints are explicit, not hidden supports in the bending problem.

|Axial layers|Computed f1 Hz|Relative continuum error|
|---|---:|---:|
|4|355.794978|0.634017%|
|8|354.106930|0.156564%|
|16|353.690312|0.038727%|

The error decreases and passes the predeclared finest-grid 0.2% guard. A consistent linear axial discretization has second-order frequency error; this guard is deliberately wider than the expected small-grid interpolation error. The smaller algebraic residual is not substituted for these continuum discretization errors.

#### Real Stage 6 geometry and lifecycle

`tests/export_stage7_modal_meshes.gd` uses the actual accepted document/cylinder mesher at diameter=0.2 m and length=0.2 m. It verifies deterministic repeated nodes/connectivity and positive quality, then exports densities 1,2,3 without introducing modal Workbench production code. Python independently checks every TET4 volume and uses the actual Bottom IDs as homogeneous constraints. E=2e9 Pa, nu=0.25, rho=7800 kg/m³. Polygonal geometry changes with density; the following frequencies are a mesh-refinement observation, not a circular-cylinder analytical reference.

|Density|Nodes / TET4|Active DOFs|First three frequencies Hz|
|---|---:|---:|---|
|1|27 / 48|54|310.976388 / 317.469996 / 612.823284|
|2|125 / 384|300|278.681668 / 279.861305 / 464.004530|
|3|343 / 1296|882|267.192685 / 267.609528 / 430.548441|

Refinement increments decrease; all three spectra/masses agree with independent FEM assembly. A repeated density-3 solve reproduces the vectors exactly. The archived exported mesh bytes are in [final numerical fixtures](stage7-checkpoint1/numerical-verified/stage6-cylinder-meshes.json). Sphere/pipe-specific modal cases were not run; no modal acceptance claim is added for those geometry workflows.

Invalid density (zero, negative, NaN, infinity), invalid E, nonzero prescribed displacement, free-free input, all-constrained input, inverted elements, fractional/out-of-range mode counts, invalid fixed flags, excessive node count, unsupported HEX8, version/type mismatch, trailing data, invalid/expired wall bound and forced eigen nonconvergence all reject with exit **2**. The valid HEX8 negative fixture specifically reports `MODAL_HEX8_DEFERRED`. A pre-existing cancel request exits **3**. A separate bounded test observes phase 4 during an actual eigensolve, requests cancellation, gets exit **3**, verifies ownership-lock removal/no published result, and launches another valid solve successfully. No orphan solver process remained at final inspection. Cancellation does not imply a restartable modal checkpoint.

The edit-during-solve test changes E in the source file after observing eigen-solution phase 4. The process completes normally against its immutable snapshot in **2.119 s**. The result preserves the original E and original SHA-256; comparison against the edited current file fails, as required. The original snapshot is archived next to the deliberately edited input. LF-only and Windows CRLF inputs both pass exact-byte identity checks. This tests the new native proof contract; it does not claim an unimplemented modal Workbench importer.

### Final native build matrix and compatibility

Existing compiler/toolchain: `C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe`, GCC **13.1.0**, x86_64-posix-seh MinGW-Builds. Common direct flags: `-std=c++17 -municode -static -ffp-contract=off -I<root>/native/src`, link `-lpsapi -lbcrypt`. Release adds `-O2`; Debug adds `-O0 -g`; OpenMP adds `-fopenmp`; serial omits it. No compiler, solver tolerance or dependency upgrade was made.

|Configuration|Build exit / seconds|Modal solve exit / seconds|Legacy static / thermal / thermal restart|
|---|---|---|---|
|Release + OpenMP|0 / 21.956|0 / 0.360|0 / 0 / 0|
|Debug + OpenMP|0 / 19.028|0 / 0.767|0 / 0 / 0|
|Release serial|0 / 22.212|0 / 0.341|0 / 0 / 0|
|Debug serial|0 / 18.403|0 / 0.849|0 / 0 / 0|

[All build commands, timings, executable SHA-256 identities and fields](stage7-checkpoint1/builds-verified/results.json). All four configurations solve the same small modal case, verify independently recomputed residuals/frequencies/serialization, and exit normally. Frequencies agree across builds within the predeclared 1e-7 relative guard. Modal work is presently serial, even in OpenMP-enabled binaries; validation uses one requested thread and makes no parallel speedup claim.

Legacy static and steady thermal jobs are compared field-by-field against the archived Stage 6 results (rtol=1e-10, atol=1e-9); unchanged transient checkpoints resume in all four binaries and match their historical uninterrupted temperature reference within 1e-7 K. The existing version-1 static/thermal/checkpoint formats were not reinterpreted. The final build batch exits 0 with **274 Python assertions / 21 recorded operations**. Windows direct builds are verified; CMake target wiring was updated but not separately configured/executed. Other compilers/platforms are **NOT TESTED** in this checkpoint.

### Final regressions, resource observations and limitations

After the snapshot correction, the complete existing default manifest passes **28/28**, no script errors, outer exit 0 in **64.510 s**. [Per-test exits/durations/logs](stage7-checkpoint1/regression-verified/default/results.json). Separate freshly compiled native structural, HEX8 and radiation tests exit 0; execution durations are **0.441 / 0.506 / 0.743 s**. Those older C++ tests use assertions but do not emit exact dynamic assertion totals; no count is invented. Their logs identify the checked patches, rigid modes, integration and radiation references. [Native regression receipts](stage7-checkpoint1/regression-verified/results.json).

The earlier complete manifest and passing intermediate numerical/build runs remain as evidence, but the `*-verified` directories identify final acceptance after the provenance correction. `numerical-attempt1/` retains the true-inner-residual failure. `builds-snapshot-final/` retains the text-mode snapshot failure. The compiler initializer-list mistake was test-only and occurred before the first recorded matrix-build batch. No existing regression threshold was weakened and no failed artifact was removed.

Existing headless dummy-renderer diagnostics remain visible in the default manifest logs and are collected in [expanded final receipts](stage7-checkpoint1/all-final-receipts.json). The new headless mesher fixture has no script errors. There was no new graphical UI requirement or Workbench production change, so no app-shell smoke test or graphics campaign was added. This is not evidence of resolving Godot shutdown reliability.

Single-run resource observations (not benchmarks), one thread / 256 MiB configured budget:

|Case|Active DOFs / requested modes|K / M nonzeros|Assembly / eigen solve ms|Eigen iterations / total CG iterations|Windows peak working set|
|---|---|---|---|---|---|
|Finest cantilever|1440 / 2|39964 / 15906|30.973 / 2091.285|4 / 11164|10,149,888 bytes|
|Cylinder density 3|882 / 3|30564 / 10272|19.099 / 507.034|8 / 3475|8,540,160 bytes|

Native peak memory is the process-cumulative Windows `PeakWorkingSetSize` measured by the existing executable, not Godot static memory. Timings exclude independent Python verification. No expensive tests ran concurrently, no stress loop or HPC campaign ran, and no general performance improvement is claimed. The 6,000-DOF cap is a protective implementation limit; accuracy/performance was not certified across its entire range. The largest completed numerical reference here has 1,440 active DOFs. A fully general or vetted production eigensolver, sparse inertia counting, arbitrary ill-conditioned/hinged models, free-free modes and difficult large spectral clusters remain outside validated scope. Such cases must report failure rather than produce fabricated modes.

### Reproducible commands and delivered boundary

Exact expanded commands, expected/actual exits, durations, assertion banners and diagnostics are recorded in [all final receipts](stage7-checkpoint1/all-final-receipts.json), with primary phase counts and source identities in [summary](stage7-checkpoint1/summary.json). Native numerical input/result/status files are adjacent to each phase's receipts. These include complete self-contained beam/bar jobs and actual Stage 6 cylinder mesh data.

From the repository root, use a fresh output directory to preserve earlier evidence:

```powershell
$py = 'C:/Users/Victus/AppData/Local/Python/bin/python.exe'
$runRoot = '.tools/stage7-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
& $py tests/validate_stage7_modal.py --phase builds --output "$runRoot/builds"
& $py tests/validate_stage7_modal.py --output "$runRoot/numerical"
& $py tests/validate_stage7_modal.py --phase materials --output "$runRoot/materials"
& $py tests/validate_stage7_modal.py --phase provenance --output "$runRoot/provenance"
& $py tests/validate_stage7_modal.py --phase regression --output "$runRoot/regression"
```

Each invocation must exit 0 before proceeding. The runner refuses to overwrite an existing results receipt. It sets bounded subprocess timeouts and single-thread Python numerical libraries. Godot fixture/default runs redirect APPDATA to `.tools/cae-appdata`. Build compatibility fixtures depend on the retained Stage 6 archives explicitly referenced in the receipts. No new numerical package was installed; NumPy/SciPy must already be available to reproduce independent verification. `tests/summarize_stage7_modal.py` collects this checkpoint's recorded final evidence without rerunning solves.

Implemented and tested: constrained native TET4 modal FEM, consistent mass, sparse generalized eigensolution, mode normalization/diagnostics, versioned jobs/results, snapshot-based identity, independent spectra/continuum/scaling/geometry checks, four builds and legacy regressions. Deferred: modal Workbench study selection/mode-count controls, density UI validation specific to modal, modal exporter/importer, frequency list and animation; HEX8 consistent modal mass and free-free modal solution. Unsupported here: nonzero prescribed/modal pre-stress linearization, static modal excitation, modal checkpoint/restart, damping and the remaining Stage 7 physics checkpoints.

**Final verdict: PASS — CHECKPOINT 1 COMPLETE within the documented native constrained TET4 scope.** This is a functioning sparse modal FEM kernel, not a dense demonstration or animation. It is not universal production eigenanalysis certification, an accurate coarse TET4 bending benchmark, completion of all Stage 7, or a fix for Stage 6's historical Godot access violation. Checkpoint 2 was not started.

Final review: both new Python tools pass `py_compile` (exit 0). Whole-working-tree `git diff --check` still exits 2 for the pre-existing blank line at the end of `ui/cae/cae_workspace.gd`; that file was not edited here. [Exact formatting receipt](stage7-checkpoint1/worktree-format-check.json). A [diff against the preserved current-worktree main.cpp baseline](stage7-checkpoint1/native-main.diff) makes the parser/result integration reviewable independently of older uncommitted changes. Existing meshers, structural/thermal kernels, GDExtension ABI and Workbench production files were preserved.

## Checkpoint 2 — Native transient structural dynamics

**PASS — validated native transient structural FEM within the bounded constrained TET4 scope below.** The repository remains on `master`, HEAD `13e40a5a565a273485aa80ea14ed110df36136a2`, with all preceding working-tree changes retained. [Checkpoint 2 baseline and source hashes](stage7-checkpoint2/baseline.json). Checkpoint 1's mass matrix, eigensolver, stiffness routines and provenance helper are reused without numerical edits. No Workbench production code or geometry producer is changed. Historical Godot access violation remains **UNRESOLVED**. No Checkpoint 3 physics is started.

### Formulation and intended acceptance

Stationary homogeneous supports are eliminated from M and K. Rayleigh C=alpha_mass*M+beta_stiffness*K, alpha_mass in s^-1 and beta_stiffness in s; both must be nonnegative finite. Newmark beta is fixed at 1/4 and gamma at 1/2. Define u_predict=u_n+h*v_n+h²*a_n/4 and v_predict=v_n+h*a_n/2. Solve:

`[M + h*C/2 + h²*K/4] a_(n+1) = F_(n+1) - C*v_predict - K*u_predict`.

Then u_(n+1)=u_predict+h²*a_(n+1)/4, v_(n+1)=v_predict+h*a_(n+1)/2. Initial acceleration solves M*a_0=F_0-C*v_0-K*u_0. This is algebraically equivalent to the conventional effective stiffness K+2*C/h+4*M/h², with less extreme coefficient magnitudes at small h. No artificial damping or penalty support is introduced. The constant effective matrix and its IC(0) preconditioner are prepared once; an independent mass-system setup computes initial acceleration.

Under symmetric positive-definite M/K and positive-semidefinite Rayleigh C, the linear average-acceleration method is unconditionally stable, with second-order temporal accuracy and no algorithmic damping in the undamped case. This does not ensure accuracy for under-resolved oscillation or discontinuous force histories. See [OpenSees Newmark documentation](https://opensees.berkeley.edu/wiki/index.php/Newmark_Method) and [INL dynamics documentation](https://blackbear.inl.gov/modules/solid_mechanics/Dynamics.html). Unit and FEM tests must verify these properties independently.

Energy accounting uses E_n=0.5*v_n^T*M*v_n+0.5*u_n^T*K*u_n. Each step accumulates discrete work `(F_n+F_(n+1))/2 · (u_(n+1)-u_n)` and dissipation `h*v_average^T*C*v_average`, where v_average=(v_n+v_(n+1))/2. Average acceleration gives delta_u=h*v_average, so averaging endpoint equilibrium yields E_n+D_n-W_n-E_0=0 up to linear solve/rounding errors. These are discrete work/dissipation measures, not exact continuum-time quadrature for arbitrary loads.

Predeclared verification guards, before reference execution: dynamic equilibrium relative defect <=1e-8; true linear residual <=1e-9; undamped unit energy drift/work-balance <=1e-10 J; FEM energy-balance error <=1e-6 of the initial energy for free-mode fixtures. Smooth oscillator dt-halving errors should decrease approximately quadratically (ratio 3.5–4.5), with finest normalized phase error below 1e-3. SDOF displacement/velocity/acceleration absolute errors at dt=.005 s and T=4 s must be below 1e-4 m / 5e-4 m/s / 2e-3 m/s². Coupled oscillator dt=.001 s, T=1 s guards are 2e-5 / 1e-4 / 1e-3 in the corresponding SI units against high-accuracy independent SciPy integration. FEM temporal errors and frequency-resolution observations will be reported separately from the preserved 41.7% coarse-beam spatial discrepancy.

### Native implementation and scope

New production files: `native/src/math/newmark.hpp` (matrix-level integration and cached CG), `native/src/kernels/transient_structural.hpp` (TET4 assembly/reduction), and `native/extreme/dynamic_output.hpp` (time-history serialization). Narrow additions to `native/extreme/main.cpp` dispatch version-3 jobs; CMake gains a dynamics test target. The existing build script and libraries are reused unchanged. [Main integration diff against the current-worktree baseline](stage7-checkpoint2/native-main.diff).

TET4 stiffness calls the existing `structural::element`; mass calls the accepted `modal::tet_mass`. The modal CSR matrix wrapper and existing IC(0)/Jacobi implementation are reused. No shared static or modal solver tolerance was changed. Private dynamic CG uses the requested 1e-12–1e-10 recurrence tolerance (validation uses 1e-11), a true-RHS residual check <=1e-9 and bounded iterations. True-residual replacement restarts CG when necessary, rather than trusting only a recursive residual. Zero RHS is handled explicitly. Per-step endpoint equilibrium uses `norm(Ma+Cv+Ku-F)/(norm(Ma)+norm(Cv)+norm(Ku)+norm(F))`; an all-zero denominator requires an exactly zero defect. The kernel checks this at every step, including unsampled steps, and rejects residuals above 1e-8.

Constant K, M, damping and h allow one effective matrix/preconditioner setup for the entire integration. The output reports this count and cumulative CG iterations. Initial acceleration has a separate mass-system solve; it is not copied from zero or a static displacement. All full-output support components are restored as exact zeros. Nonzero prescribed displacement or nonzero initial support displacement/velocity rejects. Unsupported pre-populated static force vectors in the native model reject; external loads must use explicit dynamic histories. Loads on stationary constrained DOFs do no displacement work and do not affect the reduced response; corresponding reactions are not supplied in this checkpoint.

Supported loads are additive per original global DOF: constant, right-continuous step, clipped linear ramp and gated sinusoid. A constant is active at t=0; a step is amplitude for t>=start; a ramp rises from zero at start to amplitude at end and remains there; a sinusoid is amplitude*sin(omega*(t-start)+phase) for t>=start, otherwise zero. Amplitude is N, times are s, omega is rad/s and phase is rad. Nonfinite/invalid parameters and unknown kinds reject. Force discontinuities are sampled at actual endpoint times; no unsupported claim of second-order accuracy across arbitrary discontinuous onsets is made.

Validated continuum scope is small-strain, linear isotropic TET4, positive finite density, fixed stationary supports and the documented resource bounds. HEX8, free-free structural dynamics, moving supports, nonlinear materials, damping beyond Rayleigh, reaction output and stress/strain time histories are deferred. No analytical mode shape or static series is substituted for time integration.

### Version-3 job and result contract

Version-1 static/thermal jobs, version-2 modal jobs and thermal `UNICORE_STATE 1` checkpoints retain their original meanings. The new input is:

```text
UNICORE_JOB 3 transient_structural
node_count element_count
x y z                                      # node_count rows, meters
4 n0 n1 n2 n3 E nu density                  # element_count rows; Pa, -, kg/m^3
fixed prescribed initial_u initial_v        # 3*node_count rows; xyz DOFs; m, m/s
DYNAMICS dt steps alpha_mass beta_stiffness max_linear_iterations relative_tolerance wall_seconds
LOADS load_count
dof kind amplitude start end omega phase    # load_count rows
OUTPUTS frame_count
step_0 step_1 ... step_last
```

The comments describe the grammar and are not accepted input syntax. `fixed` is strictly 0/1 and `prescribed` must be zero. Output indices are strictly increasing on the integration grid, must include 0 and the final step, and request times t=index*dt. Arbitrary off-grid interpolation is deferred. All count/index/material/initial/load/damping/time fields are validated; unknown/trailing syntax rejects. Legacy CLI solver overrides do not silently alter dynamic integration: the dynamic trailer is authoritative. Newmark parameters are fixed constants, not configurable input fields.

The version-3 input uses the accepted bounded **immutable binary snapshot** path. Both exact-byte SHA-256 and existing FNV identity describe the bytes actually parsed, including geometry, per-element density/materials, initial conditions, histories, damping, output settings and controls. SHA-256 helper source is unchanged. The input-edit test modifies E while the process is integrating: output still reports original E and original SHA, and comparison with the edited current source fails. The intentionally edited source and original snapshot are both retained in [provenance evidence](stage7-checkpoint2/provenance-final/).

Successful results add `dynamic_schema:1`, `complete:true`, `converged:true`, original nodes/elements, per-cell materials, active original DOF IDs, units, controls, requested `output_steps` and `frame_count`. Each sampled frame contains time, full nodal displacement/velocity/acceleration, kinetic/elastic energy, cumulative damping dissipation, discrete external work, energy-balance defect and equilibrium residual. Setup/assembly/integration timings, total physical mass, matrix nonzeros, linear iterations, preconditioner/fallback and maximum all-step diagnostics are included. These are computed numerical states, not measurements. No top-level static displacement is fabricated for old importers.

Results are published atomically only after a complete successful history. Failed/cancelled jobs retain failure diagnostics and may leave a diagnostic `.tmp`; they do not publish a successful history. Readers must check Completed status, complete/schema/provenance, requested-frame correspondence, field lengths and finite values. The test-side dynamic reader rejects representative incomplete, truncated and nonnumeric nodal fields. The existing Workbench importer also rejects Failed/Cancelled states and unsupported/malformed/incomplete dynamic output through its existing status/provenance/mandatory-field gates. It does **not** validate/display all dynamic fields as a new product feature. [Actual Godot importer rejection test](stage7-checkpoint2/imports-final/workbench-import-rejection.log), exit 0 in **0.627 s**, exercises five rejection paths with no script errors.

### Independent oscillator verification

`native/tests/dynamics_test.cpp` calls the production matrix-level integrator; it does not replace the production TET4 formulation. Its single-DOF M=2 kg, K=8 N/m oscillator has omega=2 rad/s. Free cases use u0=0.1 m, v0=0.2 m/s, plus a separate u0=0, v0=0.3 case. Damped free motion uses alpha_mass=0.4 s^-1, beta_stiffness=0.03 s, hence C=1.04 kg/s and damping ratio 0.13. Step/constant forces are 2 N; sinusoidal force is sin(1.3*t) N. Analytic displacement, velocity and acceleration are computed independently in Python; a finite-duration ramp uses independent SciPy DOP853 integration.

At h=0.005 s, T=4 s:

|Case|Maximum displacement error m|Velocity error m/s|Acceleration error m/s²|
|---|---:|---:|---:|
|Free, u0/v0 both nonzero|7.5654e-6|1.6824e-5|3.0262e-5|
|Rayleigh damped free|3.3515e-6|7.0832e-6|1.4187e-5|
|Step|1.6493e-5|2.6504e-5|6.5972e-5|
|Sinusoidal|6.4806e-6|1.7551e-5|2.5922e-5|

All constant/ramp/velocity cases also pass the predeclared guards; their full errors are in [numerical results](stage7-checkpoint2/numerical-final/results.json). Independent reconstruction checks reported mechanical energy and midpoint damping/work quadratures, not only the producer's balance field. Unit discrete energy balance stays below the 1e-10 J guard. Zero-damping unforced motion conserves mechanical energy; nonzero physical damping produces nonnegative dissipation. A deliberately coarse h=1 s oscillator test remains energy bounded/conservative, despite its large phase error: its discrete angular frequency is pi/2 rather than 2 rad/s. Stability is not being presented as accuracy.

For smooth free oscillation over 4 s, h=.04/.02/.01 s yields terminal phase errors **0.00426258 / 0.00106641 / 0.000266651 rad**. Displacement, velocity and acceleration errors each decrease with dt-halving ratios in the predeclared 3.5–4.5 interval. These verify second-order time convergence independently of FEM spatial error.

The coupled two-DOF reference uses M=[[2,.3],[.3,1]], K=[[30,-10],[-10,20]], C=.2*M+.01*K, u0=[.1,-.03], v0=[.2,.1], one sinusoidal force and one ramp. SciPy DOP853 (rtol=1e-12, atol=1e-14, bounded max_step=.002 s) integrates the first-order state equations without production Newmark code. At dt=.001 s, T=1 s, maximum errors are **7.4594e-7 m**, **3.4509e-6 m/s**, **2.2552e-5 m/s²**. Multiple frequencies, off-diagonal mass coupling, nonzero initial states, forcing and damping are exercised together. NumPy 2.5.2/SciPy 1.18.1 are existing test-only dependencies; no new solver library or package was installed.

### Real TET4 temporal, modal and spatial evidence

Actual accepted Stage 6 cylinder meshes (diameter=0.2 m, length=0.2 m, Bottom fixed) are reused. E=2e9 Pa, nu=.25, rho=7800 kg/m³. Python independently reconstructs shape gradients using affine interpolation, assembles K/M, reduces DOFs and solves a generalized symmetric eigenproblem. The accepted native modal solver is also invoked and agrees with this independent first natural frequency within 1e-7 relative. Initial displacement is a small mass-normalized independently verified first-mode pattern (modal coordinate 1e-5), initial velocity zero. The production transient kernel still solves the full reduced FEM equilibrium at every step; it is not a modal-response generator.

Density-1 mass is **44.123463 kg**, matching independent rho*sum(TET4 volumes), with 27 nodes / 48 TET4 and 54 free DOFs. This is the faceted solid's mass; the circular-cylinder mass differs because of polygonal geometry. Fixed components stay exactly zero, all states are finite, initial acceleration agrees with equilibrium, and a repeated 2,000-step history reproduces exactly in the same configuration.

The 20-period observation uses the independently/native-verified frequency **310.976388 Hz**, total duration approximately 0.0643 s:

|Internal steps|Terminal phase error rad|Projected transient frequency Hz|
|---|---:|---:|
|500|0.655270|309.354810|
|1000|0.164976|310.568126|
|2000|0.0413172|310.874141|

The phase errors decrease by approximately four under halving dt. Displacement/velocity/acceleration waveform errors decrease too. At 2,000 steps the maximum normalized errors over 20 periods remain approximately **4.08% / 4.14% / 4.08%**; no claim of arbitrarily accurate long-time phase is made. Projection/phase estimates agree within 1e-6 relative with the independently known Newmark frequency `atan(omega*h/2)/(pi*h)`. The finest FFT peak is **310.665722 Hz**, but its bin spacing is **15.533286 Hz**, so FFT acceptance is only within one bin. The phase-based estimate, FFT bin resolution and modal frequency are not conflated.

Every sampled state is independently checked against K*u+M*a=0 in the undamped free case. Maximum reported all-step equilibrium residual is **4.12e-12**. At 2,000 steps, maximum absolute energy-balance defect is **4.88e-19 J**, separately verified from the stored states with independently assembled K/M. The damped/forced FEM case has positive damping dissipation and maximum discrete work-energy imbalance **1.18e-17 J**. Its damping/work integrals are independently reconstructed from every saved internal step. A zero-initial/unforced FEM case remains identically zero.

[Spatial observations from real transient histories](stage7-checkpoint2/spatial-observations.json), with omega*h=.1 held fixed:

|Density|Nodes / TET4|Physical mesh mass kg|Independent FEM modal f Hz|Transient projected f Hz|
|---|---:|---:|---:|---:|
|1|27 / 48|44.123463|310.976388|310.717629|
|2|125 / 384|47.758892|278.681668|278.449781|

The change with density includes faceted geometry and FEM spatial effects; the small time-integration shift is separately predictable. There is no independent continuum frequency reference for this compact cylinder. The prior **41.7% Euler–Bernoulli discrepancy** belongs to the different coarse TET4 slender-beam benchmark, remains documented above and is not relabeled a Newmark error. These cases do not certify general bending accuracy or sphere/pipe dynamic workflows.

### Failure, lifecycle and restart boundary

Representative invalid density/elastic constants, nonfinite initial u/v, invalid dt, too many steps/outputs, unordered output indices, negative/nonfinite Rayleigh damping, nonzero/moving supports, malformed load kinds, version mismatch, trailing data, forced CG nonconvergence and tiny expired wall limits all reject with native exit **2**. There is no published result for those failures. Separate zero-initial-state/delayed-step forcing forces an **effective-system** iteration-limit failure after initial acceleration has solved as zero, confirming that time-step nonconvergence also rejects. [Supplementary lifecycle commands/results](stage7-checkpoint2/lifecycle-extra/results.json).

Cancellation is requested after observing actual integration phase 4 on a bounded density-3 cylinder. It returns native exit **3** in **0.266 s** total test runtime, removes its ownership lock and publishes no successful history. A fresh valid job then solves normally. Each owned native subprocess is waited to actual completion. There was no new Godot shutdown diagnosis or claim about unrelated engine processes. The existing Workbench import guard rejects the failed/cancelled states.

Structural restart is deliberately **deferred**. The thermal checkpoint stores temperatures/time settings and cannot encode the required structural u/v/a state, damping/integration settings and job identity without a separately versioned implementation and equivalence validation. Version-3 `--restart` and nonzero `--pause-after` reject with `DYNAMIC_RESTART_DEFERRED` and exit 2; even an otherwise valid thermal checkpoint is not misread as structural state. Cooperative cancellation is not checkpoint-capable interruption. Unchanged thermal checkpoint/restart is verified across all four builds.

### Bounds, builds and regressions

Hard bounds: 1,000 nodes / 3,000 full DOFs, 6,000 TET4, 20,000 steps, 4,096 additive load terms, 1,001 output frames, and at most **200,000 full-DOF/frame entries per field** (three vector fields). Actual frame count may be lower because of that product bound. Requested outputs must include first/final states and be strictly ordered. Input snapshot is bounded at 8 MiB. Linear iteration limit is 1–20,000 per solve; wall limit is positive and <=60 s, checked cooperatively through assembly/CG/integration. Existing CLI memory budget and process monitor remain active; reference native jobs configure one thread and 256 MiB. Serialization is bounded by the output cap; no unbounded result stream is produced.

|Configuration|Compile/link exit / seconds|Dynamic reference exit / seconds|Static / thermal / modal / thermal restart|
|---|---|---|---|
|Release + OpenMP|0 / 14.074|0 / 0.247|0 / 0 / 0 / 0|
|Debug + OpenMP|0 / 10.128|0 / 0.428|0 / 0 / 0 / 0|
|Release serial|0 / 14.140|0 / 0.245|0 / 0 / 0 / 0|
|Debug serial|0 / 9.958|0 / 0.427|0 / 0 / 0 / 0|

Compiler/build flags remain the Checkpoint 1 GCC 13.1.0 MinGW C++17 direct-build infrastructure, `-ffp-contract=off`, Release `-O2`, Debug `-O0 -g`, optional `-fopenmp`, existing psapi/bcrypt system libraries. [Exact build commands, binary SHA identities and numerical comparisons](stage7-checkpoint2/builds-final/results.json). Dynamic u/v/a agree across builds (rtol=1e-8, atol=1e-10). Archived Stage 6 static/thermal fields match their established tolerances; modal frequencies retain the existing 1e-7 compatibility guard; resumed thermal temperatures retain the 1e-7 K restart guard. Modal source/mass/helper hashes are unchanged from the baseline. CMake wiring is updated but not separately built; other compilers/platforms are NOT TESTED. New integration remains serial even in OpenMP-capable binaries; no parallel speedup is claimed.

Complete existing default manifest: **28/28 pass**, exit 0 in **30.202 s**. [Raw per-script exits/durations](stage7-checkpoint2/regression-final/default/results.json). Fresh native static structural, HEX8, thermal/radiation, modal and dynamics test executables all compile and exit 0. The accepted modal matrix suite still reports **582 checks / 0 failures**; the dynamics smoke reports 3 checks / 0 failures. Older native structural/thermal suites do not emit dynamic assertion counts; their retained logs identify the checked references instead of inventing counts. [Native regression commands/logs](stage7-checkpoint2/regression-final/results.json).

Final main numerical batch: **44 operations**, **31,615 Python check invocations** (mostly per-frame/per-field checks, including deliberately caught negative-reader assertions). These are not 31,615 independent physical benchmarks. Build batch: 24 operations / 3,132 checks. Full numerical/build/import/provenance/lifecycle receipts are consolidated in [all final receipts](stage7-checkpoint2/all-final-receipts.json), with phase totals and source hashes in [summary](stage7-checkpoint2/summary.json). All final validation invocations exit 0. The earlier numerical-attempt1 also passed within its narrower coverage and remains preserved; the final suite adds independent work/energy, declared-frame completeness, current modal reference, zero-state and import failure coverage. No unexpected numerical failure or crash was removed or relabeled a pass.

Existing dummy-renderer diagnostics remain in some legacy headless regression logs and are retained in the receipts; zero exit is not described as globally diagnostic-free. The new importer rejection test exits normally without script errors. No Workbench production code changed, so no new graphical campaign or app-shell smoke was required; this does not certify application shutdown stability.

Single-run observations for the density-1 cylinder, not performance benchmarks: 2,000 steps / 1,001 sampled frames, assembly **0.486 ms**, effective-system/initial setup **0.329 ms**, integration **71.201 ms**, total CG iterations **20,009**, native peak working set **7,688,192 bytes**. The peak comes from Windows `GetProcessMemoryInfo` in the native process, not Godot static counters. Reference jobs were sequential; no unbounded stress loop or HPC campaign ran, and no controlled speedup comparison or background-load isolation is claimed.

### Reproduction and final Checkpoint 2 verdict

New tools: `tests/validate_stage7_dynamics.py`, `tests/summarize_stage7_dynamics.py`, `native/tests/dynamics_test.cpp`, and the narrow existing-importer test `tests/test_stage7_dynamic_import_rejection.gd`. Inputs and results are retained beside each receipt, including corrupted-result diagnostics and original/edited snapshot pairs. All exact expanded subprocess commands, durations and exit codes are in the linked receipts. From the repository root, choose fresh output paths:

```powershell
$py = 'C:/Users/Victus/AppData/Local/Python/bin/python.exe'
$runRoot = '.tools/stage7-dynamics-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
& $py tests/validate_stage7_dynamics.py --phase builds --output "$runRoot/builds"
& $py tests/validate_stage7_dynamics.py --output "$runRoot/numerical"
& $py tests/validate_stage7_dynamics.py --phase provenance --output "$runRoot/provenance"
& $py tests/validate_stage7_dynamics.py --phase regression --output "$runRoot/regression"
```

Each command must exit 0 before proceeding. The runner refuses to overwrite existing receipts, uses explicit process timeouts and single-thread Python numerical libraries. Godot tests redirect APPDATA into `.tools/cae-appdata`. The `imports` phase checks this checkpoint's retained `numerical-final` fixtures; the exact direct Godot command is in its receipt. The summary tool reconstructs spatial phase observations from already computed histories, verifies preserved modal hashes and refuses to summarize failed phases as PASS. Build compatibility/archive references depend on retained Stage 6/Checkpoint 1 files identified in the commands.

**Final verdict: PASS — native transient structural TET4 FEM within this documented bounded scope.** Implemented/tested: average-acceleration Newmark, consistent mass and stiffness, zero/nonzero initial u/v, stationary constraints, four load kinds, undamped/Rayleigh cases, cached sparse solution, energy/work diagnostics, temporal/modal/spatial observations, snapshot provenance, cancellation/recovery, four builds and legacy regressions. Deferred: structural restart, reactions, stress time histories, HEX8/free-free dynamics, off-grid output interpolation, and all Workbench study/export/import/animation/timeline plumbing. The existing Workbench structural/thermal functionality remains supported; transient structural studies are available through the native CLI only. Stage 7 is not complete, Checkpoint 3 was not started, and the historical Godot access violation remains unresolved.

Final tooling checks: new Python validation/summary scripts compile with `py_compile` (exit 0). Whole-worktree `git diff --check` retains the pre-existing trailing blank line diagnostic in `ui/cae/cae_workspace.gd` (exit 2); no unrelated formatting was cleaned up. [Exact receipt](stage7-checkpoint2/worktree-format-check.json). The preserved Checkpoint 1 mass, eigensolver and SHA helper hashes match byte-for-byte in the final summary. No native solver process remained at final quiescence inspection; unrelated Godot processes were not terminated or represented as checkpoint-owned clean exits.

CAD expansion: PARTIAL infrastructure only; see docs/architecture/CAD_MESHING_CHECKPOINT.md. No new native or GUI acceptance claimed.

