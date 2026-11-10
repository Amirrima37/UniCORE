## 2026-10-28T12:11:10Z
You are Explorer M2-2 for Milestone 2 (Conservation Law Sentry & Spatial Partitioning).
Your working directory is: c:\dev\UniCORE\.agents\teamwork\explorer_m2_2\

MANDATORY FIRST STEP:
Read the authoritative user request at:
c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md

And read the project specification at:
c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md
and spec inventory at:
c:\dev\UniCORE\.agents\teamwork\spec_miner_survey\spec_inventory.md

Your focus:
1. Design concrete implementation strategy for `SpatialHashGrid` (res://core/physics/spatial_hash_grid.gd, extends RefCounted).
2. Formulate 3D uniform spatial hashing:
   - Methods: `initialize(cell_size: float, expected_capacity: int = 10000)`, `clear()`, `insert(particle_idx: int, position: Vector3)`, `get_neighbors(position: Vector3, search_radius: float) -> PackedInt32Array`.
   - Hash function: `hash_coords(ix: int, iy: int, iz: int) -> int`: primes `(ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791)`.
   - Grid bucket layout in GDScript 2.0: typed Dictionary or PackedInt32Array buckets.
   - Bounding box cell iteration: clamp neighbor search to `ceil(search_radius / cell_size)` cells, then filter particles with exact distance squared check `pos.distance_squared_to(query_pos) <= search_radius * search_radius`.
3. Design 5,000-particle performance and equivalence benchmark:
   - Run 5,000 randomly scattered particles.
   - Verify query returns identical neighbor list to brute-force O(N^2) search.
   - Verify query executes in < 10 ms.
4. Write findings and blueprint to c:\dev\UniCORE\.agents\teamwork\explorer_m2_2\exploration_report.md and create c:\dev\UniCORE\.agents\teamwork\explorer_m2_2\handoff.md.
5. When complete, send a message to the orchestrator parent.
