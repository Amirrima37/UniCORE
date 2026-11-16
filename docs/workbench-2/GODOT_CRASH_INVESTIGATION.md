# Godot app-shell access violation investigation - 2026-11-12

## Finding and correction

The application-level trigger is localized to a retained **anonymous AnalysisDrawer event-bus listener inspected during deferred cleanup**. Replacing that subscription with an owner-bound named method corrects the reproduced full-suite failure: **91 assertions pass and the process exits 0 in five consecutive bounded runs**. The underlying Godot C++ memory defect and exact function at offset 0x518504 remain unproven; this report does not label the fault a confirmed use-after-free.

Only production change: `ui/analysis_drawer/analysis_drawer.gd`, replacing:

```gdscript
_event_bus.subscribe("interface_settings_changed", func(_d): _apply_cyber_styling())
```

with `_on_interface_settings_changed`, a bound method calling the same styling function. Event behavior is preserved. No solver, event-bus implementation, destruction order, numerical tolerance or unrelated subsystem was rewritten. New regression: `tests/test_analysis_drawer_listener_lifetime.gd` checks publication while alive and listener pruning/publication after actual deferred destruction.

## Evidence and localization

The supplied WinDbg evidence establishes an invalid READ: exception 0xc0000005, Godot executable offset 0x518504, instruction `mov rax,[rax+68h]` after `mov rax,[rcx+20h]`; RCX 0x000001F28351D960, RAX 0x000001F281F23570, read address 0x000001F281F235D8. The reported reserved/private region and absent heap allocation information do not by themselves identify an allocation lifetime or prove use-after-free. These addresses are supplied dump evidence, not addresses newly measured in these test processes.

The full original test reproduced 0xc0000005 after `91 Passed, 0 Failed`. It queues test UI/managers/world/event bus/settings objects for deletion and calls quit. The critical observable sequence is:

1. Standalone drawer subscribes its anonymous `interface_settings_changed` handler to the test EventBus.
2. The drawer is queued for deletion before the standalone ModuleManager.
3. `ModuleManager._exit_tree()` calls `EventBus.unsubscribe_all_for_target(self)`.
4. A diagnostic EventBus subclass logs each callable inspection. The last marker before the fault is `CALLABLE before is_valid interface_settings_changed` for the second listener in that event group; the corresponding after-marker is absent.

This identifies a script-level call site during deferred deletion, rather than just guessing from the final assertion banner. [Failing cleanup trace](crash-rootcause/traced.log). After the bound-method correction the same traced suite exits 0: [successful cleanup trace](crash-rootcause/traced-fixed.log).

The trace is not a native stack: it does not independently prove that the supplied dump's instruction belongs to a particular Godot source function. Export-symbol names were not used to assign responsibility.

## Controlled isolation experiments

Each experimental process was capped at 20-35 seconds. Production files and extension configuration were restored after temporary controls. Exact variant sources are archived as `.gd.txt` under [variants](crash-rootcause/variants/traced.gd.txt).

|Experiment before correction|Observed outcome|
|---|---|
|Original suite|0xc0000005, 91 assertions pass|
|Move body from _init to _initialize|Same crash|
|Defer test body|Same crash|
|Remove manual _ready calls|Same crash|
|Remove full main-scene group|Same crash; 77 assertions pass|
|Retain standalone drawer until tree teardown|Exit 0, no script errors|
|Retain standalone module manager|Exit 0, no script errors|
|Remove clipboard timer action|Same crash|
|Detach drawer before queue_free|Same crash|
|Full suite, extension auto-loading disabled|Same 0xc0000005|
|Full suite, only standalone drawer subscription changed to bound method in experimental subclass|Exit 0, all 91 assertions pass, no script errors|

Raw results: [first isolation](crash-rootcause/isolation.json), [individual deletions](crash-rootcause/single-deletion.json), [timer controls](crash-rootcause/timer-isolation.json), [bound-method controls](crash-rootcause/bound-control.json), [without-extension result](crash-rootcause/without-extension.json) and [log](crash-rootcause/without-extension.log). Disabling automatic extension loading used an empty `.godot/extension_list.cfg` only for that process; its original bytes were restored in `finally`. No explicit extension load occurs in this test/main script. This excludes extension loading as a requirement for this reproduction, not every conceivable extension interaction.

Simple Control deletion and small standalone listener/drawer/manager examples exit 0; the smaller settings/space/drawer-only reduction also exits 0. Thus a tiny independently failing reproducer was **not** obtained. The smallest confirmed reduction removes the main scene (77 assertions). Retaining objects may also change allocation/order; those observations alone were not treated as proof. The full-suite bound-method control and cleanup trace are the basis for the limited correction.

An additional attempt to reverse only the callback change timed out at 30 seconds. It is recorded as a timeout, **not** claimed as another confirmed access violation; `finally` restored the correction. [Control record](crash-rootcause/revert-control-attempt.json). Subsequent corrected traced suite exits 0. No failed experiment is silently counted as a pass.

## Exact validation

Five unchanged full-suite runs after the production correction, 30-second cap each:

|Run|Assertions|Process exit|Script errors|Duration s|
|---|---|---:|---:|---:|
|0|91 passed / 0 failed|0|0|9.257|
|1|91 passed / 0 failed|0|0|8.004|
|2|91 passed / 0 failed|0|0|7.101|
|3|91 passed / 0 failed|0|0|6.715|
|4|91 passed / 0 failed|0|0|7.028|

[Exact repeated-run results](crash-rootcause/fixed-runs.json), individual `fixed-0.log` through `fixed-4.log` are adjacent. The corrected traced run is an additional successful full-suite execution.

Existing default manifest: **28 passed / 0 failed**, zero script errors/timeouts: [results and logs](crash-rootcause/regression/results.json). The manifest remains the original 28 entries; the app-shell test has not been silently folded into that count.

Focused checks: destroyed-drawer listener cleanup, exact baseline/optimized FEM contour buffers, numerical probes, actual structural graphics and thermal/radiation/transient-playback graphics all exit 0 with zero script errors: [results](crash-rootcause/focused.json). Eight screenshots at 1280x720 and 1920x1080 were opened and inspected: `render-box-{displacement,von_mises,temperature,heat_flux}-{1280,1920}.png` in the evidence directory. No new visible numerical/rendering regression was observed.

The full headless app-shell logs are **not error-free**: existing dummy-renderer `mesh_get_surface_count` messages and duplicate manual-_ready `resized` connection diagnostics remain. They were already documented in prior work and were not suppressed or changed by this correction. There are no new script errors or new diagnostic classes in the tested correction; clean process exit must not be confused with a completely clean diagnostic log. The isolated new listener regression and graphical checks pass separately. No native numerical sources changed.

## Source-function mapping and remaining uncertainty

No matching PDB/debug-symbol package or equivalent symbolized executable was obtained. Installed addr2line cannot resolve the preferred-image address corresponding to 0x518504: [mapping output](crash-rootcause/address-mapping.txt), [address calculation](crash-rootcause/address-mapping.json). That preferred address is not asserted to be the ASLR runtime address. Attempts to fetch the official Godot 4.0 lambda-callable source were unavailable through the connected web tool; no inferred source name is presented as a verified offset mapping.

What is verified: the failing cleanup call site, the retained anonymous subscription involved, independence from automatic extension loading, and repeated full-suite success after a minimal bound-method correction. What remains unknown: the precise Godot native lifetime/ownership defect, which memory object the dump's registers reference, and whether a generic engine-level defect requires a separate upstream fix. This is a verified correction for the observed application reproduction, not a claim that all Godot shutdown faults or all anonymous-callable lifetimes are repaired.

All unrelated working-tree changes were retained. The original app-shell assertions and cleanup sequence were left unchanged. Historical Stage 5/5.1 reports remain historical evidence; this report supersedes their unresolved status only for the tested reproduction and correction above.
