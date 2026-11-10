# Agent physics integration

Completion means a generated model uses the numerical engine, remains editable in
the existing interface, and recalculates when edited. Prompt compliance alone does
not prove this.

## Implemented foundation

- AgentBrain appends a versioned gravity API contract to its common enriched prompt.
  Generation, editing, repair and provider fallback use this context.
- The contract directs generated code to register/reuse the gravity module through
  ModuleManager so the existing object editor discovers its numerical bodies.
- Position, velocity and mass edits evaluate current forces without stepping time,
  refresh spatial state, and establish a new conservation baseline. Native force
  evaluation uploads the edited arrays through the existing set_state binding.
- A regression script covers force response to mass/position edits, subsequent
  velocity integration, and invalid edits.

## Remaining implementation, in order

1. Add a supported scenario configuration API with explicit initial conditions and
   ownership. Capture names and all body properties at initialization; reset must
   restore removed bodies, discard subsequent additions and restore the snapshot.
   Keep scenario reset distinct from resetting a shared simulation clock.
2. Stage module replacement in ModuleManager. Check initialize()'s return value;
   roll back failed initialization and release the candidate's subscriptions and
   resources. Retain the old module until replacement succeeds. Shared solver
   mutation needs snapshot/rollback too; keeping the old Node alone is insufficient.
3. Enforce physics integration at runtime. Validate registered solver ownership,
   editable body discovery and shared time participation. Reject duplicate ticking
   and unsupported controls with actionable repair errors. Apply the same gate to
   local cache, registry and shared modules, not just fresh LLM responses.
4. Provide an executable reference scenario and interface regression covering ray
   selection, inspector position/mass/velocity edits while paused, simulation speed,
   pause, single-step, reset and cleanup. Check acceleration against softened
   Newtonian expectations with explicit tolerances; test velocity-dependent modes
   separately. Confirm manual edits do not appear as integration drift.
5. Run native parity tests and explicitly verify get_last_step_backend() after a
   step. Required-native requests must fail clearly when bindings or parameters
   cannot execute natively; optional fallback must report its actual backend.
6. Add separate verified API references and integration adapters for molecular,
   quantum and nuclear modules. Document units, editable state and limitations per
   domain. Do not expose gravity controls for models that do not support them.
7. Exercise a real provider request through generation, validation, loading,
   selection, edits and reset. Include a repair and provider-fallback case. This
   completes acceptance only after the observable numerical behavior passes.

## Validation

Run the added regression with a working Godot binary:

    godot --headless --path . --script tests/test_agent_physics_contract.gd

Then run tests/test_native_gravity_suite.gd with --require-native when the native
extension is available. The bundled Godot invocation in this session exited with
code 1 and no diagnostic output, so the new regression is not runtime verified.
