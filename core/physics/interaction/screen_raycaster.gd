class_name ScreenRaycaster
extends RefCounted

## Utility for Screen-to-World 3D Raycasting onto interaction planes in UniCORE.
## Allows the Observer Camera to interact with objects and space without physical colliders.

## Raycasts a 2D screen coordinate onto an arbitrary 3D plane.
## Returns null if the ray is parallel to the plane or facing away.
static func cast_to_plane(camera: Camera3D, screen_pos: Vector2, plane_normal: Vector3, plane_origin: Vector3) -> Variant:
	if not camera:
		return null
	
	var ray_origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos)
	
	var d: float = plane_normal.dot(plane_origin)
	var plane := Plane(plane_normal, d)
	
	return plane.intersects_ray(ray_origin, ray_dir)

## Raycasts onto a camera-facing billboard plane passing through anchor_pos.
## Ideal for dragging impulse vectors in 3D without perspective skew.
static func cast_to_camera_facing_plane(camera: Camera3D, screen_pos: Vector2, anchor_pos: Vector3) -> Variant:
	if not camera:
		return null
	var cam_basis: Basis = camera.global_transform.basis if camera.is_inside_tree() else camera.transform.basis
	var plane_normal: Vector3 = cam_basis.z.normalized()
	return cast_to_plane(camera, screen_pos, plane_normal, anchor_pos)

## Raycasts onto a depth plane situated at a fixed distance from the camera along its forward vector.
static func cast_to_depth_plane(camera: Camera3D, screen_pos: Vector2, depth: float = 10.0) -> Variant:
	if not camera:
		return null
	var cam_basis: Basis = camera.global_transform.basis if camera.is_inside_tree() else camera.transform.basis
	var forward: Vector3 = -cam_basis.z.normalized()
	var cam_pos: Vector3 = camera.global_position if camera.is_inside_tree() else camera.position
	var anchor: Vector3 = cam_pos + forward * depth
	return cast_to_camera_facing_plane(camera, screen_pos, anchor)

## Direct mathematical ray-plane intersection without requiring a Camera3D node.
static func ray_plane_intersection(ray_origin: Vector3, ray_dir: Vector3, plane_normal: Vector3, plane_d: float) -> Variant:
	var plane := Plane(plane_normal, plane_d)
	return plane.intersects_ray(ray_origin, ray_dir)
