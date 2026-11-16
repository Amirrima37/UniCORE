# Repository Cleanup & Optimization 1.0 — PARTIAL

Only source-backed bytecode cleanup qualified; SDK slimming and external evidence archival deferred.

Readable baseline: 7,964,948,362 bytes / 77,038 files. After: 8,571,219,214 bytes / 80,025 files.
Net reduction: -606,270,852 bytes (-7.6117%). Recorded bytecode deletions: 751,756 bytes / 56 files; 551,989 bytes remain absent after testing.

Measurements include new inventories and test outputs. Logical file lengths are measured, not allocated NTFS blocks. Inaccessible directories are omitted; the total is a lower bound. Relocations, compression savings, external archives and SDK removals: zero. No claim of substantial space savings.

Default regressions: {"passed": true, "expected": 28, "recorded": 28, "missing": [], "results_file": "results.json"}
Pre-existing source hash changes: 1. Seven original binary hashes preserved: True.

## Evidence and recovery

See [final receipt](evidence/cleanup1/final-receipt.json), [plan](cleanup-plan.json), [deletion manifest](evidence/cleanup1/deleted-manifest.json), [baseline inventory](evidence/cleanup1/baseline-inventory.json), [after inventory](evidence/cleanup1/after-inventory.json), [source hashes](evidence/cleanup1/source-hashes.json), and [exact duplicate candidates](evidence/cleanup1/duplicate-candidates.json). Python recreates removed bytecode on import. Each deletion records source, hash, size and Git status. No production source, SDK package, job, screenshot, solver result or historical evidence was removed.

## Remaining work and limitations

- No SDK reconstruction attempted: external D:/msys64 compiler dependency retained
- No external archive destination established: all historical evidence preserved
- Reference audit limited to bytecode source backing; no SDK or engineering artifacts deleted
- Inventory access-denied omissions prevent exact whole-project accounting
- Campaign results listed are fresh latest receipts; missing stages must not be treated as passing

The PE import audit traverses executable/DLL imports with objdump and reports missing modules. Static imports alone do not establish dynamic-loading completeness. Existing runtime verification checks all 243 SDK DLLs plus external winpthread; these remain intact. Build/provision scripts and package hashes remain unchanged. Offline execution paths are unchanged.

The current campaign uses existing runners, which also write established latest receipts and generate fresh jobs. All attempts remain available. No historical PASS is substituted for a new run. Complete campaign details and actual exit codes are in the machine receipt.

## Largest directories after cleanup

- .tools: 6991551959 bytes
- .tools/godot472-migration: 2885643083 bytes
- .tools/godot472-migration/roaming: 2839191986 bytes
- .tools/occt-sdk: 1915898756 bytes
- .tools/occt-sdk/ucrt64: 1680389656 bytes
- docs: 1349778143 bytes
- docs/architecture: 1041962631 bytes
- docs/architecture/evidence: 1041812270 bytes
- .tools/hpc23-bench: 817649820 bytes
- .tools/hpc22: 498479590 bytes
- .tools/hpc23-bench/thermal-large-46: 359759892 bytes
- .tools/engines: 280422795 bytes

## Context discovery

Focused source inventory lists 891 paths versus 77038 readable baseline files. Fixtures and required configuration remain discoverable. AGENTS.md provides architecture and testing guidance; explicit shell reads can still access ignored files. No unsupported .codexignore behavior is assumed.

## Fresh acceptance campaign

Recorded 34 fresh stage receipts. Numerical rows: {"cad23": {"path": "docs/architecture/evidence/cad23/numerical.json", "rows": 32}, "cad24": {"path": "docs/architecture/evidence/cad24-completion/structural-numerical.json", "rows": 6}}.

| Stage | Outcome | Exit |
| --- | --- | --- |
| boundary | PASS | 0 |
| cad21-geometry | PASS | 0 |
| cad21-integration | PASS | 0 |
| cad21-lifecycle | PASS | 0 |
| cad21-preservation | PASS | 0 |
| cad22-independent | PASS | 0 |
| cad22-lifecycle | PASS | 0 |
| cad22-numerical | PASS | 0 |
| cad22-persistence | PASS | 0 |
| cad22-validation | PASS | 0 |
| cad23-gui | PASS | 0 |
| cad23-independent | PASS | 0 |
| cad23-lifecycle | PASS | 0 |
| cad23-numerical | PASS | 0 |
| cad23-persistence | PASS | 0 |
| cad23-shutdown | PASS | 0 |
| cad23-unit | PASS | 0 |
| cancel-cut | PASS | 0 |
| cancel-step | PASS | 0 |
| deck-audit | PASS | 0 |
| endurance | PASS | 0 |
| failure | PASS | 0 |
| gui-endurance | PASS | 0 |
| gui | PASS | 0 |
| history | PASS | 0 |
| matrix-extra | PASS | 0 |
| native | PASS | 0 |
| numerical | PASS | 0 |
| owner-exit | PASS | 0 |
| protocol | PASS | 0 |
| regressions | PASS | 0 |
| retention | PASS | 0 |
| scan | PASS | 0 |
| timeout | PASS | 0 |

The cleanup inventory script was created before the baseline and later updated with rerun protection and scan-error reporting. Its intentional hash change is recorded separately from user sources. Unexpected source changes: [].

