class_name UnitConverter
extends RefCounted

## Universal Physical Unit Converter for UniCORE.
## Translates between SI units and reduced natural dimensionless simulation units
## (Lennard-Jones, Planck, Astronomical) to avoid IEEE-754 32-bit floating-point issues.

enum UnitSystem {
	SI,
	LENNARD_JONES,
	PLANCK,
	ASTRONOMICAL
}

enum PhysicalQuantity {
	LENGTH,
	MASS,
	TIME,
	VELOCITY,
	ACCELERATION,
	FORCE,
	ENERGY,
	MOMENTUM,
	ANGULAR_MOMENTUM,
	TEMPERATURE,
	PRESSURE,
	DENSITY,
	CHARGE
}

# Universal Physical Constants in SI
const SPEED_OF_LIGHT: float = 299792458.0                     # m / s
const PLANCK_CONSTANT_HBAR: float = 1.054571817e-34           # J * s
const GRAVITATIONAL_CONSTANT_G: float = 6.67430e-11           # m^3 / (kg * s^2)
const BOLTZMANN_CONSTANT_KB: float = 1.380649e-23             # J / K
const VACUUM_PERMITTIVITY_EPS0: float = 8.8541878128e-12     # F / m
const ELEMENTARY_CHARGE_E: float = 1.602176634e-19            # C
const ASTRONOMICAL_UNIT_AU: float = 1.495978707e11            # m
const SOLAR_MASS_MSUN: float = 1.98847e30                     # kg

# Lennard-Jones Reference Presets (Argon)
const LJ_ARGON_SIGMA: float = 3.40e-10                        # m
const LJ_ARGON_EPSILON: float = 1.656e-21                     # J (120 K * k_B)
const LJ_ARGON_MASS: float = 6.6335e-26                       # kg (39.948 amu)

# Instance-configurable base parameters
var lj_sigma: float = LJ_ARGON_SIGMA
var lj_epsilon: float = LJ_ARGON_EPSILON
var lj_mass: float = LJ_ARGON_MASS

var astro_length: float = ASTRONOMICAL_UNIT_AU
var astro_mass: float = SOLAR_MASS_MSUN
var astro_g: float = GRAVITATIONAL_CONSTANT_G

var _scale_cache: Dictionary = {}

func _init() -> void:
	_invalidate_cache()

func configure_lennard_jones(p_sigma: float, p_epsilon: float, p_mass: float) -> bool:
	if p_sigma <= 0.0 or p_epsilon <= 0.0 or p_mass <= 0.0:
		push_error("UnitConverter: Lennard-Jones parameters must be strictly positive.")
		return false
	lj_sigma = p_sigma
	lj_epsilon = p_epsilon
	lj_mass = p_mass
	_invalidate_cache()
	return true

func configure_astronomical(p_length: float, p_mass: float, p_g: float = GRAVITATIONAL_CONSTANT_G) -> bool:
	if p_length <= 0.0 or p_mass <= 0.0 or p_g <= 0.0:
		push_error("UnitConverter: Astronomical parameters must be strictly positive.")
		return false
	astro_length = p_length
	astro_mass = p_mass
	astro_g = p_g
	_invalidate_cache()
	return true

func _invalidate_cache() -> void:
	_scale_cache.clear()

func get_scale_factor(system: UnitSystem, quantity: PhysicalQuantity) -> float:
	var key: int = (int(system) << 8) | int(quantity)
	if _scale_cache.has(key):
		return _scale_cache[key]
	
	var factor: float = _compute_scale_factor(system, quantity)
	_scale_cache[key] = factor
	return factor

func _compute_scale_factor(system: UnitSystem, quantity: PhysicalQuantity) -> float:
	match system:
		UnitSystem.SI:
			return 1.0
		
		UnitSystem.LENNARD_JONES:
			var s_l: float = lj_sigma
			var s_e: float = lj_epsilon
			var s_m: float = lj_mass
			var s_t: float = s_l * sqrt(s_m / s_e)
			match quantity:
				PhysicalQuantity.LENGTH:
					return s_l
				PhysicalQuantity.MASS:
					return s_m
				PhysicalQuantity.TIME:
					return s_t
				PhysicalQuantity.ENERGY:
					return s_e
				PhysicalQuantity.VELOCITY:
					return s_l / s_t
				PhysicalQuantity.ACCELERATION:
					return s_l / (s_t * s_t)
				PhysicalQuantity.FORCE:
					return s_e / s_l
				PhysicalQuantity.MOMENTUM:
					return s_m * (s_l / s_t)
				PhysicalQuantity.ANGULAR_MOMENTUM:
					return s_l * s_m * (s_l / s_t)
				PhysicalQuantity.TEMPERATURE:
					return s_e / BOLTZMANN_CONSTANT_KB
				PhysicalQuantity.PRESSURE:
					return s_e / (s_l * s_l * s_l)
				PhysicalQuantity.DENSITY:
					return s_m / (s_l * s_l * s_l)
				PhysicalQuantity.CHARGE:
					return sqrt(4.0 * PI * VACUUM_PERMITTIVITY_EPS0 * s_e * s_l)
				_:
					push_error("UnitConverter: Unsupported LJ quantity: %d" % quantity)
					return 1.0

		UnitSystem.PLANCK:
			var c: float = SPEED_OF_LIGHT
			var hbar: float = PLANCK_CONSTANT_HBAR
			var g: float = GRAVITATIONAL_CONSTANT_G
			var kb: float = BOLTZMANN_CONSTANT_KB
			var eps0: float = VACUUM_PERMITTIVITY_EPS0
			
			var l_p: float = sqrt(hbar * g / (c * c * c))
			var m_p: float = sqrt(hbar * c / g)
			var t_p: float = sqrt(hbar * g / (c * c * c * c * c))
			var e_p: float = m_p * c * c
			
			match quantity:
				PhysicalQuantity.LENGTH:
					return l_p
				PhysicalQuantity.MASS:
					return m_p
				PhysicalQuantity.TIME:
					return t_p
				PhysicalQuantity.ENERGY:
					return e_p
				PhysicalQuantity.VELOCITY:
					return c
				PhysicalQuantity.ACCELERATION:
					return c / t_p
				PhysicalQuantity.FORCE:
					return (c * c * c * c) / g
				PhysicalQuantity.MOMENTUM:
					return m_p * c
				PhysicalQuantity.ANGULAR_MOMENTUM:
					return hbar
				PhysicalQuantity.TEMPERATURE:
					return e_p / kb
				PhysicalQuantity.PRESSURE:
					return (c * c * c * c * c * c * c) / (hbar * g * g)
				PhysicalQuantity.DENSITY:
					return (c * c * c * c * c) / (hbar * g * g)
				PhysicalQuantity.CHARGE:
					return sqrt(4.0 * PI * eps0 * hbar * c)
				_:
					push_error("UnitConverter: Unsupported Planck quantity: %d" % quantity)
					return 1.0

		UnitSystem.ASTRONOMICAL:
			var s_l: float = astro_length
			var s_m: float = astro_mass
			var g: float = astro_g
			var s_t: float = sqrt((s_l * s_l * s_l) / (g * s_m))
			var s_v: float = s_l / s_t
			
			match quantity:
				PhysicalQuantity.LENGTH:
					return s_l
				PhysicalQuantity.MASS:
					return s_m
				PhysicalQuantity.TIME:
					return s_t
				PhysicalQuantity.ENERGY:
					return (g * s_m * s_m) / s_l
				PhysicalQuantity.VELOCITY:
					return s_v
				PhysicalQuantity.ACCELERATION:
					return (g * s_m) / (s_l * s_l)
				PhysicalQuantity.FORCE:
					return (g * s_m * s_m) / (s_l * s_l)
				PhysicalQuantity.MOMENTUM:
					return s_m * s_v
				PhysicalQuantity.ANGULAR_MOMENTUM:
					return s_m * s_l * s_v
				PhysicalQuantity.TEMPERATURE:
					return ((g * s_m * s_m) / s_l) / BOLTZMANN_CONSTANT_KB
				PhysicalQuantity.PRESSURE:
					return (g * s_m * s_m) / (s_l * s_l * s_l * s_l)
				PhysicalQuantity.DENSITY:
					return s_m / (s_l * s_l * s_l)
				PhysicalQuantity.CHARGE:
					return 1.0
				_:
					push_error("UnitConverter: Unsupported Astro quantity: %d" % quantity)
					return 1.0
		_:
			push_error("UnitConverter: Unknown unit system: %d" % system)
			return 1.0

func to_simulation(system: UnitSystem, quantity: PhysicalQuantity, si_value: float) -> float:
	var factor: float = get_scale_factor(system, quantity)
	if factor <= 0.0:
		push_error("UnitConverter: Non-positive scale factor for system %d, quantity %d" % [system, quantity])
		return si_value
	return si_value / factor

func to_si(system: UnitSystem, quantity: PhysicalQuantity, sim_value: float) -> float:
	var factor: float = get_scale_factor(system, quantity)
	if factor <= 0.0:
		push_error("UnitConverter: Non-positive scale factor for system %d, quantity %d" % [system, quantity])
		return sim_value
	return sim_value * factor

func to_simulation_vector(system: UnitSystem, quantity: PhysicalQuantity, si_vector: Vector3) -> Vector3:
	var factor: float = get_scale_factor(system, quantity)
	if factor <= 0.0:
		push_error("UnitConverter: Non-positive scale factor for vector conversion")
		return si_vector
	return si_vector / factor

func to_si_vector(system: UnitSystem, quantity: PhysicalQuantity, sim_vector: Vector3) -> Vector3:
	var factor: float = get_scale_factor(system, quantity)
	if factor <= 0.0:
		push_error("UnitConverter: Non-positive scale factor for vector conversion")
		return sim_vector
	return sim_vector * factor

static func default_to_simulation(system: UnitSystem, quantity: PhysicalQuantity, si_val: float) -> float:
	var conv := UnitConverter.new()
	return conv.to_simulation(system, quantity, si_val)

static func default_to_si(system: UnitSystem, quantity: PhysicalQuantity, sim_val: float) -> float:
	var conv := UnitConverter.new()
	return conv.to_si(system, quantity, sim_val)

static func default_to_simulation_vector(system: UnitSystem, quantity: PhysicalQuantity, si_vec: Vector3) -> Vector3:
	var conv := UnitConverter.new()
	return conv.to_simulation_vector(system, quantity, si_vec)

static func default_to_si_vector(system: UnitSystem, quantity: PhysicalQuantity, sim_vec: Vector3) -> Vector3:
	var conv := UnitConverter.new()
	return conv.to_si_vector(system, quantity, sim_vec)
