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
	
	_cached_positions = positions.duplicate()
	_cached_masses = masses.duplicate()
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
	
	_cached_positions = positions.duplicate()
	_cached_masses = masses.duplicate()
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
			if node.coincident_indices.is_empty():
				if node.particle_idx >= 0 and node.particle_idx != target_idx:
					var dr: Vector3 = node.particle_pos - target_pos
					var dist_sq: float = dr.length_squared()
					var denom: float = dist_sq + eps_sq
					if denom > EPSILON_SINGULARITY:
						var inv_dist: float = 1.0 / sqrt(denom)
						var inv_dist3: float = inv_dist * inv_dist * inv_dist
						acc += dr * (eff_g * node.particle_mass * inv_dist3)
			else:
				var n_coinc: int = node.coincident_indices.size()
				for c in range(n_coinc):
					var c_idx: int = node.coincident_indices[c]
					if c_idx != target_idx:
						var c_pos: Vector3 = _cached_positions[c_idx] if c_idx < _cached_positions.size() else node.particle_pos
						var c_mass: float = _cached_masses[c_idx] if c_idx < _cached_masses.size() else 0.0
						var dr: Vector3 = c_pos - target_pos
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
	
	# Rebuild tree if unbuilt, particle count, positions, or masses changed
	if _root == null or _particle_count != n or _cached_positions != positions or _cached_masses != masses:
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
	
	if _root == null or _particle_count != n or _cached_positions != positions or _cached_masses != masses:
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
			if node.coincident_indices.is_empty():
				if node.particle_idx >= 0 and node.particle_idx != target_idx:
					var dist_sq: float = (node.particle_pos - target_pos).length_squared()
					var denom: float = dist_sq + eps_sq
					if denom > EPSILON_SINGULARITY:
						potential -= eff_g * node.particle_mass / sqrt(denom)
			else:
				var n_coinc: int = node.coincident_indices.size()
				for c in range(n_coinc):
					var c_idx: int = node.coincident_indices[c]
					if c_idx != target_idx:
						var c_pos: Vector3 = _cached_positions[c_idx] if c_idx < _cached_positions.size() else node.particle_pos
						var c_mass: float = _cached_masses[c_idx] if c_idx < _cached_masses.size() else 0.0
						var dist_sq: float = (c_pos - target_pos).length_squared()
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
	
	if _root == null or _particle_count != n or _cached_positions != positions or _cached_masses != masses:
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
