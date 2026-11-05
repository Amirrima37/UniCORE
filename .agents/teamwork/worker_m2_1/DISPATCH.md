## 2026-10-28T12:48:21Z
You are the Physics Core Developer (Worker M2) for Milestone 2 (Conservation Law Sentry & Spatial Partitioning Acceleration).
Your working directory is: c:\dev\UniCORE\.agents\teamwork\worker_m2_1\

MANDATORY FIRST STEP:
Read the authoritative user request at:
c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md

And read the project specification at:
c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md

And read the Explorer blueprints:
- c:\dev\UniCORE\.agents\teamwork\explorer_m2_1\exploration_report.md
- c:\dev\UniCORE\.agents\teamwork\explorer_m2_2\exploration_report.md
- c:\dev\UniCORE\.agents\teamwork\explorer_m2_3\exploration_report.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

EXCLUSIVE WRITE OWNERSHIP:
You own and must implement the following 3 files exclusively:
1. res://core/physics/conservation_sentry.gd
2. res://core/physics/spatial_hash_grid.gd
3. res://core/physics/barnes_hut_octree.gd

Implementation Requirements:
1. Strict GDScript 2.0 static typing on all properties, parameters, and return types (zero untyped Variants).
2. Follow all Godot 4.0.stable constraints from GEMINI.md:
   - No `Callable.get_argument_count()`
   - No `ClassName.has_method(...)` on class name directly
   - No typed dictionaries (use `var _grid: Dictionary = {}`)
3. `ConservationSentry`:
   - Real-time continuous auditing of total energy E, linear momentum P, angular momentum L, and kinetic temperature T in an O(N) fused single-pass loop.
   - Guard against division by zero: drift_E = |E(t) - E(0)| / max(|E(0)|, 1e-12).
   - Signals: `invariants_updated(snapshot: Dictionary)`, `conservation_warning(violation_type: String, relative_drift: float)`.
   - Thresholds: `energy_tolerance = 0.005`, `momentum_tolerance = 0.01`, `angular_momentum_tolerance = 0.01`.
   - Methods: `register_system`, `audit` (supporting automatic self-registration on first call if uninitialized), `reset`, `get_last_snapshot`, `is_system_conserved`.
4. `SpatialHashGrid`:
   - Prime hash function: `(ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791)`.
   - Methods: `initialize(cell_size: float, expected_capacity: int = 10000)`, `clear()`, `insert(particle_idx: int, position: Vector3)`, `build_grid(positions: PackedVector3Array)`, `get_neighbors(position: Vector3, search_radius: float) -> PackedInt32Array`, `get_neighbors_in_radius(position: Vector3, search_radius: float, positions: PackedVector3Array) -> PackedInt32Array`.
   - Use `floor()` quantization for negative coordinates.
   - Bounding box search with hash deduplication and Euclidean distance squared filtering.
5. `BarnesHutOctree`:
   - 3D hierarchical tree with Morton 3-bit indexing.
   - 100% iterative (non-recursive) insertion and traversal to eliminate recursion stack overflow.
   - In-place node pooling (`_node_pool`) for zero-allocation performance.
   - Multipole opening angle criterion: `s^2 <= theta_crit^2 * d^2` (theta_crit = 0.5).
   - Edge case guards for coincident particles, degenerate AABB, and zero-distance singularity.

Verification Steps:
Execute the following verification commands using run_command:
1. & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE --check-only -s res://core/physics/conservation_sentry.gd
2. & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE --check-only -s res://core/physics/spatial_hash_grid.gd
3. & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE --check-only -s res://core/physics/barnes_hut_octree.gd
4. & "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only
Verify all exit with code 0!

When complete, write your handoff report to:
c:\dev\UniCORE\.agents\teamwork\worker_m2_1\handoff.md
Include all command outputs and verification details.
Then send a completion message back to the orchestrator parent.
