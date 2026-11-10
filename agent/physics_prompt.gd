extends RefCounted

## Versioned, locally verified callable API context; no C++ source upload needed.
const CONTEXT: String = """
PHYSICS AND INTERFACE CONTRACT (takes precedence over generic mesh spawning):
For calculated gravity/orbits use the existing n_body_gravity module, not animated meshes.
initialize(context) receives module_manager, time_controller, event_bus, world_root,
conservation_sentry and compute_backend. Call super.initialize(context).
Resolve gravity with context.module_manager.get_module("n_body_gravity"). If absent,
load it through context.module_manager.load_module_from_script("n_body_gravity",
preload("res://modules/physics/n_body_gravity_module.gd")). Never instantiate a hidden
child solver: the object editor discovers modules registered with ModuleManager.
Do not clear an existing scene unless requested. Track names you create and remove
only those names in cleanup(); never unload a shared gravity module.

Verified gravity API:
add_body(name: String, position: Vector3, velocity: Vector3, mass: float,
         radius: float = 0.2, color: Color = Color.WHITE) -> void
spawn_body(position: Vector3, velocity: Vector3, mass: float, body_type = "planet") -> void
remove_body_by_name(name: String) -> bool
get_editable_body(name: String) -> Dictionary
edit_body(name: String, property: String, value: Variant) -> bool
Properties: position/velocity (Vector3), mass/radius (positive finite number),
color (Color), name (unique nonempty String). Use unique body names.
Use edit_body for physical changes; never move just a visual mesh or mutate private arrays.
get_positions(), get_velocities(), get_masses(), get_radii(), get_particle_count()
get_force_snapshot() returns forces evaluated at the current state without stepping.
clear_particles() removes ALL bodies; use only for an explicitly requested replacement.
Defaults are normalized units: gravitational_constant=1, softening=0.05,
speed_of_light=50, relativity enabled. Do not claim SI units without configuring a
consistent scale. For Newtonian models disable enable_relativity and set
post_newtonian_mode=0. Explain unsupported physics honestly; never fake calculations.

The registered solver renders its own bodies from authoritative numerical positions.
Its sim_tick connection already integrates them. Do not call step() from a generated
_process/_physics_process, create another clock, or animate an orbit with sin/cos.
context.time_controller provides set_time_scale(float), set_paused(bool),
toggle_pause(), step_once(). Simulation speed changes elapsed time; edit_body velocity
changes physical initial conditions. Keep these distinct. Do not reset shared time
for a local body edit. Reset your model by restoring captured body initial conditions
through edit_body, including removing added bodies and restoring removed bodies.
Use the existing inspector/selection path; solver bodies remain editable while paused.

Native C++ calculations run locally through the solver bindings. compute_backend
accepts inherit/gdscript/native/auto. get_last_step_backend() reports the last actual
integration backend, not a promise about future execution. Do not claim native
execution from configuration alone. Do not paste C++ into GDScript or invent APIs.
For molecular, quantum and nuclear requests, use their actual registered module APIs
only when present in supplied context; gravity properties are not universal controls.
Apply this contract to new generation, edits, repairs and provider fallback.
"""
