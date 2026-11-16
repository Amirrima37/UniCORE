# Workbench 2.0 — stage 1: command discovery and shell

This is an independently validated first increment, not completion of the full Workbench 2.0 milestone. Existing uncommitted CAE/native changes were preserved. The four requested Extreme/HPC documents were inspected before implementation. No native kernel, material value, job format or numerical tolerance was changed in this increment.

## UI architecture

`core/cae/tool_registry.gd` centralizes 38 existing top-level menu handlers, stable category/title IDs, search, availability reasons, shortcut metadata, icon metadata and implemented/experimental/planned status. Planned entries cannot execute. Menu dispatch and search dispatch share the same handlers. Undo/redo invokes the existing document history; view changes do not enter document history. Ctrl+K opens search. Existing shortcuts remain in the workspace keyboard handler: dispatch is not yet generated from registry metadata. Icon metadata is an extension point, not a finished icon system.

The workspace remains the UI adapter. `cae_document.gd` owns SI document commands, revision history and mesh/result invalidation. Existing geometry/mesh services produce solver snapshots. Existing native structural/thermal bindings and independent Extreme processes compute results; scientific display services consume numerical fields. Future physics modules should provide document validation, mesh requirements, solver adapters and field descriptors through these boundaries, without adding solver code to toolbar handlers. A formal plugin service interface and workspace switching remain future work.

## Implemented workflows

The header presents identity, document revision and analysis type, retaining AI Sandbox navigation. The command row scrolls horizontally when necessary. Search discovers existing geometry, materials, simulation, mesh inspection, results and Extreme CPU entry points. Selection/result/mesh availability checks protect menu and search execution. The console collapses, retains AI input and records reported diagnostics. The existing contextual body inspector and numerical workflows remain in place.

The header currently says Untitled; filename and disk save status tracking are unfinished. This stage does not claim every nested inspector action is individually registered. Loads, field components, playback and job operations remain reachable through their existing dialogs/inspectors.

## Roadmap mapping

`core/cae/capability_roadmap.json` preserves all 50 entries supplied in the user message, including bundled product names, as seven expandable domain groups: structures/mechanics, fluids, electronics/electromagnetics, semiconductors, optics/photonics, systems/optimization, and materials/design/platform. The browser searches these groups separately from executable tools and disables execution. Reference product names describe requested domains, not supplied integrations or proprietary implementations.

Structural and thermal isotropic analysis, parametric primitives, box-volume HEX8/TET4 meshes, materials, numerical postprocessing and local CPU jobs reuse existing modules. General nonlinear/dynamic structures, CFD/DEM/reacting flow, electromagnetic/electronic and semiconductor solvers, optics, system models, safety, materials data platforms, CAD translators and remote HPC remain planned. Existing thermal support does not imply electronics CFD cooling; existing local processes do not imply cloud scheduling. Splitting bundled entries into finer capability IDs and relating validated subsets to their roadmap parents remains necessary.

## Screenshots

Actual Godot 4.0 Vulkan framebuffer captures on AMD Radeon RX 6550M:

- [1280 x 720](workbench-1280.png)
- [1920 x 1080](workbench-1920.png)
- [Capability browser](roadmap.png)

The 720p capture exposed a wrapping header that was corrected and recaptured. The viewport and inspector fit; long explorer labels still require horizontal scrolling. The browser uses tooltips for long roadmap descriptions. Screenshots were visually inspected. Automated handler tests do not constitute exhaustive physical mouse/keyboard testing.

## Numerical visualization and performance

Existing deformation, scalar legends, thermal fields, probes and asynchronous mesh preparation are preserved. No new numerical interpolation, convergence history or field was introduced. No frame time or large-model stall measurements were performed in this stage; no performance improvement is claimed. Registry search operates over small metadata records and does not rebuild the viewport. Console log retention still needs a bound for long sessions.

## Validation

The existing default native regression manifest completed **28/28** with no script errors; raw per-test logs, durations and results are under [regression](regression/results.json). This covers native physics, structural UI, CAE shell/recovery/AI commands, mesh inspection/integration/async preparation, radiation and Extreme numerical equivalence/advanced loads. It is not the extended all-suites run. These tests ran before the final browser-only corrections; targeted tests and graphical capture were repeated afterward.

`tests/test_workbench2.gd` passed command population, roadmap population (50), geometry creation and document undo/redo. Earlier attempts stalled at an incorrect command-count assertion; they were interrupted, not counted as passes. The final count is 38. The empty roadmap search also exposed a Godot empty-string membership behavior; an explicit empty-query check fixed it. Headless workspace tests emitted dummy-renderer `mesh_get_surface_count` warnings but no script errors. Graphical captures exited 0 without those warnings.

Historical app-shell **0xC0000005 remains unresolved**. The default 28-test manifest does not include that full application-shell suite. No native rebuild was necessary because native files were unchanged. Checkpoint/restart, standalone job monitoring, full transient playback and new performance measurements were not independently rerun beyond the manifest coverage.

## Modified files in this increment

- `core/cae/tool_registry.gd` (new)
- `core/cae/capability_roadmap.json` (new)
- `ui/cae/tool_browser.gd` (new)
- `ui/cae/cae_workspace.gd` (existing modified file extended carefully)
- `tests/test_workbench2.gd`, `tests/capture_workbench2.gd` (new)
- This report, screenshots and regression evidence.

## Remaining stages

Finish contextual model-tree categories/actions and preserved expansion state; accurate filename/save tracking; register nested tools and scientific field commands; generate keyboard dispatch and icons from registry; destructive-edit confirmations; unified capability descriptors; bound console retention. Then improve geometry/material validation presentation, mesh/BC controls, solver/Extreme configuration, scientific result inspection and visualization. Profile actual frame times and stalls before optimizing. Run the extended suite, explicit standalone lifecycle/restart tests and full graphical workflow tests at each relevant stage. The scientific and solver expansion scope restrictions remain in force.

# Stage 2 — professional engineering UI

Stage 2 extends the existing shell and command registry. No native kernel, tolerance, material record, job format or physics module was changed. Existing unrelated working-tree edits remain preserved.

## Toolbar and panels

The flat menu row is replaced visually by eight task tabs: Home, Geometry, Materials, Mesh, Loads & Constraints, Simulation, Results and Inspection. Each tab presents labeled command groups with cached category icons, short labels, tooltips, disabled reasons and a restrained blue active state. All ribbon buttons dispatch through the existing registry. The original menu adapters remain hidden to register backward-compatible command IDs; they are not a second visible toolbar. Two real load/setup commands bring search to 40 commands. Ctrl+K and the 50-entry roadmap remain operational. Unsupported result fields are disabled by checking actual result keys. Normal solve cancellation and history commands have availability checks.

The explorer and inspector retain Godot split-container handles and session widths through document refreshes and workspace visibility changes. Minimum widths protect numerical controls; the central viewport can still expand. Inspector scrolling, tree ellipsis and full-label tooltips accommodate long content. Session layout does not persist across application restarts.

## Explorer and contextual editing

The hierarchy includes actual geometry bodies, per-body material assignments, mesh node/cell statistics, analysis, loads/constraints, solver/boundary settings and results status. No unsupported connections or coordinate systems were inserted. Selecting categories presents relevant inspector summaries/actions; body selection synchronizes with viewport highlighting and the property inspector. Right-click actions support fit, duplicate, visibility and confirmed deletion. Delete key and the registered Delete command also request confirmation before changing the document.

Collapse state is keyed independently of labels. A structure signature avoids clearing/repopulating the tree during dimension, rotation and position edits. The existing inspector binding fast path retains controls during small edits; tests check both inspector and tree item identities. Topology/name/material/analysis changes may rebuild relevant UI. Category selection and viewport selection remain distinct: a subsequent edit/refresh returns the inspector to the selected body.

Properties are grouped into collapsible Identity, Dimensions, Position, Rotation, Scale, Material and Face Force sections. Section choices persist during the session. Numeric inputs align right, with units on section headings or property labels. Cylinder radius and diameter still share the SI document parameter and refresh together. Invalid document commands report feedback in the status line and console, preserving revision/history. SpinBox limits reject values outside their input bounds; model validation remains the authority for dependent parameters.

The explorer lists legacy fixed-face and face-force entries. Detailed pressure, displacement, gravity and thermal conditions remain editable through the existing analysis dialog; they are not yet all individual tree leaves. The material editor itself retains its existing record/JSON interface; this increment does not claim a complete material-browser redesign.

## Viewport

Existing triangle picking, selected-body color, standard direction selector, orientation widget, orbit/pan/zoom and orthographic/perspective controls remain functional. Fit all/body is prominent in the viewport toolbar. Primitive fit now computes a bounding-sphere distance using the camera field of view and viewport aspect ratio, removing the fixed 0.2 m minimum for small models. Orthographic fitting accounts for camera size and narrow views. Existing mesh/result fit retains its prior bounds-based implementation. No disconnected transform gizmos were introduced.

## Screenshots and reference comparison

The supplied [ANSYS reference](../ansys_screenshot/screenshot.png) was opened and inspected before implementation. These are actual final Godot 4.0 Vulkan captures, also opened and inspected after the changes:

- [Stage 2 at 1280 × 720](stage2-1280.png)
- [Stage 2 at 1920 × 1080](stage2-1920.png)
- [Preserved capability browser](stage2-roadmap.png)

The reference informed task tabs, command groups with captions, a structured outline and dense contextual editing. UniCORE keeps dark neutral surfaces, a right-side inspector and its own icon/color system. Compared with Stage 1, primitives and editing commands no longer require opening cascading menus, related properties occupy compact sections, and the selected body is identifiable in both views. Compared with the reference, the implemented command breadth and icon vocabulary are smaller; no unavailable operations were added to fill the ribbon. At 720p the model remains central, controls do not overlap, and the inspector scrolls. Long analysis/tree descriptions still ellipsize and require a tooltip or a wider panel. Godot's existing canvas stretch scales the interface at 1080p rather than increasing logical UI density.

Screenshot inspection exposed and corrected a vertically wrapped VIEW label, excessively dark pressed states and a programmatic active-tab mismatch. Early graphical attempts also exposed a Godot 4.0 nested-lambda parser bug and unavailable Image SVG-loading APIs. Named callbacks and cached code-drawn icons replaced those paths. Those error runs were not counted as passes. Final graphical capture and workflow runs contained no script errors.

## Workflow tests and regressions

`tests/test_workbench2_stage2.gd` verifies:

- Box/cylinder creation and actual viewport triangle picking at the projected cylinder position.
- Explorer/body selection synchronization.
- Editing the real diameter SpinBox, SI document update and linked radius update.
- Inspector/tree reuse for small edits, undo/redo and invalid-value rejection without revision changes.
- Existing material-library record assignment through its UI signal.
- Collapse-state preservation after rename and split width retention during edits.
- Supported box-volume mesh generation, simulation settings access, a small native solve, result inspection and unavailable-field guards.
- Nonempty functional command groups for all eight tabs.

The unsupported cylinder volume mesher is not implied: the cylinder is removed before meshing the supported box. Tests invoke real controls, signals and picking; they are not exhaustive physical mouse/keyboard automation or large-model benchmarks.

The final default manifest passed **28/28**, zero script errors. [Final regression evidence](stage2-final-regression/results.json) retains individual logs and durations. The earlier Stage 2 manifest also passed 28/28. Stage 1 compatibility and Stage 2 headless/graphical workflow checks passed; [targeted evidence](stage2-checks/results.json) records exit status and durations. Headless tests still emit dummy-renderer `mesh_get_surface_count` errors; those are recorded in the raw logs and are not script errors. The graphical workflow has zero such renderer errors.

Historical application-shell **0xC0000005 remains unresolved** and was not suppressed. The default manifest does not include that full application-shell suite. No claim of a universally crash-free application is made.

## Performance, files and remaining stages

Cached icons avoid regenerating textures on every explorer refresh. Small edits retain inspector controls and, when the visible hierarchy is unchanged, existing explorer items. The existing geometry cache and on-demand viewport redraw remain in use. No large-model frame-time campaign or new responsiveness speedup measurement was performed; test execution durations are not FPS measurements. No expensive HPC benchmark ran.

Stage 2 changes: `ui/cae/cae_workspace.gd`, the fitting calculation in `ui/cae/cad_viewport.gd`, new `tests/test_workbench2_stage2.gd`, extended `tests/capture_workbench2.gd`, this report, screenshots and validation evidence. Other listed Stage 1 and pre-existing files were not rewritten.

Remaining work includes individual tree entries for all persisted condition types, per-command rather than per-category icon artwork, registry-generated keyboard dispatch, filename/save-state tracking, persistent disk layout preferences, improved material record editing, full mesh/condition workflow polish, richer scientific result navigation and measured large-model UI profiling. Ribbon grouping currently uses an adapter mapping over registry titles; moving group/workspace metadata into capability descriptors is a future architecture cleanup. All 50 roadmap records remain planned references, not new solvers.

# Stage 3 — engineering workflows

Stage 3 extends the Stage 2 ribbon and document adapters. No numerical kernel, native tolerance default, HEX8/TET4 formulation, material database or numerical job grammar was changed. No large HPC campaign ran.

## Selection and mesh workflow

Body and local box-face selection are available in the viewport toolbar. Box-face picks update the face selector; a cyan outline identifies the selected target. This is a local parametric box face, not a new persistent CAD topology system. Condition selection synchronizes the target body and marker. Node/element picking uses the existing mesh inspection implementation, highlights actual selected entities and reports coordinates, quality and available result values. Region ownership synchronizes the selected body with the explorer where the mesh supplies material-region IDs.

The Mesh ribbon opens a dedicated inspector with density (1–16 divisions per axis), supported element choice, generation, node/base-cell statistics, wireframe/combined/node/element display, quality, invalid elements and detailed inspection/section controls. Only boxes can be volume meshed. Thermal uses TET4; structural supports TET4 and HEX8. Cylinders, spheres and pipes remain display primitives and are rejected by volume generation.

The structured mesh document stores base HEX8 cells. TET4 conversion occurs in the existing native/exporter paths. Before solving, inspection IDs refer to base cells. When current results supply connectivity, inspection uses actual solver nodes/elements. The inspector states this distinction explicitly; display triangles are not presented as FEM elements. Quality status now uses a compact formatted summary instead of dumping a dictionary into the status line.

## Persisted conditions and editing

`core/cae/condition_catalog.gd` is a read-only descriptor adapter over existing condition records. It does not introduce a second boundary-condition database. The explorer now lists each persisted fixed support, face force, pressure, prescribed displacement, gravity, volumetric heat source and thermal face temperature/flux/convection/radiation condition. Entries describe the owning body and target.

Selecting a condition opens a contextual editor with SI units, existing magnitude/vector components, validation through the authoritative document command and individual deletion. The new `RemoveCondition` document command removes exactly the selected record and participates in revision/history, undo/redo and stale mesh/result invalidation. No solver-side active flag was invented: all persisted conditions are active. Show/hide controls change the face target marker only, clearly labeled independently from numerical activation.

Targets are shown in the contextual editor; a different target can be specified through the existing analysis/condition dialog. Existing scalar condition slots remain single-per-body for pressure/gravity/prescribed displacement, while thermal conditions are keyed by kind and local face. Editing those representations does not claim arbitrary multiple-load cases. Deletion is reversible through document undo.

The existing radiation editor had an out-of-range label lookup; radiation now has actual emissivity and surroundings-temperature fields. Invalid temperatures, parameters and unsupported targets remain rejected by existing validation. The legacy bottom quick-action row is hidden: fixed/force actions moved to Loads & Constraints, density moved into Mesh, and node/element selection is discoverable in Inspection. Selection/face controls sit with the viewport controls. Existing shortcuts remain intact.

## Backend-specific solver configuration

Simulation now opens Solver configuration alongside analysis/time settings and Extreme CPU. The panel clearly distinguishes normal native PCG/Jacobi defaults from configurable independent CPU jobs. Normal-mode tolerance/preconditioner controls were not fabricated: the existing Godot solve adapter does not accept them.

Advanced settings persist under `analysis.extreme_solver`: Jacobi, Block Jacobi or IC(0), relative/absolute tolerance, maximum iterations, thread count and memory budget. Document validation checks finite tolerances, positive integral resource/iteration settings and supported methods. At least one nonnegative tolerance must be positive. Hardware memory screening remains native; a saved budget is not a reservation. Block-Jacobi applicability/fallback is identified in the UI, and tighter settings are not a claim of universally accurate high-contrast fluxes.

The existing standalone launcher appends supported CLI options to its argument array. No shell string or incompatible job trailer was introduced. Jobs without the new settings supply no additional flags and retain legacy behavior. Extreme CPU resource controls initialize from saved settings and can override threads/memory per launch. Restart reuses the saved job snapshot's preconditioner/tolerances/iteration limit, alongside its existing thread/memory controls. Transient thermal physical-state restart remains the supported scope; structural checkpoint and Krylov iteration restart are not claimed. The analysis dialog preserves advanced settings when changing ordinary study fields.

A Workflow check command summarizes Geometry → Materials → Mesh → Conditions → Solver → Results, lists existing model validation feedback and provides entry points for missing steps. Current document behavior conservatively invalidates the mesh when conditions or solver settings change, so regeneration is explicitly requested before standalone launch. This increment does not optimize that policy.

## Validation and screenshots

The existing default manifest passed **28/28**, with no script errors: [regression results and per-script logs](stage3-regression/results.json). Targeted compatibility and workflow results are saved under [stage3-checks](stage3-checks/results.json). Stage 1 and Stage 2 compatibility checks passed. The Stage 3 test runs both headless and graphically and covers:

- Actual element and node picking/highlighting, selection modes and face-target markers.
- Existing box mesh generation and mesh workspace access.
- Individual condition enumeration, pressure editing/deletion, undo/redo and snapshot invalidation.
- Radiation field editing, negative-Kelvin rejection and thermal condition enumeration.
- Small native structural and steady thermal solves.
- Advanced settings persistence and preservation through the analysis dialog.
- A tiny two-step transient Extreme job with IC(0), checking the actual emitted native configuration, result import, checkpoint creation and restart/import with preserved options.
- Project save/open and study configuration persistence.

Early configuration-test comparison used exact equality after JSON floating-point parsing; inspection confirmed the native output was `9.9999999999999994e-12` for the requested `1e-11`. The assertion now bounds configuration parsing error by `1e-24`; no numerical result comparison or solver tolerance was weakened. A mixed tree-metadata comparison error discovered during screenshot capture was corrected with a Dictionary type guard. Those error runs were not counted as passes.

Final graphical captures ran without script errors and were opened for visual inspection:

- [Conditions at 1280 × 720](stage3-conditions-1280.png)
- [Conditions at 1920 × 1080](stage3-conditions-1920.png)
- [Mesh workspace](stage3-mesh.png)

The screenshots show actual mesh and persisted pressure/support records. The condition controls fit at 720p; longer tree descriptions ellipsize with tooltips. Mesh options scroll within the inspector. Earlier quality dictionary output visibly crowded the status line and was replaced with scientific formatting. The existing ANSYS reference informs grouped engineering operations and target-centric inspection; UniCORE retains its dark palette and simpler implemented scope. Tests exercise handlers, controls and picking rather than exhaustive physical mouse/keyboard automation.

Headless dummy-renderer `mesh_get_surface_count` diagnostics remain in raw logs; final graphical workflow tests do not emit them. Historical app-shell **0xC0000005 remains unresolved**, is not suppressed, and is outside the default 28-test manifest. There is no claim that the entire application is crash-free.

## Modified files and remaining work

Stage 3 modifies `core/cae/cae_document.gd`, `core/cae/extreme_jobs.gd`, `ui/cae/analysis_editor.gd` and `ui/cae/cae_workspace.gd`; adds `core/cae/condition_catalog.gd`, `tests/test_workbench2_stage3.gd` and `tests/capture_workbench3.gd`; and adds this report, validation evidence and screenshots. Existing unrelated changes are preserved. Native binaries/kernels were not rebuilt because their sources were unchanged.

Remaining work: independently validated suppression/activation semantics if introduced later; richer target reassignment and multiple structural load cases; all-target marker rendering rather than the selected face only; generalized topology; preview of TET4 solver cells before solving; refinement/adaptive or non-box meshing; normal-mode advanced solver option transmission; deeper result/field navigation; full mouse/keyboard UI automation and measured large-model frame times. The existing asynchronous inspection preparation and cached displays remain; no new performance speedup or large-model responsiveness measurement is claimed.

Final validation note: the first saved graphical integration run failed because its test loop treated an intermediate status as terminal and attempted import before completion. It also compared unparsed and JSON-parsed floating-point settings with exact dictionary equality on that failure path. The failed logs are retained in `stage3-checks/initial-timing-failure/`. The corrected test waits for an actually completed, importable result within the same deadline and uses the explicit `1e-24` tolerance for solver-setting round trips. Final saved results are four passing targeted runs (Stage 1, Stage 2, Stage 3 headless, Stage 3 graphical), plus the 28/28 default manifest. The graphical Stage 3 workflow completed with zero failures and no script/renderer errors. The native status/publication implementation and numerical acceptance thresholds were unchanged.

# Stage 4 — geometry-to-FEM integration

Cylinder-only TET4 volume meshing is now integrated with the document, semantic Bottom/Top/Lateral targets, Mesh workspace, inspection and existing standalone CPU solver/export/import path. The normal Godot solver adapters remain box-only; cylinder Solve explicitly opens Extreme CPU guidance. No numerical kernel or tolerance was changed.

Read the [pre-change architecture audit](STAGE4-AUDIT.md) and [Stage 4 technical report](STAGE4.md) for the algorithm, bounds, boundary mapping, reference cases, convergence table, screenshots, timings and limitations. Analytical axial elasticity and steady conduction jobs pass at densities 1–3, including rotated geometry and cap pressure. Circle-reference errors decrease from 11.07% to 1.15% in displacement and 9.97% to 1.14% in heat rate; the polygon reference matches within the documented 1e-5 relative bounds. The default manifest passes 28/28; Stage 2/3 and checkpoint regression evidence is retained under `stage4-checks`.

This is the bounded cylinder/standalone increment. Mixed primitive meshes, normal-adapter cylinders, cylinder gravity, sphere/pipe, Booleans and arbitrary CAD solids remain unavailable. Historical app-shell **0xC0000005 remains unresolved**.

# Stage 5 — scientific postprocessing (partial)

See [Stage 5 report](STAGE5.md) for the field inventory, structural surface contours, deformation overlay, validation evidence and remaining milestone work.

Stage 5 continuation adds verified Extreme imports, measured cylinder quality distributions, a viewport legend, automatic deformation scale and result probes. See the continuation section in [STAGE5.md](STAGE5.md) for compatibility limits, numerical evidence and cylinder captures. The milestone remains partial.

Stage 5 stabilization is complete for the implemented subset: final default manifest 28/28, focused checks 15/15 and native configuration checks pass. Full feature completion is not claimed. The historical app-shell 0xC0000005 reproduced and remains unresolved; see the final stabilization section in [STAGE5.md](STAGE5.md).

Stage 5.1: [performance and crash diagnostics](STAGE5_1.md). Exact-state caches reduce cylinder median switching to about 37 ms in the controlled pair. Default 28/28 and focused/configuration 26/26 pass. Historical crash remains unresolved with WER module/offset evidence.

App-shell crash follow-up: [investigation and verified callback correction](GODOT_CRASH_INVESTIGATION.md). The tested reproduction now passes 91 assertions and exits 0 in five runs; default 28/28 remains passing. Native offset/function mapping remains unresolved; see the report for evidence and limits.
