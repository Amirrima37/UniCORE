# CAE recovery implementation and acceptance results

Current numerical/material capabilities are documented in [Engineering kernel cycle](engineering-kernel-cycle.md). The recovery report below is a historical milestone snapshot.

This work extends the existing Godot shell, document and native bindings. The original sandbox and dynamic module path remain present. The full engineering-domain roadmap remains the long-term scope; this recovery does not claim implementations for its missing solvers.

## Milestone 1: navigation, input and lifecycle

Modified: `core/workspace_mode_controller.gd`, `core/space_viewport.gd`, `ui/hud/top_bar.gd`, `ui/cae/cae_workspace.gd`.

- One mode controller owns AI Sandbox / CAE Workbench state, visibility and processing snapshots.
- The persistent selector sits beside the logo. Back to AI Sandbox requests the same state transition. Escape dismisses a CAE dialog/popup first, otherwise returns to AI.
- Entering CAE suspends the world modules, simulation clock, physics interaction and input mapper, and hides sandbox panels. Returning restores their previous processing/visibility, mouse mode and live UI focus. An already-open sandbox modal retains its input block.
- Hidden CAE controls ignore input and the separate viewport stops rendering. The document is retained in memory across transitions. No geometry or history is discarded on mode switch.
- Global menu/settings/log actions leave CAE through the mode controller before opening their original sandbox interface. The global prompt button focuses the engineering command field in CAE.
- Fixed the existing local-model download-progress callback's two/four argument mismatch, which previously emitted an error each progress update.

Verified: `test_cae_shell.gd` instantiates the real shell with test-only network/provider setup, enters CAE, returns, opens the original prompt, dispatches a sandbox prompt to the existing GDScript system, and re-enters the retained session. Isolated recovery checks exercise modal Escape, focus restoration and 30 mode round trips. No live cloud request was required.

## Milestone 2: compact dark workspace and rendering

Modified: `ui/cae/cae_workspace.gd`, `ui/cae/cad_viewport.gd`.

- Native compact menus and toolbar; nested horizontal splits separate tree, viewport and scrollable inspector. Bottom rows contain simulation setup, the existing-agent command field and status/units.
- The viewport has its own explicit World3D and charcoal WorldEnvironment. Grid, world axes, neutral solid material, selection color and directional/ambient lighting are real rendered objects.
- Bounded camera clipping and resize invalidation keep small models visible in the bundled compatibility renderer. Rendered captures were inspected, including the actual cylinder/grid rather than only Control construction.
- Geometry is cached by body ID and parameter signature. Transform/selection/visibility edits preserve mesh instances; only changed primitive parameters rebuild a shape. Deleting a body releases its cache entries. Result overlays have their own root/cache key.
- No per-frame tree or inspector reconstruction. The inspector keeps its numeric controls while editing. An idle workspace has its process callback disabled; only an active solve enables worker polling. Camera motion and model changes invalidate one viewport frame; a hidden viewport is disabled.
- Editing history shares immutable mesh/result snapshots instead of copying all numerical fields for a small parameter edit.

Verification: real-shell layout checks at 1280 and 960 pixel window widths account for the application's existing canvas stretch coordinates. OpenGL compatibility capture on the local AMD renderer produced `.tools/cae-recovery.png` and `.tools/cae-viewport.png` with no graphical runtime errors. Split panes remain independently resizable. Graphical validation used the same shell fixture to avoid network/download side effects.

Performance investigation used Godot `--profiling`, built-in Performance monitors and timed instrumented operations; this is a local microbenchmark, not a general FPS or GPU performance guarantee. Logs are `.tools/cae-baseline.log`, `.tools/cae-final-profile.log`, and `.tools/cae-recovery-performance.json`.

| Sampled operation | Before | After |
|---|---:|---:|
| 30 selections among 12 bodies | 9.083 ms | 2.676 ms |
| Body instances replaced by those selections | 12 | 0 |
| Sampled scene node count in that harness | 480 | 165 |
| Create 12 bodies | 10.981 ms | 3.838 ms |

Empty-workspace mode test: 100 round trips, p95 0.272 ms, maximum 0.459 ms; scene node count 155 before and after. Sampled static memory changed from 24,567,844 to 24,572,004 bytes while the harness allocated its timing sample array. This is a bounded test, not proof against every future resource leak. Hidden rendering and idle workspace processing were both disabled. Headless Godot 4.0 still emits known dummy-renderer `mesh_get_surface_count` teardown diagnostics; the graphical run does not emit them. No interactive editor-profiler session is claimed.

## Milestone 3: parametric editing and persistence

Modified: `core/cae/cae_document.gd`, workspace and viewport components.

- Box, cylinder, sphere and actual hollow pipe meshes.
- Numeric mm UI backed by SI metres, with type-specific length/width/height, diameter/radius, inner diameter and wall thickness validation.
- Diameter/radius synchronize through the same command. Each committed numeric change updates the real primitive, not a decorative field.
- Position in mm, rotation in degrees and nonzero positive scale affect the instance transform. Stored rotations use radians.
- Rename, duplicate, delete, hide/show, selection highlighting, Undo/Redo and full-precision JSON persistence. Old documents gain default rotation/scale/visibility fields without a schema reset.
- Picking transforms the ray into the body's local coordinates and tests cached triangles after a bounding-box check. It respects rotation, scale, visibility and the empty bore of a pipe. Tree selection and viewport selection use the same state.

Verified: `test_cae_recovery.gd` changes the actual cylinder diameter inspector from 100 to 150 mm and checks mesh radius 0.075 m, Undo and Redo; radius synchronization; transforms; hide/show; rename/tree synchronization; save/load; invalid pipe wall rejection; and triangle picking through a pipe bore. Modeling meshes remain separate from analysis geometry/mesh validation.

## Milestone 4: camera and orientation

Modified: `ui/cae/orientation_widget.gd`, `ui/cae/cad_viewport.gd`, workspace toolbar.

- Y-up convention: Front looks toward -Z; Back toward +Z; Right toward -X; Left toward +X; Top toward -Y; Bottom toward +Y.
- Red X, green Y, blue Z widget projects world axes through the actual camera basis. Clicking a positive axis selects Right/Top/Front.
- Standard views and Isometric use parallel projection; Perspective uses perspective. View transitions use short tweens; manual navigation cancels a transition cleanly.
- Fit all, Fit selection, Reset view, projection toggle, right-drag orbit, middle-drag or Shift+right-drag pan, wheel zoom. The camera moves around its target; it does not rotate the model.
- Ctrl+Z/Y, Ctrl+Shift+Z, Ctrl+S, Delete and F are supported when a text editor does not own focus.

Verified: Top/Front/Isometric projection type and actual camera direction, model transform invariance and manual orbit after standard views. The graphical capture verifies widget/model/grid visibility. Remaining limitation: the orientation control is an axis triad rather than a six-face cube.

## Milestone 5: existing-agent CAD commands

Modified: `agent/agent_brain.gd`, shell wiring and workspace command executor.

The existing AgentBrain/provider stack can produce validated JSON CAD commands in CAE mode. The engineering field and original prompt dispatch both use this integration. Sandbox prompts retain the original GDScript/module path. No second agent was introduced.

Commands use the same document operations as the manual inspector. Batches are validated against a staging document, applied atomically and undoable in one step. Invalid commands, stale model/selection responses and concurrent provider use are rejected. Missing inputs can be returned as a question; explicit material assumptions are displayed. Generated scripts are not accepted as core CAD commands.

Verified: `test_cae_ai_commands.gd` uses a mock provider transport with the actual AgentBrain and actual executor to create a 100 mm diameter, 500 mm long cylinder, modify its selected diameter to 200 mm, Undo, reject a partially invalid batch, reject a stale response, display a missing-input question and preserve the sandbox system prompt. Live model/provider command-generation accuracy has not been evaluated; a configured existing provider is required for live requests.

## Milestone 6: bounded native expansion and regression

Modified: `native/src/kernels/geometry_metrics.hpp`, `native/src/bindings/geometry_tools.*`, registration/capability files, and structural input validation.

Existing numerical capabilities remain gravity, molecular, quantum, nuclear, particle metrics and the initial static TET4 structural solver. The next small shared capability is `UniCoreGeometryTools.measure_primitive(part)`: analytical volume, area, mass and centroidal local-axis inertia for all four primitive types. The inspector's Measure volume / mass action calls this GDExtension API. Box scaling and uniform radial scaling are supported; unsupported nonuniform curved geometry returns an error. Units are explicit in returned field names. This work adds no major multiphysics solver.

Standalone analytical tests cover box/cylinder/sphere/pipe metrics and invalid inputs. Bridge tests cover integer conversion, hollow volume, scaling and native error behavior. Rotated/scaled solids are explicitly rejected by the current structural mesher instead of solving an untransformed shape silently.

Both debug and release native DLLs were rebuilt using `native/build_direct.ps1` against the existing pinned Godot C++ archives. Debug-loaded suites pass: structural, geometry, worker UI, particle metrics (122 checks), gravity (1,722), molecular (512), quantum (8,881) and nuclear (16,589). Some older negative-input regression cases intentionally emit errors while reporting zero failures. The existing structural bending accuracy limitation remains unchanged: the 8-division TET4 cantilever is about 32% below the simple beam reference. No new accuracy claim is made.

## Remaining limits

- Structural analysis still supports only unrotated, unscaled boxes with fixed faces and total face forces; cylinders, spheres and pipes are editable geometry, not structurally solved solids.
- No BREP CAD kernel, Boolean operations, extrusion, fillets, assemblies, general curved-volume mesher, pressure or prescribed displacement was added.
- All earlier specialized-domain roadmap items remain future numerical work; none are represented as working placeholder controls.
- History is retained for the in-memory session; project files persist model/mesh/results rather than the Undo stack. Camera/session settings survive mode switches, but camera settings are not serialized to project files.
- Tests use controlled provider/network fixtures. Manual interactive use with the user's live AI service and long-duration GPU/memory profiling remain outside these automated checks.

To reproduce: run the named Godot test scripts with the bundled Godot 4.0 console executable. The graphical test is `tests/test_cae_shell.gd -- --capture` with the compatibility renderer; run it with a graphical display. `tests/profile_cae_workspace.gd` and `tests/profile_cae_recovery.gd` generate the instrumented performance samples. Native analytical sources are `native/tests/geometry_metrics_test.cpp` and `native/tests/structural_solver_test.cpp`.
