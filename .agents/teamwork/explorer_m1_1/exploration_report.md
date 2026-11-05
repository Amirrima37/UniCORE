# Technical Exploration & Architecture Blueprint: SimulationTimeController & UnitConverter
**Milestone**: M1 — Central Simulation Time Engine & Integrators  
**Author**: Explorer M1-1  
**Date**: 2026-10-28  
**Scope**:
- `res://core/physics/simulation_time_controller.gd`
- `res://core/physics/unit_converter.gd`

---

## 1. Executive Summary & Scope

In accordance with `ORIGINAL_REQUEST.md` (R1) and `scientific_simulation_architecture_spec.md`, Milestone 1 establishes the mathematical foundation of the UniCORE scientific physics engine. This exploration report specifies concrete architecture, mathematical models, exact GDScript 2.0 static typing, and production-ready implementation blueprints for two foundational components:

1. **`SimulationTimeController` (`res://core/physics/simulation_time_controller.gd`)**:
   - Central deterministic physics clock running inside Godot's `_physics_process`.
   - Variable time scaling ($0.001\times$ to $1000\times$).
   - Strict pause/unpause state machine.
   - Fixed-delta accumulator with anti-spiral substepping cap (`max_substeps = 10`).
   - On-demand `step_once()` single-tick deterministic stepping for manual frame analysis and scientific debugging.
   - Signal bus distribution (`sim_tick`, `time_scale_changed`, `simulation_paused`, `step_executed`).

2. **`UnitConverter` (`res://core/physics/unit_converter.gd`)**:
   - Universal bidirectional translator between SI physical units and dimensionless reduced natural simulation units.
   - Mitigates IEEE-754 32-bit single-precision float underflow/overflow across extreme scales (from Planck scale $10^{-35}\text{ m}$ to Astronomical scale $10^{11}\text{ m}$).
   - Implements 3 primary natural unit systems: **Lennard-Jones** (molecular dynamics), **Planck** (quantum/fundamental), and **Astronomical** (celestial $N$-body).
   - Provides full scalar and vector conversion across 13 physical dimensions (Length, Mass, Time, Velocity, Acceleration, Force, Energy, Momentum, Angular Momentum, Temperature, Pressure, Density, Charge).

---

## 2. Component 1: SimulationTimeController

### 2.1 Role & Architecture
`SimulationTimeController` extends `Node`. It serves as the single source of truth for physical time advancement. Physics modules (such as `MolecularDynamicsModule`, `NBodyGravityModule`, `NuclearDecayModule`, `QuantumWavePacketModule`) must **never** consume variable engine `delta` directly from `_process` or `_physics_process`. Instead, they subscribe to `sim_tick(dt: float, sim_time: float)` emitted by `SimulationTimeController`.

### 2.2 Class Contract & Static Typing

```gdscript
class_name SimulationTimeController
extends Node
```

#### Constants & Limits
- `const MIN_TIME_SCALE: float = 0.001`: Prevents zero or negative time progression, avoiding division by zero or backward causality.
- `const MAX_TIME_SCALE: float = 1000.0`: Upper limit preventing immediate accumulator explosion.
- `const DEFAULT_FIXED_DELTA: float = 0.01`: 100 Hz physical update rate (10 ms per tick).
- `const DEFAULT_MAX_SUBSTEPS: int = 10`: Limits maximum fixed steps executed within a single engine frame.

#### Exported Properties
- `@export var time_scale: float = 1.0`: Simulation speed multiplier clamped to $[0.001, 1000.0]$.
- `@export var fixed_delta: float = 0.01`: Discrete step duration in seconds distributed to integrators.
- `@export var is_paused: bool = false`: Pauses automatic time advancement while retaining state.
- `@export var max_substeps: int = 10`: Maximum ticks permitted per engine physics process frame.

#### State Variables
- `var sim_time: float = 0.0`: Monotonically increasing physical simulation time (seconds).
- `var _accumulator: float = 0.0`: Accumulated real-world delta scaled by `time_scale`.

#### Signals
- `signal sim_tick(dt: float, sim_time: float)`: Emitted for every discrete physical tick.
- `signal time_scale_changed(scale: float)`: Emitted when `time_scale` changes.
- `signal simulation_paused(is_paused: bool)`: Emitted when pause state changes.
- `signal step_executed(sim_time: float)`: Emitted specifically when `step_once()` completes.

### 2.3 Detailed Method Logic & Invariants

#### 1. `set_time_scale(scale: float) -> void`
- Clamps input: `var target_scale: float = clampf(scale, MIN_TIME_SCALE, MAX_TIME_SCALE)`.
- If `not is_equal_approx(time_scale, target_scale)`:
  - `time_scale = target_scale`
  - `time_scale_changed.emit(time_scale)`

#### 2. `set_paused(paused: bool) -> void`
- If `is_paused != paused`:
  - `is_paused = paused`
  - `simulation_paused.emit(is_paused)`

#### 3. `toggle_pause() -> void`
- Convenience toggle: `set_paused(not is_paused)`.

#### 4. `step_once() -> void`
- **Core Requirement**: Executes exactly one `fixed_delta` slice on demand, regardless of whether the simulation is paused or running.
- Invariant:
  1. Guard against non-positive delta: `if fixed_delta <= 0.0: return`
  2. Advance simulation time: `sim_time += fixed_delta`
  3. Emit physical tick: `sim_tick.emit(fixed_delta, sim_time)`
  4. Emit step notification: `step_executed.emit(sim_time)`
  5. Note: `_accumulator` is **not** modified by `step_once()`, ensuring unpausing resumes exact continuous accumulator phase.

#### 5. `reset() -> void`
- Resets accumulated simulation state:
  - `sim_time = 0.0`
  - `_accumulator = 0.0`

#### 6. `_physics_process(delta: float) -> void` (Accumulator & Death-Spiral Protection)
- **Phase 1: Pre-condition checks**:
  - `if is_paused or delta <= 0.0 or fixed_delta <= 0.0: return`
- **Phase 2: Accumulate scaled delta**:
  - `_accumulator += delta * time_scale`
- **Phase 3: Substepping execution**:
  ```gdscript
  var steps: int = 0
  while _accumulator >= fixed_delta and steps < max_substeps:
      _accumulator -= fixed_delta
      sim_time += fixed_delta
      sim_tick.emit(fixed_delta, sim_time)
      steps += 1
  ```
- **Phase 4: Death-spiral prevention (lag collapse defense)**:
  - If the engine experiences extreme frame hitching (e.g. background garbage collection or OS hitch), `_accumulator` could contain dozens of pending ticks.
  - If `_accumulator > fixed_delta * float(max_substeps)`:
    - Discard remaining backlog: `_accumulator = 0.0`.
    - This guarantees frame rendering does not freeze trying to catch up with an unrecoverable deficit.

---

## 3. Component 2: UnitConverter

### 3.1 Motivation & Floating-Point Numerical Precision
In computational physics within Godot 4.0:
- Standard 3D vectors (`Vector3`) and GPU buffers utilize 32-bit single-precision IEEE-754 floats.
- 32-bit floats have an effective precision of 24 bits ($\sim 7$ decimal digits) and dynamic exponent range from $\approx 1.18 \times 10^{-38}$ to $\approx 3.40 \times 10^{38}$.
- **Microscopic Domain**: Argon atomic diameter $\sigma \approx 3.4 \times 10^{-10}\text{ m}$. In SI units, the Lennard-Jones $r^{-12}$ term requires computing $(3.4 \times 10^{-10})^{12} \approx 2.38 \times 10^{-114}$, which severely underflows to zero, corrupting atomic dynamics!
- **Macroscopic Domain**: Planetary and galactic masses reach $10^{30}\text{ kg}$ to $10^{42}\text{ kg}$, with squared gravitational potentials overflowing to `+INF`.

`UnitConverter` solves this by normalizing physical quantities into reduced simulation units where primary parameters are $O(1.0)$ (e.g. length $\sim 1.0$, mass $\sim 1.0$, energy $\sim 1.0$).

### 3.2 Unit Systems Architecture

```gdscript
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
```

### 3.3 Conversion Mathematics by System

Let the SI scale factor for quantity $Q$ in system $S$ be denoted $F(S, Q)$.
By definition:
$$\text{SI Value} = \text{Simulation Value} \times F(S, Q)$$
$$\text{Simulation Value} = \frac{\text{SI Value}}{F(S, Q)}$$

#### System 1: Lennard-Jones (LJ) Reduced Units
In Lennard-Jones molecular dynamics, three independent fundamental reduction scales are chosen:
- Length scale: $S_L = \sigma$ (Argon: $3.40 \times 10^{-10}\text{ m}$)
- Energy scale: $S_E = \epsilon$ (Argon: $1.656 \times 10^{-21}\text{ J}$, corresponding to $\epsilon / k_B = 120.0\text{ K}$)
- Mass scale: $S_M = m$ (Argon: $6.6335 \times 10^{-26}\text{ kg} \approx 39.948\text{ amu}$)

From these base scales, all other physical dimensions are strictly derived via dimensional analysis:
- **Time**:
  $$S_T = \sigma \sqrt{\frac{m}{\epsilon}} \approx 2.152 \times 10^{-12}\text{ s} \quad (2.152\text{ ps})$$
- **Velocity**:
  $$S_v = \frac{S_L}{S_T} = \sqrt{\frac{\epsilon}{m}} \approx 157.98\text{ m/s}$$
- **Acceleration**:
  $$S_a = \frac{S_L}{S_T^2} = \frac{\epsilon}{m \sigma} \approx 7.34 \times 10^{13}\text{ m/s}^2$$
- **Force**:
  $$S_F = \frac{S_E}{S_L} = \frac{\epsilon}{\sigma} \approx 4.87 \times 10^{-12}\text{ N}$$
- **Pressure**:
  $$S_P = \frac{S_E}{S_L^3} = \frac{\epsilon}{\sigma^3} \approx 4.21 \times 10^7\text{ Pa} \quad (\approx 415.5\text{ atm})$$
- **Temperature**:
  $$S_\Theta = \frac{\epsilon}{k_B} \approx 119.94\text{ K} \quad (k_B = 1.380649 \times 10^{-23}\text{ J/K})$$
- **Linear Momentum**:
  $$S_p = S_M \cdot S_v = \sqrt{m \epsilon} \approx 1.048 \times 10^{-23}\text{ kg}\cdot\text{m/s}$$
- **Angular Momentum / Action**:
  $$S_{L_{ang}} = S_L \cdot S_p = \sigma \sqrt{m \epsilon} \approx 3.56 \times 10^{-33}\text{ J}\cdot\text{s}$$
- **Mass Density**:
  $$S_\rho = \frac{S_M}{S_L^3} = \frac{m}{\sigma^3} \approx 1687.7\text{ kg/m}^3$$

#### System 2: Planck Natural Units
In Planck units, universal constants are set to unity: $c = 1$, $\hbar = 1$, $G = 1$, $k_B = 1$.
Base constants in SI:
- $c = 299792458.0\text{ m/s}$
- $\hbar = 1.054571817 \times 10^{-34}\text{ J}\cdot\text{s}$
- $G = 6.67430 \times 10^{-11}\text{ m}^3/(\text{kg}\cdot\text{s}^2)$
- $k_B = 1.380649 \times 10^{-23}\text{ J/K}$
- $\varepsilon_0 = 8.8541878128 \times 10^{-12}\text{ F/m}$

Derived scale factors:
- **Length (Planck Length)**:
  $$l_P = \sqrt{\frac{\hbar G}{c^3}} \approx 1.616255 \times 10^{-35}\text{ m}$$
- **Mass (Planck Mass)**:
  $$m_P = \sqrt{\frac{\hbar c}{G}} \approx 2.176434 \times 10^{-8}\text{ kg}$$
- **Time (Planck Time)**:
  $$t_P = \sqrt{\frac{\hbar G}{c^5}} \approx 5.391247 \times 10^{-44}\text{ s}$$
- **Velocity**:
  $$v_P = c = 299792458.0\text{ m/s}$$
- **Acceleration**:
  $$a_P = \frac{c}{t_P} = \sqrt{\frac{c^7}{\hbar G}} \approx 5.5607 \times 10^{51}\text{ m/s}^2$$
- **Force**:
  $$F_P = \frac{c^4}{G} \approx 1.210295 \times 10^{44}\text{ N}$$
- **Energy**:
  $$E_P = m_P c^2 = \sqrt{\frac{\hbar c^5}{G}} \approx 1.9561 \times 10^9\text{ J}$$
- **Temperature**:
  $$T_P = \frac{E_P}{k_B} \approx 1.416784 \times 10^{32}\text{ K}$$
- **Linear Momentum**:
  $$p_P = m_P c \approx 6.52485\text{ kg}\cdot\text{m/s}$$
- **Angular Momentum**:
  $$L_P = \hbar \approx 1.054571817 \times 10^{-34}\text{ J}\cdot\text{s}$$
- **Charge (Planck Charge)**:
  $$q_P = \sqrt{4\pi \varepsilon_0 \hbar c} \approx 1.875546 \times 10^{-18}\text{ C}$$
- **Density**:
  $$\rho_P = \frac{m_P}{l_P^3} = \frac{c^5}{\hbar G^2} \approx 5.155 \times 10^{96}\text{ kg/m}^3$$
- **Pressure**:
  $$P_P = \frac{F_P}{l_P^2} = \frac{c^7}{\hbar G^2} \approx 4.633 \times 10^{113}\text{ Pa}$$

#### System 3: Astronomical (Astro) Units
In astronomical $N$-body systems, scaling is established such that the gravitational constant in simulation is dimensionless unity: $G^* = 1.0$.
Base configuration:
- Base Length: $L_0 = 1\text{ AU} = 1.495978707 \times 10^{11}\text{ m}$
- Base Mass: $M_0 = 1 M_\odot = 1.98847 \times 10^{30}\text{ kg}$
- Newton's Constant: $G_{SI} = 6.67430 \times 10^{-11}\text{ m}^3/(\text{kg}\cdot\text{s}^2)$

Derived scale factors:
- **Time Scale**:
  $$\tau_{Astro} = \sqrt{\frac{L_0^3}{G_{SI} M_0}} \approx 5.0226 \times 10^6\text{ s} \approx 58.132\text{ days} \approx \frac{1\text{ Julian Year}}{2\pi}$$
- **Velocity Scale**:
  $$v_{Astro} = \frac{L_0}{\tau_{Astro}} = \sqrt{\frac{G_{SI} M_0}{L_0}} \approx 29784.69\text{ m/s} \quad (29.785\text{ km/s} \text{ — exact Earth orbital speed!})$$
- **Acceleration Scale**:
  $$a_{Astro} = \frac{G_{SI} M_0}{L_0^2} \approx 5.93 \times 10^{-3}\text{ m/s}^2$$
- **Force Scale**:
  $$F_{Astro} = \frac{G_{SI} M_0^2}{L_0^2} \approx 1.179 \times 10^{28}\text{ N}$$
- **Energy Scale**:
  $$E_{Astro} = \frac{G_{SI} M_0^2}{L_0} \approx 1.764 \times 10^{41}\text{ J}$$
- **Linear Momentum**:
  $$p_{Astro} = M_0 v_{Astro} \approx 5.9226 \times 10^{34}\text{ kg}\cdot\text{m/s}$$
- **Angular Momentum**:
  $$L_{ang, Astro} = M_0 L_0 v_{Astro} \approx 8.86 \times 10^{45}\text{ kg}\cdot\text{m}^2/\text{s}$$
- **Mass Density**:
  $$\rho_{Astro} = \frac{M_0}{L_0^3} \approx 5.94 \times 10^{-4}\text{ kg/m}^3$$

---

## 4. Concrete Code Blueprints for Worker

Below are the exact, complete, production-ready GDScript 2.0 implementations for the Worker agent to place in `res://core/physics/`.

### 4.1 Blueprint: `res://core/physics/simulation_time_controller.gd`

```gdscript
class_name SimulationTimeController
extends Node

## Central physical time clock manager for UniCORE.
## Manages deterministic fixed-delta ticks, time scaling, pause/resume, and step-once execution.

signal sim_tick(dt: float, sim_time: float)
signal time_scale_changed(scale: float)
signal simulation_paused(is_paused: bool)
signal step_executed(sim_time: float)

const MIN_TIME_SCALE: float = 0.001
const MAX_TIME_SCALE: float = 1000.0

@export var time_scale: float = 1.0:
	set(value):
		set_time_scale(value)
@export var fixed_delta: float = 0.01:
	set(value):
		set_fixed_delta(value)
@export var is_paused: bool = false:
	set(value):
		set_paused(value)
@export var max_substeps: int = 10

var sim_time: float = 0.0
var _accumulator: float = 0.0

func _physics_process(delta: float) -> void:
	if is_paused or delta <= 0.0 or fixed_delta <= 0.0:
		return
	
	_accumulator += delta * time_scale
	
	var steps: int = 0
	while _accumulator >= fixed_delta and steps < max_substeps:
		_accumulator -= fixed_delta
		sim_time += fixed_delta
		sim_tick.emit(fixed_delta, sim_time)
		steps += 1
	
	# Death-spiral protection: if frame lag exceeds maximum substepping capacity,
	# drop remaining backlog to prevent cascading engine stall.
	var max_backlog: float = fixed_delta * float(max_substeps)
	if _accumulator > max_backlog:
		_accumulator = 0.0

func set_time_scale(scale: float) -> void:
	var target_scale: float = clampf(scale, MIN_TIME_SCALE, MAX_TIME_SCALE)
	if not is_equal_approx(time_scale, target_scale):
		time_scale = target_scale
		time_scale_changed.emit(time_scale)

func get_time_scale() -> float:
	return time_scale

func set_paused(paused: bool) -> void:
	if is_paused != paused:
		is_paused = paused
		simulation_paused.emit(is_paused)

func toggle_pause() -> void:
	set_paused(not is_paused)

func is_simulation_paused() -> bool:
	return is_paused

func set_fixed_delta(p_fixed_delta: float) -> void:
	if p_fixed_delta <= 0.0:
		push_error("SimulationTimeController: fixed_delta must be strictly positive.")
		return
	fixed_delta = p_fixed_delta

func get_fixed_delta() -> float:
	return fixed_delta

func get_sim_time() -> float:
	return sim_time

func step_once() -> void:
	if fixed_delta <= 0.0:
		push_error("SimulationTimeController: cannot step_once with fixed_delta <= 0.")
		return
	sim_time += fixed_delta
	sim_tick.emit(fixed_delta, sim_time)
	step_executed.emit(sim_time)

func reset() -> void:
	sim_time = 0.0
	_accumulator = 0.0
```

---

### 4.2 Blueprint: `res://core/physics/unit_converter.gd`

```gdscript
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

# Static convenience methods with standard reference presets
static func default_to_simulation(system: UnitSystem, quantity: PhysicalQuantity, si_val: float) -> float:
	var conv := UnitConverter.new()
	return conv.to_simulation(system, quantity, si_val)

static func default_to_si(system: UnitSystem, quantity: PhysicalQuantity, sim_val: float) -> float:
	var conv := UnitConverter.new()
	return conv.to_si(system, quantity, sim_val)
```

---

## 5. Verification & Testing Strategy

### 5.1 Verification Test Cases for `SimulationTimeController`
1. **Deterministic Single Step (`step_once`)**:
   - Create controller instance: `var tc = SimulationTimeController.new()`.
   - Initial state: `tc.sim_time == 0.0`.
   - Signal tracking: connect `sim_tick` and `step_executed` to counting Callables.
   - Execute `tc.step_once()`.
   - Verify `tc.sim_time == 0.01` (strictly equals `fixed_delta`).
   - Verify `sim_tick` emitted 1 time with arguments `(0.01, 0.01)`.
   - Verify `step_executed` emitted 1 time with argument `0.01`.
2. **Pause Freezing**:
   - Call `tc.set_paused(true)`.
   - Call `tc._physics_process(0.01)`.
   - Verify 0 ticks emitted and `sim_time` remains unchanged.
3. **Time Scale Bounds**:
   - Call `tc.set_time_scale(-10.0)` $\to$ `tc.time_scale == 0.001`.
   - Call `tc.set_time_scale(5000.0)` $\to$ `tc.time_scale == 1000.0`.
4. **Substepping Cap & Accumulator Drop**:
   - Set `tc.max_substeps = 5`.
   - Call `tc._physics_process(1.0)` (which contains 100 steps of `0.01`).
   - Verify exactly 5 `sim_tick` calls are emitted in this frame.
   - Verify that `_accumulator` is clamped to 0.0, avoiding lag accumulation.

### 5.2 Verification Test Cases for `UnitConverter`
1. **Lennard-Jones Argon System**:
   - Convert SI length $3.4 \times 10^{-10}\text{ m}$ to simulation $\to$ result must be $1.0$.
   - Convert simulation temperature $1.0$ to SI $\to$ result must equal $\approx 119.94\text{ K}$.
   - Round trip: `to_si(to_simulation(x)) == x` within $10^{-6}$ relative error.
2. **Astronomical Gaussian System**:
   - Convert $1\text{ AU}$ ($1.495978707 \times 10^{11}\text{ m}$) $\to 1.0$.
   - Convert orbital velocity of Earth $29784.69\text{ m/s} \to 1.0$.
   - Convert $1 M_\odot \to 1.0$.
3. **Planck Units System**:
   - Convert speed of light $299792458.0\text{ m/s} \to 1.0$.
   - Convert Planck length $l_P \approx 1.616255 \times 10^{-35}\text{ m} \to 1.0$.
4. **Vector Scaling**:
   - `to_simulation_vector(ASTRONOMICAL, LENGTH, Vector3(AU, 0, 0)) == Vector3(1, 0, 0)`.

---

## 6. Recommendations for Worker & Integrator Agents

1. **Strict Type Annotations**: Ensure all parameter types and return types in `simulation_time_controller.gd` and `unit_converter.gd` are statically typed without untyped `Variant`.
2. **Pre-allocated Substepping**: In `SimulationTimeController._physics_process`, avoid allocations inside the while loop.
3. **Zero Assert in Tests**: Ensure test suites in `tests/test_physics_engine_suite.gd` use custom test assertions (`passed_count`, `failed_count`, `quit(code)`), adhering to `GEMINI.md`.
4. **Validation Check**: Run `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only` following creation of the classes to guarantee zero compiler diagnostics.
