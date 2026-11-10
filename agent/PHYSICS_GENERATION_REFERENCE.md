# UniCORE physics generation reference

Status: implementation specification and proposed runtime prompt. This file alone does not change AgentBrain or get sent to DeepSeek. The implementation must explicitly load the runtime rules and append verified API context.

## Repository facts and source of truth

- `agent/agent_brain.gd`: SYSTEM_PROMPT, `_get_enriched_system_prompt()`, generation, edits, retries, local fallback and cache/registry resolution.
- `agent/providers/openai_compatible_provider.gd`: inspect the existing DeepSeek-compatible request path; retain configured credentials and endpoint.
- `agent/code_validator.gd`: compilation, interface and security checks. Passing these checks does not establish physical correctness.
- `core/base_module.gd`: UniCoreModule extends Node, not Node3D. Implement get_module_id, get_module_name, initialize(context) and cleanup; use owned Node3D children for spatial transforms.
- `core/module_manager.gd`: authoritative context, loading, registration and lifecycle. Check actual context keys before using them.
- `core/physics/compute_backend.gd`: capability-aware factories create_gravity_solver, create_molecular_solver, create_quantum_solver, create_nuclear_solver and create_particle_metrics. Factories can return null. Native types are discovered dynamically, not referenced in parse-time type annotations.
- `modules/physics/n_body_gravity_module.gd`, `molecular_dynamics_module.gd`, `quantum_wavepacket_module.gd`, `nuclear_decay_module.gd`: existing simulation implementations and native/script dispatch.
- `modules/physics/tools/`: examples for connecting interactive tools to existing simulations; start with celestial_spawner_tool.gd.
- `native/src/bindings/`: authoritative native signatures and argument/result schemas. Read the matching binding and its GDScript caller together.
- `docs/native/README.md`, `SOLVERS.md`, `MOLECULAR.md`, `VALIDATION.md` in that directory: build, compatibility, limitations and verification. Check installed tools rather than assuming documented paths still work.

## Runtime system prompt rules

You generate executable UniCORE Godot GDScript modules. For a physics request, implement a numerical simulation connected to the project's existing calculation backend. Meshes, trails and labels visualize calculated state; they are not the simulation.

1. Return only raw GDScript, with Name, Description and Tags comment metadata and the existing module contract. No Markdown fences, placeholders or invented APIs.
2. Use only APIs and schemas supplied in the verified capability context. Prefer configuring/composing an existing physics module or using its public tools. Do not duplicate integration when an existing module already owns stepping. Do not mutate private packed buffers from generated tools.
3. State initial conditions, units or dimensionless conventions, forces/model, timestep and numerical limitations in comments and relevant UI. Keep physical coordinates separate from render scale.
4. The active solver owns state evolution. Render transforms and measurements come from that state. Do not substitute tweens, prescribed sine/cosine orbits, random motion or frame-dependent translations for requested physics. Analytical solutions are allowed only when explicitly selected and labelled.
5. Respect the existing simulation clock, pause, time scale, stepping and reset. Reset restores initial conditions. Use existing input bindings and event schemas, with cleanup of owned objects and signal connections.
6. Request native computation through the supported backend path. Native availability alone does not prove native execution. Report the backend actually used and the reason for fallback. A request explicitly requiring C++ must fail clearly if no native step can execute; auto mode may use a labelled numerical GDScript fallback.
7. Do not promise native execution for unsupported callbacks/workloads. Existing selection gates and nuclear listener behavior may retain scripted stepping. Do not remove those safeguards just to display a native badge.
8. Validate finite values, positive masses where applicable, bounded sizes and stable timestep choices. Expose meaningful computed diagnostics with units. Do not fabricate conservation results or label unsupported models as physically implemented.
9. If the requested model is absent, use the application's explicit unsupported-capability path. Never invent a solver. Any new numerical model requires repository implementation and verification before generation may use it.
10. Preserve validator restrictions. Do not access credentials, run shell commands or make arbitrary network/filesystem operations from generated modules. Regex validation is not an execution sandbox.

These rules require appended domain-specific context: actual public method signatures, defaults, argument dictionaries, units, result schemas, lifecycle ownership, backend constraints and one small verified example. A hosted model cannot read repository paths merely because this document names them.

## Acceptance evidence

- A generated gravity scenario initializes nonempty numerical state, executes an actual native step in a suitable fixture, and renders the resulting positions.
- Changing mass or initial velocity changes calculated trajectories. Pause prevents state evolution, single-step advances once, and reset restores initial state.
- A deterministic two-body fixture has documented energy/angular-momentum tolerances over a specified interval and improves appropriately under timestep refinement. Do not demand exact conservation with every integrator or model.
- Native and script results agree within justified tolerances for equivalent supported fixtures. Native unavailable and fallback conditions are tested separately.
- A mesh-only response to a physics request is rejected or repaired; a legitimate decorative request remains allowed.
- Invalid generation cannot replace a working module; cleanup leaves no orphan simulation, nodes or signal connections.
- Cached/registry/shared modules must meet the same capability and contract requirements. Old visual-only results cannot bypass validation.
