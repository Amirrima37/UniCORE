extends UniCoreModule

var _particles: CPUParticles3D
var _particle_material: StandardMaterial3D

func get_module_id() -> String:
	return "particle_system"

func get_module_name() -> String:
	return "Эффекты: Фонтан Неоновых Частиц"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)

	_particles = CPUParticles3D.new()
	_particles.name = "NeonParticleFountain"
	_particles.amount = 120
	_particles.lifetime = 2.0
	_particles.speed_scale = 1.0
	_particles.explosiveness = 0.05
	_particles.randomness = 0.3

	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 0.3
	_particles.direction = Vector3(0, 1, 0)
	_particles.spread = 25.0
	_particles.gravity = Vector3(0, -9.8, 0)
	_particles.initial_velocity_min = 6.0
	_particles.initial_velocity_max = 9.0

	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16

	_particle_material = StandardMaterial3D.new()
	_particle_material.albedo_color = Color(0.0, 1.0, 0.85)
	_particle_material.emission_enabled = true
	_particle_material.emission = Color(0.0, 0.9, 0.8)
	_particle_material.emission_energy_multiplier = 2.5
	sphere.material = _particle_material

	_particles.mesh = sphere
	_particles.position = Vector3(0, 0.1, -3.0)
	add_child(_particles)
	_particles.emitting = true

	return true

func cleanup() -> void:
	if _particles and is_instance_valid(_particles):
		_particles.queue_free()
	super.cleanup()
