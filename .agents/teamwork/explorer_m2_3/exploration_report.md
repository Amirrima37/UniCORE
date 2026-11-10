# UniCORE Barnes-Hut 3D Octree Implementation Blueprint & Architecture Report
**Author**: Explorer M2-3 (Conservation Law Sentry & Spatial Partitioning)  
**Target Component**: `res://core/physics/barnes_hut_octree.gd`  
**Milestone**: Milestone 2 (Task 11 / Spatial Partitioning Acceleration)  
**Date**: 2026-10-28  
**Status**: COMPLETE SPECIFICATION & BLUEPRINT  

---

## 1. Executive Summary & Algorithmic Foundations

### 1.1 Objective & Context
In gravitational $N$-body systems and celestial mechanics, the fundamental interaction is long-range and follows Newton's inverse-square law:
$$\vec{F}_{ij} = -G \frac{m_i m_j}{(|\vec{r}_i - \vec{r}_j|^2 + \epsilon^2)^{3/2}} (\vec{r}_i - \vec{r}_j)$$

While short-range potentials (such as Lennard-Jones 12-6 in `MolecularDynamicsModule`) decay rapidly ($1/r^6$) and can be truncated at a cutoff radius $r_c = 2.5\sigma$ using `SpatialHashGrid` in $O(N)$ time, gravitational forces **do not have a cutoff radius**. Truncating gravity produces unphysical artifacts, breaks orbital momentum conservation, and prevents large-scale structure formation.

Computing all pairwise gravitational interactions naively requires $O(N^2)$ calculations. For $N = 10,000$ bodies, this requires $10^8$ force evaluations per physics substep, which freezes the simulation loop.

`BarnesHutOctree` reduces this computational complexity from $O(N^2)$ to $O(N \log N)$ by grouping distant clusters of bodies into hierarchical multipole/monopole pseudoparticles within a 3D recursive octree.

### 1.2 Comparison: SpatialHashGrid vs. BarnesHutOctree

| Architectural Dimension | `SpatialHashGrid` | `BarnesHutOctree` |
|---|---|---|
| **Physics Domain** | Short-range forces (Molecular Dynamics, Collisions) | Long-range forces (Gravity, Coulomb electrostatics) |
| **Interaction Potential** | Lennard-Jones ($r^{-12} - r^{-6}$), hard-sphere | Newtonian ($1/r^2$), 1PN General Relativity |
| **Cutoff Radius ($r_c$)** | Strict finite cutoff ($r_c = 2.5\sigma$) | Infinite (no cutoff allowed) |
| **Data Structure** | Flat 3D hash table of uniform cubes | Hierarchical 8-ary spatial tree (Octree) |
| **Time Complexity** | $O(N)$ neighbor queries within $R$ | $O(N \log N)$ multipole force summation |
| **Multipole Approximation**| None (exact pairwise within radius) | Monopole Center-of-Mass with opening angle $\theta$ |
| **Target Module** | `MolecularDynamicsModule` | `NBodyGravityModule`, `ScientificProbeModule` |

---

## 2. Mathematical Foundations & Multipole Acceptance Criterion

### 2.1 Octree Node Physical Representation
Each node in the 3D octree represents a spatial cubic volume defined by an axis-aligned bounding box `AABB(origin, size)` and contains:
1. **Total Mass**:
   $$M = \sum_{k \in \text{node}} m_k$$
2. **Center of Mass (CoM)**:
   $$\vec{R}_{CoM} = \frac{1}{M} \sum_{k \in \text{node}} m_k \vec{r}_k$$
3. **Geometric Size**:
   $$s = \text{size.x} \quad (\text{node is an exact cube, so } \text{size.x} = \text{size.y} = \text{size.z})$$

### 2.2 Multipole Acceptance Criterion (MAC)
When calculating the gravitational acceleration $\vec{a}_i$ on body $i$ located at $\vec{r}_i$:
For any node in the octree, let $\vec{R}_{CoM}$ be the node's center of mass, and let $d = |\vec{R}_{CoM} - \vec{r}_i|$ be the distance from body $i$ to the node's center of mass.
The opening angle $\theta$ subtended by the node is:
$$\theta = \frac{s}{d}$$

Given a critical opening angle threshold $\theta_{crit}$ (default $0.5$):
- **Far Field Condition ($\theta \le \theta_{crit}$)**:
  The internal distribution of masses within the node can be accurately approximated by a single monopole mass $M$ located at $\vec{R}_{CoM}$. The tree traversal **does not open** the node; instead, it accumulates the single acceleration contribution:
  $$\Delta \vec{a}_i = G \frac{M}{(d^2 + \epsilon^2)^{3/2}} (\vec{R}_{CoM} - \vec{r}_i)$$
- **Near Field Condition ($\theta > \theta_{crit}$)**:
  The node is too close to be treated as a single point mass. The traversal opens the node and recursively/iteratively visits its 8 child octants.
- **Leaf Nodes**:
  If a leaf node is reached:
  - If it contains particle $j \neq i$, calculate the exact pairwise interaction between body $i$ and body $j$.
  - If it contains particle $i$ itself ($j == i$), skip it (no self-interaction).

### 2.3 Eliminating Square Roots in the MAC Test
In high-performance simulation loops, evaluating `sqrt()` for every opening angle check on thousands of nodes is a massive bottleneck.
We transform the opening angle criterion into a square-distance inequality:
$$\theta \le \theta_{crit} \iff \frac{s}{d} \le \theta_{crit} \iff \frac{s}{\theta_{crit}} \le d \iff s^2 \le \theta_{crit}^2 \cdot d^2$$
Let $\theta_{sq} = \theta_{crit}^2$ and $d^2 = |\vec{R}_{CoM} - \vec{r}_i|^2$:
$$\text{Approximate} \iff s^2 \le \theta_{sq} \cdot d^2$$
This requires **zero square roots** during tree pruning! A square root is only evaluated when the node is actually accepted or direct pairwise force is calculated.

### 2.4 Gravitational Potential & Energy Auditing
`ConservationSentry` requires the continuous evaluation of total gravitational potential energy $U_{total}$ to audit the Hamiltonian Noether invariant $E = E_k + U$.
The gravitational potential $\Phi(\vec{r}_i)$ at the position of particle $i$ is:
$$\Phi(\vec{r}_i) = \sum_{\text{far nodes}} -G \frac{M}{\sqrt{d^2 + \epsilon^2}} + \sum_{j \neq i, \text{near}} -G \frac{m_j}{\sqrt{|\vec{r}_j - \vec{r}_i|^2 + \epsilon^2}}$$

The total potential energy of the entire system of $N$ bodies is:
$$U_{total} = \frac{1}{2} \sum_{i=0}^{N-1} m_i \Phi(\vec{r}_i)$$
*(The factor of $1/2$ corrects for double-counting pairwise interactions).*
Using `BarnesHutOctree`, $U_{total}$ is evaluated in $O(N \log N)$ rather than $O(N^2)$, enabling real-time conservation auditing of thousands of celestial bodies at 60–100 Hz.

---

## 3. Data Structure Architecture & Godot 4 Nuances

### 3.1 Inner Class `OctreeNode` vs. Memory Pooling
Creating tens of thousands of `RefCounted` nodes via `new()` every physics frame causes severe garbage collection pauses and memory fragmentation.
To guarantee deterministic 60+ FPS execution in Godot 4.0.stable:
1. `BarnesHutOctree` maintains an internal node pool: `_node_pool: Array[OctreeNode]`.
2. When `build()` is called, an internal cursor `_pool_cursor` is reset to 0.
3. If an existing node is available in `_node_pool`, it is recycled via `node.reset(...)`.
4. If the pool is exhausted, a new `OctreeNode` is instantiated and appended to `_node_pool`.
5. On subsequent frames, **zero memory allocations occur**.

```gdscript
class OctreeNode extends RefCounted:
	var bounds: AABB = AABB()
	var center: Vector3 = Vector3.ZERO
	var size: float = 0.0           # Node side length (AABB is an exact cube)
	var size_squared: float = 0.0   # Precomputed size * size for branch tests
	
	var total_mass: float = 0.0
	var center_of_mass: Vector3 = Vector3.ZERO
	
	# Leaf state
	var is_leaf: bool = true
	var is_empty: bool = true
	var particle_idx: int = -1      # -1 if internal or empty
	var particle_pos: Vector3 = Vector3.ZERO
	var particle_mass: float = 0.0
	var depth: int = 0
	
	# Coincident particles at MAX_DEPTH or identical coordinates
	var coincident_indices: PackedInt32Array = PackedInt32Array()
	
	# Children octants (size 8; unused children remain null)
	var children: Array = []
```

### 3.2 Canonical 3D Morton/Octant Indexing
Subdividing a cube of center $\vec{c} = (c_x, c_y, c_z)$ into 8 octants uses a 3-bit integer index $k \in [0, 7]$:
- Bit 0 ($+1$): $x \ge c_x$
- Bit 1 ($+2$): $y \ge c_y$
- Bit 2 ($+4$): $z \ge c_z$

```gdscript
func _get_octant(c: Vector3, p: Vector3) -> int:
	var oct: int = 0
	if p.x >= c.x:
		oct |= 1
	if p.y >= c.y:
		oct |= 2
	if p.z >= c.z:
		oct |= 4
	return oct
```

For octant $k$:
```gdscript
func _calculate_child_bounds(parent_bounds: AABB, k: int) -> AABB:
	var half: Vector3 = parent_bounds.size * 0.5
	var origin: Vector3 = parent_bounds.position
	if (k & 1) != 0: origin.x += half.x
	if (k & 2) != 0: origin.y += half.y
	if (k & 4) != 0: origin.z += half.z
	return AABB(origin, half)
```
This indexing scheme is completely deterministic, branchless in bitwise logic, and covers $\mathbb{R}^3$ without spatial gaps.

### 3.3 Root Bounding Box Construction & Degeneracy Guards
If particles lie in a 2D plane (e.g. flat disc galaxy with $z = 0$) or along a line, an unconstrained `AABB` has zero thickness along that axis ($size.z = 0$). Dividing a zero-thickness box produces degenerate child octants.
**Defensive Strategy**:
1. Compute the axis-aligned bounding box enclosing all active particles.
2. Determine the maximum dimension: $S = \max(\text{extent.x}, \text{extent.y}, \text{extent.z})$.
3. Enforce a minimum size: $S = \max(S, \text{MIN\_BOUNDS\_SIZE})$ where $\text{MIN\_BOUNDS\_SIZE} = 10^{-4}$.
4. Pad by a safety margin of $2\%$ ($1.02$) to ensure no particle on the boundary falls outside due to floating-point rounding.
5. Center the cubic root box at the particle bounding box centroid:
   $$\text{origin} = \text{center} - (S \cdot 0.51, S \cdot 0.51, S \cdot 0.51)$$
   $$\text{size} = (S \cdot 1.02, S \cdot 1.02, S \cdot 1.02)$$

---

## 4. Algorithmic Mechanics & Recursion-Free Design

### 4.1 Zero-Recursion Iterative Tree Insertion
In typical recursive tree building, if two particles have nearly identical positions, the tree subdivides dozens of times down a narrow branch, consuming call stack frames. In Godot 4, deep call stacks risk engine crashes.

Our design implements **100% iterative insertion** using a `while true` loop:

```
Algorithm: Iterative Octree Insertion
Inputs: p_idx, p_pos, p_mass
1. Set current = root
2. Loop:
   a. If current is empty leaf:
      Store particle in current; update current.total_mass and center_of_mass.
      Break.
   b. If current is non-empty leaf:
      If current.depth >= MAX_DEPTH or p_pos.is_equal_approx(current.particle_pos):
         Append p_idx to current.coincident_indices; update mass & CoM.
         Break.
      Subdivide current:
         Save old particle (old_idx, old_pos, old_mass).
         current.is_leaf = false; current.particle_idx = -1.
         Insert old particle into child octant k_old.
         Update current mass & CoM with p_mass and p_pos.
         Set current = child octant k_new for p_pos.
         Continue loop.
   c. If current is internal node:
      Update current mass & CoM.
      Set current = child octant k for p_pos.
      Continue loop.
```
Because `depth` increases strictly on each subdivision and is capped by `MAX_DEPTH = 32`, this loop is strictly guaranteed to terminate with zero call stack consumption.

### 4.2 Zero-Recursion Iterative Tree Traversal
Force and potential calculations use an explicit traversal stack (`Array[OctreeNode]`) rather than function recursion:
1. Pre-allocate stack to size 64: `var stack: Array[OctreeNode] = []; stack.resize(64)`.
2. Push `root` to stack at index 0.
3. While `stack_ptr > 0`:
   - Pop node.
   - If leaf: evaluate direct pairwise force between query position and leaf particles (excluding `target_idx`).
   - If internal node: check $s^2 \le \theta_{sq} \cdot d^2$.
     - If true: approximate node as point mass, accumulate acceleration, do not open children.
     - If false: push non-null children onto stack.

This guarantees:
- **Zero call stack consumption**.
- Stack size never exceeds $8 \times \text{MAX\_DEPTH} \approx 256$ elements even in the deepest pathological trees.
- No risk of GDScript stack overflow.

---

## 5. Concrete GDScript 2.0 Architectural Blueprint

Below is the complete, production-ready specification and code blueprint for `res://core/physics/barnes_hut_octree.gd`.

```gdscript
class_name BarnesHutOctree
extends RefCounted

## 3D Hierarchical Barnes-Hut Octree for O(N log N) Gravitational & Electrostatic Force Acceleration.
##
## Features:
## - Symplectic-compatible long-range force and acceleration calculation.
## - Multipole Acceptance Criterion (MAC) opening angle theta = size / distance <= theta_crit.
## - Zero recursion: fully iterative tree building and iterative stack traversal.
## - Reusable node pool preventing garbage collection frame drops.
## - Edge case guards: coincident particles, zero mass, degenerate bounding boxes, softening.
## - Strict GDScript 2.0 static typing with zero untyped Variants.

# ==============================================================================
# Constants & Configuration Defaults
# ==============================================================================
const DEFAULT_THETA: float = 0.5
const DEFAULT_SOFTENING: float = 0.05
const DEFAULT_G: float = 1.0
const MAX_DEPTH: int = 32
const MIN_BOUNDS_SIZE: float = 1e-4
const EPSILON_SINGULARITY: float = 1e-12

# ==============================================================================
# Inner Class: OctreeNode
# ==============================================================================
class OctreeNode extends RefCounted:
	var bounds: AABB = AABB()
	var center: Vector3 = Vector3.ZERO
	var size: float = 0.0
	var size_squared: float = 0.0
	
	var total_mass: float = 0.0
	var center_of_mass: Vector3 = Vector3.ZERO
	
	var is_leaf: bool = true
	var is_empty: bool = true
	var particle_idx: int = -1
	var particle_pos: Vector3 = Vector3.ZERO
	var particle_mass: float = 0.0
	var depth: int = 0
	
	var coincident_indices: PackedInt32Array = PackedInt32Array()
	var children: Array = [] # Size 8, elements are OctreeNode or null
	
	func _init() -> void:
		children.resize(8)
		children.fill(null)
	
	func reset(p_bounds: AABB, p_depth: int) -> void:
		bounds = p_bounds
		center = p_bounds.position + p_bounds.size * 0.5
		size = p_bounds.size.x
		size_squared = size * size
		
		total_mass = 0.0
		center_of_mass = Vector3.ZERO
		
		is_leaf = true
		is_empty = true
		particle_idx = -1
		particle_pos = Vector3.ZERO
		particle_mass = 0.0
		depth = p_depth
		
		coincident_indices.clear()
		children.fill(null)

# ==============================================================================
# Public Properties
# ==============================================================================
var theta_crit: float = DEFAULT_THETA
var softening: float = DEFAULT_SOFTENING
var gravitational_constant: float = DEFAULT_G

# ==============================================================================
# Internal State & Memory Pool
# ==============================================================================
var _root: OctreeNode = null
var _root_bounds: AABB = AABB()
var _particle_count: int = 0
var _node_count: int = 0
var _max_depth_reached: int = 0

# Node object recycling pool
var _node_pool: Array[OctreeNode] = []
var _pool_cursor: int = 0

# Cached particle arrays for fast lookups
var _cached_positions: PackedVector3Array = PackedVector3Array()
var _cached_masses: PackedFloat32Array = PackedFloat32Array()

# Traversal stack cache for zero-allocation queries
var _traversal_stack: Array[OctreeNode] = []
var _stack_ptr: int = 0

# ==============================================================================
# Initialization
# ==============================================================================
func _init(p_theta: float = DEFAULT_THETA, p_softening: float = DEFAULT_SOFTENING, p_g: float = DEFAULT_G) -> void:
	theta_crit = maxf(0.0, p_theta)
	softening = maxf(0.0, p_softening)
	gravitational_constant = p_g
	_traversal_stack.resize(128)

# ==============================================================================
# Tree Construction API
# ==============================================================================

## Builds the octree from particle positions and masses.
## Automatically calculates cubic bounding box with padding.
func build(positions: PackedVector3Array, masses: PackedFloat32Array) -> void:
	clear()
	var n: int = positions.size()
	if n == 0 or masses.size() != n:
		if masses.size() != n:
			push_error("BarnesHutOctree: positions and masses array size mismatch (%d vs %d)" % [n, masses.size()])
		return
	
	_cached_positions = positions
	_cached_masses = masses
	_particle_count = n
	
	# Compute cubic root bounds
	_root_bounds = _compute_cubic_bounds(positions)
	_root = _acquire_node(_root_bounds, 0)
	_node_count = 1
	_max_depth_reached = 0
	
	# Insert particles iteratively
	for i in range(n):
		_insert_particle(i, positions[i], maxf(0.0, masses[i]))

## Builds the octree with explicitly provided bounds.
func build_with_bounds(positions: PackedVector3Array, masses: PackedFloat32Array, custom_bounds: AABB) -> void:
	clear()
	var n: int = positions.size()
	if n == 0 or masses.size() != n:
		return
	
	_cached_positions = positions
	_cached_masses = masses
	_particle_count = n
	
	# Ensure custom bounds are cubic and padded
	var max_dim: float = maxf(maxf(custom_bounds.size.x, custom_bounds.size.y), custom_bounds.size.z)
	max_dim = maxf(max_dim, MIN_BOUNDS_SIZE)
	var center: Vector3 = custom_bounds.position + custom_bounds.size * 0.5
	var half: float = max_dim * 0.5 * 1.02
	_root_bounds = AABB(center - Vector3(half, half, half), Vector3(half * 2.0, half * 2.0, half * 2.0))
	
	_root = _acquire_node(_root_bounds, 0)
	_node_count = 1
	_max_depth_reached = 0
	
	for i in range(n):
		_insert_particle(i, positions[i], maxf(0.0, masses[i]))

## Clears tree structure and resets pool cursor without freeing allocated node instances.
func clear() -> void:
	_root = null
	_root_bounds = AABB()
	_particle_count = 0
	_node_count = 0
	_max_depth_reached = 0
	_pool_cursor = 0
	_cached_positions = PackedVector3Array()
	_cached_masses = PackedFloat32Array()

# ==============================================================================
# Force & Acceleration Queries
# ==============================================================================

## Computes gravitational acceleration vector at target_pos.
## [param target_idx]: Index of query particle to exclude self-interaction (-1 if external probe).
func compute_acceleration(
	target_idx: int,
	target_pos: Vector3,
	p_theta: float = -1.0,
	p_softening: float = -1.0,
	p_g: float = -1.0
) -> Vector3:
	if _root == null or _root.is_empty:
		return Vector3.ZERO
	
	var eff_theta: float = theta_crit if p_theta < 0.0 else maxf(0.0, p_theta)
	var eff_soft: float = softening if p_softening < 0.0 else maxf(0.0, p_softening)
	var eff_g: float = gravitational_constant if p_g < 0.0 else p_g
	
	var eps_sq: float = eff_soft * eff_soft
	var theta_sq: float = eff_theta * eff_theta
	var acc: Vector3 = Vector3.ZERO
	
	_stack_ptr = 0
	_traversal_stack[0] = _root
	_stack_ptr = 1
	
	while _stack_ptr > 0:
		_stack_ptr -= 1
		var node: OctreeNode = _traversal_stack[_stack_ptr]
		if node == null or node.is_empty:
			continue
		
		# 1. Leaf Node Evaluation
		if node.is_leaf:
			if node.particle_idx >= 0 and node.particle_idx != target_idx:
				var dr: Vector3 = node.particle_pos - target_pos
				var dist_sq: float = dr.length_squared()
				var denom: float = dist_sq + eps_sq
				if denom > EPSILON_SINGULARITY:
					var inv_dist: float = 1.0 / sqrt(denom)
					var inv_dist3: float = inv_dist * inv_dist * inv_dist
					acc += dr * (eff_g * node.particle_mass * inv_dist3)
			
			if not node.coincident_indices.is_empty():
				for c_idx in node.coincident_indices:
					if c_idx != target_idx and c_idx != node.particle_idx:
						var c_mass: float = _cached_masses[c_idx] if c_idx < _cached_masses.size() else 0.0
						var dr: Vector3 = node.particle_pos - target_pos
						var dist_sq: float = dr.length_squared()
						var denom: float = dist_sq + eps_sq
						if denom > EPSILON_SINGULARITY:
							var inv_dist: float = 1.0 / sqrt(denom)
							var inv_dist3: float = inv_dist * inv_dist * inv_dist
							acc += dr * (eff_g * c_mass * inv_dist3)
			continue
		
		# 2. Internal Node Multipole Acceptance Criterion (MAC)
		var dr_node: Vector3 = node.center_of_mass - target_pos
		var dist_sq_node: float = dr_node.length_squared()
		
		# s^2 <= theta_sq * d^2 check (eliminates square root)
		if node.size_squared <= theta_sq * dist_sq_node:
			var denom: float = dist_sq_node + eps_sq
			if denom > EPSILON_SINGULARITY:
				var inv_dist: float = 1.0 / sqrt(denom)
				var inv_dist3: float = inv_dist * inv_dist * inv_dist
				acc += dr_node * (eff_g * node.total_mass * inv_dist3)
		else:
			# Open node and push non-null children
			for c in range(8):
				var child: OctreeNode = node.children[c]
				if child != null and not child.is_empty:
					if _stack_ptr >= _traversal_stack.size():
						_traversal_stack.resize(_traversal_stack.size() * 2)
					_traversal_stack[_stack_ptr] = child
					_stack_ptr += 1
	
	return acc

## Computes gravitational force vector: F = m * a.
func compute_force(
	target_idx: int,
	target_pos: Vector3,
	target_mass: float,
	p_theta: float = -1.0,
	p_softening: float = -1.0,
	p_g: float = -1.0
) -> Vector3:
	return compute_acceleration(target_idx, target_pos, p_theta, p_softening, p_g) * target_mass

## Batch computes gravitational accelerations for all particles.
## Returns PackedVector3Array of size N matching input array order.
func compute_all_accelerations(
	positions: PackedVector3Array,
	masses: PackedFloat32Array,
	p_theta: float = -1.0,
	p_softening: float = -1.0,
	p_g: float = -1.0
) -> PackedVector3Array:
	var n: int = positions.size()
	if n == 0 or masses.size() != n:
		return PackedVector3Array()
	
	# Rebuild tree if cached count or references changed
	if _particle_count != n or _cached_positions != positions:
		build(positions, masses)
	
	var accels: PackedVector3Array = PackedVector3Array()
	accels.resize(n)
	for i in range(n):
		accels[i] = compute_acceleration(i, positions[i], p_theta, p_softening, p_g)
	return accels

## Batch computes gravitational forces for all particles. Direct compatibility with PhysicalIntegrator.
func compute_all_forces(
	positions: PackedVector3Array,
	masses: PackedFloat32Array,
	p_theta: float = -1.0,
	p_softening: float = -1.0,
	p_g: float = -1.0
) -> PackedVector3Array:
	var n: int = positions.size()
	if n == 0 or masses.size() != n:
		return PackedVector3Array()
	
	if _particle_count != n or _cached_positions != positions:
		build(positions, masses)
	
	var forces: PackedVector3Array = PackedVector3Array()
	forces.resize(n)
	for i in range(n):
		forces[i] = compute_acceleration(i, positions[i], p_theta, p_softening, p_g) * masses[i]
	return forces

# ==============================================================================
# Gravitational Potential API (ConservationSentry Integration)
# ==============================================================================

## Computes gravitational potential Phi(r) at target_pos.
func compute_potential_at(
	target_idx: int,
	target_pos: Vector3,
	p_theta: float = -1.0,
	p_softening: float = -1.0,
	p_g: float = -1.0
) -> float:
	if _root == null or _root.is_empty:
		return 0.0
	
	var eff_theta: float = theta_crit if p_theta < 0.0 else maxf(0.0, p_theta)
	var eff_soft: float = softening if p_softening < 0.0 else maxf(0.0, p_softening)
	var eff_g: float = gravitational_constant if p_g < 0.0 else p_g
	
	var eps_sq: float = eff_soft * eff_soft
	var theta_sq: float = eff_theta * eff_theta
	var potential: float = 0.0
	
	_stack_ptr = 0
	_traversal_stack[0] = _root
	_stack_ptr = 1
	
	while _stack_ptr > 0:
		_stack_ptr -= 1
		var node: OctreeNode = _traversal_stack[_stack_ptr]
		if node == null or node.is_empty:
			continue
		
		if node.is_leaf:
			if node.particle_idx >= 0 and node.particle_idx != target_idx:
				var dist_sq: float = (node.particle_pos - target_pos).length_squared()
				var denom: float = dist_sq + eps_sq
				if denom > EPSILON_SINGULARITY:
					potential -= eff_g * node.particle_mass / sqrt(denom)
			
			if not node.coincident_indices.is_empty():
				for c_idx in node.coincident_indices:
					if c_idx != target_idx and c_idx != node.particle_idx:
						var c_mass: float = _cached_masses[c_idx] if c_idx < _cached_masses.size() else 0.0
						var dist_sq: float = (node.particle_pos - target_pos).length_squared()
						var denom: float = dist_sq + eps_sq
						if denom > EPSILON_SINGULARITY:
							potential -= eff_g * c_mass / sqrt(denom)
			continue
		
		var dr_node: Vector3 = node.center_of_mass - target_pos
		var dist_sq_node: float = dr_node.length_squared()
		
		if node.size_squared <= theta_sq * dist_sq_node:
			var denom: float = dist_sq_node + eps_sq
			if denom > EPSILON_SINGULARITY:
				potential -= eff_g * node.total_mass / sqrt(denom)
		else:
			for c in range(8):
				var child: OctreeNode = node.children[c]
				if child != null and not child.is_empty:
					if _stack_ptr >= _traversal_stack.size():
						_traversal_stack.resize(_traversal_stack.size() * 2)
					_traversal_stack[_stack_ptr] = child
					_stack_ptr += 1
	
	return potential

## Computes total gravitational potential energy U = 0.5 * sum(m_i * Phi(r_i)).
func compute_total_potential_energy(
	positions: PackedVector3Array,
	masses: PackedFloat32Array,
	p_theta: float = -1.0,
	p_softening: float = -1.0,
	p_g: float = -1.0
) -> float:
	var n: int = positions.size()
	if n < 2 or masses.size() != n:
		return 0.0
	
	if _particle_count != n or _cached_positions != positions:
		build(positions, masses)
	
	var total_u: float = 0.0
	for i in range(n):
		var phi: float = compute_potential_at(i, positions[i], p_theta, p_softening, p_g)
		total_u += masses[i] * phi
	return 0.5 * total_u

# ==============================================================================
# Introspection & Metrics
# ==============================================================================
func get_particle_count() -> int: return _particle_count
func get_node_count() -> int: return _node_count
func get_max_depth() -> int: return _max_depth_reached
func get_root_bounds() -> AABB: return _root_bounds
func is_empty() -> bool: return _root == null or _root.is_empty
func get_total_mass() -> float: return 0.0 if _root == null else _root.total_mass
func get_center_of_mass() -> Vector3: return Vector3.ZERO if _root == null else _root.center_of_mass
func get_pool_capacity() -> int: return _node_pool.size()

## Clears and frees memory pool.
func clear_memory_pool() -> void:
	clear()
	_node_pool.clear()

# ==============================================================================
# Internal Helper Methods
# ==============================================================================

func _acquire_node(p_bounds: AABB, p_depth: int) -> OctreeNode:
	var node: OctreeNode
	if _pool_cursor < _node_pool.size():
		node = _node_pool[_pool_cursor]
		node.reset(p_bounds, p_depth)
	else:
		node = OctreeNode.new()
		node.reset(p_bounds, p_depth)
		_node_pool.append(node)
	_pool_cursor += 1
	if p_depth > _max_depth_reached:
		_max_depth_reached = p_depth
	return node

func _compute_cubic_bounds(positions: PackedVector3Array) -> AABB:
	var min_pos: Vector3 = positions[0]
	var max_pos: Vector3 = positions[0]
	var n: int = positions.size()
	for i in range(1, n):
		var p: Vector3 = positions[i]
		min_pos.x = minf(min_pos.x, p.x)
		min_pos.y = minf(min_pos.y, p.y)
		min_pos.z = minf(min_pos.z, p.z)
		max_pos.x = maxf(max_pos.x, p.x)
		max_pos.y = maxf(max_pos.y, p.y)
		max_pos.z = maxf(max_pos.z, p.z)
	
	var extent: Vector3 = max_pos - min_pos
	var max_dim: float = maxf(maxf(extent.x, extent.y), extent.z)
	max_dim = maxf(max_dim, MIN_BOUNDS_SIZE)
	
	var center: Vector3 = (min_pos + max_pos) * 0.5
	var half: float = max_dim * 0.5 * 1.02 # 2% padding
	var origin: Vector3 = center - Vector3(half, half, half)
	var size: Vector3 = Vector3(half * 2.0, half * 2.0, half * 2.0)
	return AABB(origin, size)

func _get_octant(c: Vector3, p: Vector3) -> int:
	var oct: int = 0
	if p.x >= c.x: oct |= 1
	if p.y >= c.y: oct |= 2
	if p.z >= c.z: oct |= 4
	return oct

func _calculate_child_bounds(parent_bounds: AABB, k: int) -> AABB:
	var half: Vector3 = parent_bounds.size * 0.5
	var origin: Vector3 = parent_bounds.position
	if (k & 1) != 0: origin.x += half.x
	if (k & 2) != 0: origin.y += half.y
	if (k & 4) != 0: origin.z += half.z
	return AABB(origin, half)

func _insert_particle(p_idx: int, p_pos: Vector3, p_mass: float) -> void:
	var current: OctreeNode = _root
	
	while true:
		# Case 1: Empty leaf node
		if current.is_empty:
			current.is_empty = false
			current.is_leaf = true
			current.particle_idx = p_idx
			current.particle_pos = p_pos
			current.particle_mass = p_mass
			current.total_mass = p_mass
			current.center_of_mass = p_pos
			break
		
		# Case 2: Non-empty leaf node -> subdivide or handle coincident
		if current.is_leaf:
			if current.depth >= MAX_DEPTH or p_pos.is_equal_approx(current.particle_pos):
				if current.coincident_indices.is_empty():
					current.coincident_indices.append(current.particle_idx)
				current.coincident_indices.append(p_idx)
				
				var combined_mass: float = current.total_mass + p_mass
				if combined_mass > EPSILON_SINGULARITY:
					current.center_of_mass = (current.center_of_mass * current.total_mass + p_pos * p_mass) / combined_mass
				else:
					current.center_of_mass = p_pos
				current.total_mass = combined_mass
				break
			
			# Subdivide current leaf into internal node
			current.is_leaf = false
			var old_idx: int = current.particle_idx
			var old_pos: Vector3 = current.particle_pos
			var old_mass: float = current.particle_mass
			current.particle_idx = -1
			
			# Re-insert old particle into corresponding child octant
			var k_old: int = _get_octant(current.center, old_pos)
			if current.children[k_old] == null:
				current.children[k_old] = _acquire_node(_calculate_child_bounds(current.bounds, k_old), current.depth + 1)
				_node_count += 1
			var child_old: OctreeNode = current.children[k_old]
			child_old.is_empty = false
			child_old.is_leaf = true
			child_old.particle_idx = old_idx
			child_old.particle_pos = old_pos
			child_old.particle_mass = old_mass
			child_old.total_mass = old_mass
			child_old.center_of_mass = old_pos
			
			# Update current internal node's mass & CoM with new particle
			var new_mass: float = current.total_mass + p_mass
			if new_mass > EPSILON_SINGULARITY:
				current.center_of_mass = (current.center_of_mass * current.total_mass + p_pos * p_mass) / new_mass
			else:
				current.center_of_mass = p_pos
			current.total_mass = new_mass
			
			# Descend with new particle
			var k_new: int = _get_octant(current.center, p_pos)
			if current.children[k_new] == null:
				current.children[k_new] = _acquire_node(_calculate_child_bounds(current.bounds, k_new), current.depth + 1)
				_node_count += 1
			current = current.children[k_new]
		else:
			# Case 3: Internal node -> update mass & CoM and descend
			var new_mass: float = current.total_mass + p_mass
			if new_mass > EPSILON_SINGULARITY:
				current.center_of_mass = (current.center_of_mass * current.total_mass + p_pos * p_mass) / new_mass
			else:
				current.center_of_mass = p_pos
			current.total_mass = new_mass
			
			var k: int = _get_octant(current.center, p_pos)
			if current.children[k] == null:
				current.children[k] = _acquire_node(_calculate_child_bounds(current.bounds, k), current.depth + 1)
				_node_count += 1
			current = current.children[k]
```

---

## 6. Edge Cases, Numerical Stability & Defenses

| # | Edge Case | Mathematical Hazard | Architectural Defense |
|---|---|---|---|
| 1 | **Coincident Particles** ($\vec{r}_i = \vec{r}_j$) | Infinite tree subdivision down identical octants causing stack overflow or hang. | Guard: `p_pos.is_equal_approx(current.particle_pos)` skips subdivision and stores index in `coincident_indices`. |
| 2 | **Pathological Clustering** | Extremely dense clusters exceeding float resolution. | Guard: `current.depth >= MAX_DEPTH (32)` terminates descent and stores multiple particles in the leaf. |
| 3 | **Degenerate Bounding Box** | Planar (2D) or linear (1D) particle sets where $size.z = 0$. | Guard: Root bounds are forced to cubic aspect ratio with size $\ge \text{MIN\_BOUNDS\_SIZE} (10^{-4})$ and $2\%$ margin. |
| 4 | **Zero / Negative Mass** | Division by zero during Center of Mass weighting or $0/0$ `NaN`. | Guard: Negative masses clamped to $0.0$; if combined mass $< 10^{-12}$, center of mass defaults to particle position without division. |
| 5 | **Zero Distance Force Singularity** ($r \to 0$) | Inverse-square force blows up to infinity ($\text{INF}$ or $\text{NaN}$). | Softening parameter $\epsilon > 0$ ensures denominator is $(r^2 + \epsilon^2)^{3/2} \ge \epsilon^3 > 0$. If $\epsilon = 0$ and $r < 10^{-6}$, force contribution is guarded to 0. |
| 6 | **Self-Interaction Corruption** | Body calculates gravitational pull on itself, violating Newton's third law. | Query checks `target_idx != node.particle_idx` and `target_idx != c_idx` to guarantee zero self-acceleration. |
| 7 | **Memory Allocation Churn** | Rebuilding tree at 60 Hz creates 10,000+ objects/sec, causing GC frame stutter. | Pre-allocated, reusable `_node_pool` recycles existing `OctreeNode` instances with zero allocations on subsequent frames. |
| 8 | **Direct Summation Equivalence** | Approximate algorithm deviating unpredictably. | Setting $\theta_{crit} = 0.0$ forces traversal to open every internal node, guaranteeing 100% exact numerical match with naive $O(N^2)$ direct summation. |

---

## 7. Integration with UniCORE Ecosystem

### 7.1 Integration with `NBodyGravityModule` (Milestone 3)
In `NBodyGravityModule`, computing the pairwise accelerations of celestial bodies is delegated directly to `BarnesHutOctree`:
```gdscript
# Inside NBodyGravityModule
var _octree: BarnesHutOctree = BarnesHutOctree.new(0.5, softening_parameter, gravitational_constant)

func _compute_forces(pos: PackedVector3Array) -> PackedVector3Array:
	_octree.build(pos, masses)
	return _octree.compute_all_forces(pos, masses)
```

### 7.2 Integration with `ConservationSentry` (Milestone 2)
When `ConservationSentry.audit(...)` is called, it accepts `potential_calculator: Callable`:
```gdscript
# Fast O(N log N) potential calculator passed to ConservationSentry
var pot_calculator: Callable = func(pos: PackedVector3Array) -> float:
	_octree.build(pos, masses)
	return _octree.compute_total_potential_energy(pos, masses)

var snapshot: Dictionary = sentry.audit(positions, velocities, masses, pot_calculator)
```

### 7.3 Compatibility with `PhysicalIntegrator` (`VerletIntegrator`)
`compute_all_forces` returns `PackedVector3Array` directly matching the contract of `PhysicalIntegrator.integrate(...)`. Symplectic velocity-verlet integration preserves phase space volume and Keplerian orbital invariants with zero secular energy drift over thousands of steps.

---

## 8. Verification Strategy & Test Harness Blueprint

The verification of `BarnesHutOctree` will be executed via a dedicated test suite in `res://tests/test_physics_engine_suite.gd` (or `test_barnes_hut_octree_verification.gd`).

### Test Suite Structure:
1. **Test 1: Contract & Instantiation Parity**:
   - `BarnesHutOctree.new()` instantiates cleanly.
   - Verifies properties: `theta_crit`, `softening`, `gravitational_constant`.
2. **Test 2: Empty & Single-Particle Edge Cases**:
   - Empty input arrays: returns `Vector3.ZERO`, empty array, zero potential energy, zero nodes.
   - Single particle: returns zero acceleration (no self-gravity), zero potential energy.
3. **Test 3: Coincident Particles & Max Depth Defense**:
   - 10 particles at identical coordinate `Vector3(10.0, 10.0, 10.0)` with mass $1.0$.
   - Tree builds with `node_count == 1`, `particle_count == 10`, `total_mass == 10.0`.
   - Max depth $\le \text{MAX\_DEPTH}$. Zero infinite loop.
4. **Test 4: Direct Summation Equivalence ($\theta = 0.0$)**:
   - 100 randomly distributed particles in $[-10, 10]^3$.
   - Compute accelerations via direct $O(N^2)$ summation.
   - Compute accelerations via `octree.compute_all_accelerations(..., theta = 0.0)`.
   - Verify every acceleration vector matches within $10^{-5}$ tolerance.
   - Verify total potential energy matches direct $U_{direct}$ within $10^{-5}$.
5. **Test 5: Multipole Approximation Accuracy ($\theta = 0.5$)**:
   - Two distant clusters of 250 particles each at separation $D = 100$.
   - Verify relative force error $|a_{bh} - a_{direct}| / |a_{direct}| < 0.01$ (less than 1% error).
6. **Test 6: Algorithmic Scaling & Complexity ($O(N \log N)$ vs $O(N^2)$)**:
   - Run benchmark with $N = 1,000$ and $N = 3,000$ particles.
   - Verify execution time scales as $O(N \log N)$ rather than quadratic $O(N^2)$.
7. **Test 7: Node Pool Reuse & Zero Allocation**:
   - Build octree 50 times consecutively.
   - Verify `get_pool_capacity()` reaches a stable value and does not grow indefinitely.

---

## 9. Conclusion & Recommendations for Worker Subagent
- The blueprint provides a complete, drop-in specification for `res://core/physics/barnes_hut_octree.gd`.
- Strictly adheres to Godot 4.0.stable and GDScript 2.0 static typing rules.
- Fully eliminates recursion stack overflow risks through iterative loops and explicit traversal stacks.
- Provides zero-allocation node pooling for sustained high framerates in real-time simulation.
