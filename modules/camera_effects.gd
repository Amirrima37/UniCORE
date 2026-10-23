extends UniCoreModule

var _camera: Camera3D
var _base_fov: float = 75.0
var _target_fov: float = 75.0
var _time_passed: float = 0.0

func get_module_id() -> String:
	return "camera_effects"

func get_module_name() -> String:
	return "Камера: Процедурные Эффекты и FOV"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	var vp := get_viewport()
	if vp:
		_camera = vp.get_camera_3d()
	if _camera:
		_base_fov = _camera.fov
		_target_fov = _base_fov
	return true

func _process(delta: float) -> void:
	if not is_initialized:
		return
	if not _camera:
		var vp := get_viewport()
		if vp:
			_camera = vp.get_camera_3d()
		if not _camera:
			return
		_base_fov = _camera.fov
		_target_fov = _base_fov

	_time_passed += delta
	var bob_y := sin(_time_passed * 2.5) * 0.03
	var bob_x := cos(_time_passed * 1.25) * 0.02
	_camera.h_offset = bob_x
	_camera.v_offset = bob_y
	_camera.fov = lerpf(_camera.fov, _target_fov, delta * 4.0)

func set_speed_fov(is_sprinting: bool) -> void:
	_target_fov = (_base_fov + 12.0) if is_sprinting else _base_fov

func cleanup() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		_camera.fov = _base_fov
	super.cleanup()
