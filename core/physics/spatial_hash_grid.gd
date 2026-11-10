class_name SpatialHashGrid
extends RefCounted

## 3D Uniform Spatial Hashing Grid for O(N) neighbor searches in physical simulations.
## Partitions continuous 3D vacuum space into uniform cubes of side length `cell_size`.
## Coordinates are mapped via large prime hashing into discrete buckets for rapid retrieval.

const P1: int = 73856093
const P2: int = 19349663
const P3: int = 83492791
const DEFAULT_CAPACITY: int = 10000
const MIN_CELL_SIZE: float = 1e-6
const MAX_CELL_SPAN: int = 100

var cell_size: float = 1.0
var inverse_cell_size: float = 1.0
var _grid: Dictionary = {}
var _positions: PackedVector3Array = PackedVector3Array()
var _particle_count: int = 0

## Initializes the spatial grid with cell size and precalculated inverse scale.
func initialize(p_cell_size: float, expected_capacity: int = DEFAULT_CAPACITY) -> void:
	if p_cell_size <= MIN_CELL_SIZE:
		push_error("SpatialHashGrid: cell_size must be >= %f, defaulting to 1.0" % MIN_CELL_SIZE)
		cell_size = 1.0
	else:
		cell_size = p_cell_size
	inverse_cell_size = 1.0 / cell_size
	clear()

## Clears all buckets and resets particle caches.
func clear() -> void:
	_grid.clear()
	_positions = PackedVector3Array()
	_particle_count = 0

## Computes 64-bit prime hash for 3D lattice coordinates.
func hash_coords(ix: int, iy: int, iz: int) -> int:
	return (ix * P1) ^ (iy * P2) ^ (iz * P3)

## Converts 3D world position to integer cell lattice coordinates using floor division.
func get_cell_coords(position: Vector3) -> Vector3i:
	return Vector3i(
		int(floor(position.x * inverse_cell_size)),
		int(floor(position.y * inverse_cell_size)),
		int(floor(position.z * inverse_cell_size))
	)

## Inserts a single particle index at the specified 3D position.
func insert(particle_idx: int, position: Vector3) -> void:
	if particle_idx < 0:
		push_error("SpatialHashGrid: particle_idx cannot be negative: %d" % particle_idx)
		return
	
	if particle_idx >= _positions.size():
		_positions.resize(particle_idx + 1)
	_positions[particle_idx] = position
	_particle_count = maxi(_particle_count, particle_idx + 1)
	
	var coords: Vector3i = get_cell_coords(position)
	var h: int = hash_coords(coords.x, coords.y, coords.z)
	
	if _grid.has(h):
		var bucket: PackedInt32Array = _grid[h]
		bucket.append(particle_idx)
		_grid[h] = bucket
	else:
		var bucket: PackedInt32Array = PackedInt32Array()
		bucket.append(particle_idx)
		_grid[h] = bucket

## Bulk builds the grid from a contiguous array of particle positions.
func build_grid(positions: PackedVector3Array) -> void:
	clear()
	var n: int = positions.size()
	if n == 0:
		return
	
	_positions = positions.duplicate()
	_particle_count = n
	var inv_c: float = inverse_cell_size
	
	for i in range(n):
		var pos: Vector3 = positions[i]
		var ix: int = int(floor(pos.x * inv_c))
		var iy: int = int(floor(pos.y * inv_c))
		var iz: int = int(floor(pos.z * inv_c))
		var h: int = (ix * P1) ^ (iy * P2) ^ (iz * P3)
		
		if _grid.has(h):
			var bucket: PackedInt32Array = _grid[h]
			bucket.append(i)
			_grid[h] = bucket
		else:
			var bucket: PackedInt32Array = PackedInt32Array()
			bucket.append(i)
			_grid[h] = bucket

## Queries neighbor particle indices within search_radius of position using internal position buffer.
func get_neighbors(position: Vector3, search_radius: float) -> PackedInt32Array:
	return get_neighbors_in_radius(position, search_radius, _positions)

## Queries neighbor particle indices within search_radius using explicitly provided positions array.
func get_neighbors_in_radius(
	query_pos: Vector3,
	search_radius: float,
	positions: PackedVector3Array
) -> PackedInt32Array:
	if search_radius < 0.0 or _grid.is_empty():
		return PackedInt32Array()
	
	var n_pos: int = positions.size()
	if n_pos == 0:
		return PackedInt32Array()
	
	var r_sq: float = search_radius * search_radius
	var inv_c: float = inverse_cell_size
	
	var min_ix: int = int(floor((query_pos.x - search_radius) * inv_c))
	var max_ix: int = int(floor((query_pos.x + search_radius) * inv_c))
	var min_iy: int = int(floor((query_pos.y - search_radius) * inv_c))
	var max_iy: int = int(floor((query_pos.y + search_radius) * inv_c))
	var min_iz: int = int(floor((query_pos.z - search_radius) * inv_c))
	var max_iz: int = int(floor((query_pos.z + search_radius) * inv_c))
	
	# Clamp search bounds to guard against runaway radii
	if max_ix - min_ix > MAX_CELL_SPAN:
		var center_x: int = int(floor(query_pos.x * inv_c))
		min_ix = center_x - MAX_CELL_SPAN / 2
		max_ix = center_x + MAX_CELL_SPAN / 2
	if max_iy - min_iy > MAX_CELL_SPAN:
		var center_y: int = int(floor(query_pos.y * inv_c))
		min_iy = center_y - MAX_CELL_SPAN / 2
		max_iy = center_y + MAX_CELL_SPAN / 2
	if max_iz - min_iz > MAX_CELL_SPAN:
		var center_z: int = int(floor(query_pos.z * inv_c))
		min_iz = center_z - MAX_CELL_SPAN / 2
		max_iz = center_z + MAX_CELL_SPAN / 2
	
	var result: PackedInt32Array = PackedInt32Array()
	var visited_hashes: Dictionary = {}
	
	for ix in range(min_ix, max_ix + 1):
		for iy in range(min_iy, max_iy + 1):
			for iz in range(min_iz, max_iz + 1):
				var h: int = (ix * P1) ^ (iy * P2) ^ (iz * P3)
				if visited_hashes.has(h):
					continue
				visited_hashes[h] = true
				
				if not _grid.has(h):
					continue
				
				var bucket: PackedInt32Array = _grid[h]
				var b_size: int = bucket.size()
				for b in range(b_size):
					var p_idx: int = bucket[b]
					if p_idx >= 0 and p_idx < n_pos:
						var p_pos: Vector3 = positions[p_idx]
						if query_pos.distance_squared_to(p_pos) <= r_sq:
							result.append(p_idx)
	
	result.sort()
	return result

## Returns total number of particles registered in grid.
func get_particle_count() -> int:
	return _particle_count

## Returns number of active non-empty hash buckets.
func get_bucket_count() -> int:
	return _grid.size()

## Returns the raw list of particle indices in the cell at lattice coords without distance checks.
func get_bucket_particles(ix: int, iy: int, iz: int) -> PackedInt32Array:
	var h: int = hash_coords(ix, iy, iz)
	if _grid.has(h):
		return _grid[h]
	return PackedInt32Array()
