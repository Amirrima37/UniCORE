# Repository Cleanup 1.1 — PARTIAL

Deleted 10 obsolete successful build logs (985,394 bytes). NTFS compression reclaimed 2,517,491,921 API-reported storage bytes in generated output and evidence. Every compressed file was verified with SHA-256 before and after. Nothing was relocated.

Accessible logical size: 8,571,221,380 → 8,588,675,032 bytes; files: 80,026 → 80,031. This is not a complete project total: 12 paths were inaccessible and their sizes are unknown. Reparse points were not followed.

The physical savings come from NTFS compression, not deletion of the compressed files. Logical directory size remains largely unchanged. New audit records also consume storage. Compression saves reported here are gross savings for the selected files, not a whole-volume free-space measurement.

28/28 default regressions: True; exit 0. Workspace: `C:\Users\Victus\AppData\Local\Temp\unicore-regressions-c_bek6p2`. All seven original pinned hashes unchanged: True. A real native Fuse returned VALID, volume 0.003 m³, exit 0. An initial Cut probe produced multiple solids and failed its single-solid assertion; the supported Fuse probe then passed.

## Exact operations and recovery

See [deleted logs](evidence/cleanup11/old-build-logs-deleted.json), [compression manifest](evidence/cleanup11/compression-manifest.json), [commands and exits](evidence/cleanup11/compression-operations.json), [before inventory](evidence/cleanup11/before-inventory.json.gz), [after inventory](evidence/cleanup11/after-inventory.json.gz), and [final receipt](evidence/cleanup11/final-receipt.json). Each deleted log records path, size, hash and recovery method. Old log contents were intentionally discarded; a build can generate a fresh transcript.

Compressed files retain their names, relative paths and exact bytes. To undo compression for a directory, run `compact /U /S:"<absolute-directory>" *` from that directory. No external archive or relocation occurred. Historical acceptance evidence remains directly accessible.

Default regressions now choose a unique temporary workspace and put their Godot profile there. `UNICORE_TEST_OUTPUT_ROOT` chooses an existing parent; `--output` explicitly overrides the destination. Results and failure diagnostics are retained for review. Other historical acceptance runners still require migration.

## Thirty largest directories before

- .tools: 6991551959 bytes
- .tools/godot472-migration: 2885643083 bytes
- .tools/godot472-migration/roaming/Godot: 2839191986 bytes
- .tools/godot472-migration/roaming: 2839191986 bytes
- .tools/godot472-migration/roaming/Godot/app_userdata/UniCORE: 2839174280 bytes
- .tools/godot472-migration/roaming/Godot/app_userdata: 2839174280 bytes
- .tools/occt-sdk: 1915898756 bytes
- .tools/occt-sdk/ucrt64: 1680389656 bytes
- docs: 1349778142 bytes
- .tools/godot472-migration/roaming/Godot/app_userdata/UniCORE/calculix_jobs: 1222501492 bytes
- .tools/occt-sdk/ucrt64/lib: 1052490517 bytes
- docs/architecture: 1041962631 bytes
- docs/architecture/evidence: 1041812270 bytes
- .tools/hpc23-bench: 817649820 bytes
- docs/architecture/evidence/cad23: 679496594 bytes
- .tools/hpc22: 498479590 bytes
- .tools/occt-sdk/ucrt64/bin: 384682025 bytes
- docs/architecture/evidence/cad23/solver-jobs: 359941240 bytes
- .tools/hpc23-bench/thermal-large-46: 359759892 bytes
- .tools/engines: 280422795 bytes
- .tools/occt-sdk/ucrt64/lib/gcc/x86_64-w64-mingw32/15.1.0: 202066046 bytes
- .tools/occt-sdk/ucrt64/lib/gcc/x86_64-w64-mingw32: 202066046 bytes
- .tools/occt-sdk/ucrt64/lib/gcc: 202066046 bytes
- .tools/occt-sdk/ucrt64/lib/python3.12: 191518674 bytes
- .tools/hpc23-bench/elastic-large-32: 187546205 bytes
- docs/workbench-2: 181896639 bytes
- docs/architecture/evidence/cad24-completion: 172785191 bytes
- .tools/occt-sdk/ucrt64/share: 170915303 bytes
- docs/architecture/evidence/cad23/lifecycle: 170481670 bytes
- .tools/godot472-migration/roaming/Godot/app_userdata/UniCORE/cad_geometry: 156113150 bytes

## Twenty largest directories after

- .tools: 6990587629 bytes
- .tools/godot472-migration: 2885643083 bytes
- .tools/godot472-migration/roaming/Godot: 2839191986 bytes
- .tools/godot472-migration/roaming: 2839191986 bytes
- .tools/godot472-migration/roaming/Godot/app_userdata/UniCORE: 2839174280 bytes
- .tools/godot472-migration/roaming/Godot/app_userdata: 2839174280 bytes
- .tools/occt-sdk: 1915898756 bytes
- .tools/occt-sdk/ucrt64: 1680389656 bytes
- docs: 1368176760 bytes
- .tools/godot472-migration/roaming/Godot/app_userdata/UniCORE/calculix_jobs: 1222501492 bytes
- .tools/occt-sdk/ucrt64/lib: 1052490517 bytes
- docs/architecture: 1041962631 bytes
- docs/architecture/evidence: 1041812270 bytes
- .tools/hpc23-bench: 817649820 bytes
- docs/architecture/evidence/cad23: 679496594 bytes
- .tools/hpc22: 498479590 bytes
- .tools/occt-sdk/ucrt64/bin: 384682025 bytes
- docs/architecture/evidence/cad23/solver-jobs: 359941240 bytes
- .tools/hpc23-bench/thermal-large-46: 359759892 bytes
- .tools/engines: 280422795 bytes

## Limitations

- Logical active-directory 30% reduction not achieved; NTFS compression reduces physical storage while retaining logical file sizes
- Full migration of historical CAD acceptance runners to external roots remains unfinished; only default regression runner migrated
- No external archival destination configured; historical evidence remains in place
- No SDK development files removed
- NTFS compression is transparent and reversible; it may add CPU work when reading large compressed outputs
- No new TET10, CalculiX or save/reopen acceptance run; previous cleanup1 full campaign is historical evidence only
- Regression temporary workspace retained for diagnostic review; no automatic deletion of its potentially active jobs
