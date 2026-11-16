# External development environment migration — PARTIAL

Accessible repository size: 8,072,880,752 → 3,724,213,443 bytes. Net reduction: 4,348,667,309 bytes (53.87%). Relocated 4,350,077,065 bytes; 4,350,077,065 original file bytes removed after copy and validation. No junctions were installed.

| Destination | Migrated bytes | Current bytes |
| --- | ---: | ---: |
| `D:\PROJECT\SDK\OCCT` | 1,632,478,416 | 1,633,796,686 |
| `D:\PROJECT\GODOT\TEST_ENVIRONMENTS\godot472-migration` | 2,717,598,649 | 2,760,030,096 |

## Configuration

Central Python configuration: `scripts/engines/development_paths.py`. `UNICORE_OCCT_SDK_ROOT` defaults to `D:/PROJECT/SDK/OCCT`; `UNICORE_GODOT_ENV_ROOT` defaults to `D:/PROJECT/GODOT/TEST_ENVIRONMENTS/godot472-migration`; `UNICORE_TEST_OUTPUT_ROOT` defaults to `D:/PROJECT/TEST_OUTPUTS`. Godot472 build objects use `UNICORE_BUILD_CACHE_ROOT` or `D:/PROJECT/CACHE/BUILD`. Overrides are process-local. Godot tests share `tests/development_paths.gd`. `scripts/run_godot472.ps1 -TestEnvironment` uses the migrated test profile. The pinned Godot executable was not moved.

Updated path/configuration files: 71. SDK packages, headers, import libraries, CMake metadata and runtime files retain their relative layout. SDK provisioning verifies the same package locks; no new runtime downloads were introduced.

## Validation

SDK worker and fixture builder rebuilt successfully from the external SDK. Godot editor scan, native BREP validation, Fuse/Cut/Common, STEP transforms, persistent history, six TET4/TET10 CalculiX structural cases and save/reopen passed. Default regressions passed 28/28 before removal and again after removal. All seven pinned original hashes are unchanged. Actual commands/logs are under `D:\PROJECT\TEST_OUTPUTS\CAD\external-migration-1794681208224569100`.

- build: exit 0, passed True
- editor: exit 0, passed True
- native: exit 0, passed True
- history: exit 0, passed True
- structural: exit 0, passed True
- regressions: exit 0, passed True
- native-after-removal: exit 0, passed True
- regressions-after-removal: exit 0, passed True

## Evidence and recovery

[Manifest](evidence/external-migration/manifest.json) records every migrated relative filename, size and critical SHA-256. [Validation](evidence/external-migration/validation.json) records destination qualification. [Final receipt](evidence/external-migration/final-receipt.json) contains final measurements and hashes. Accessible source/destination file counts and bytes matched before originals were removed. Initial copy attempts stopped on protected scratch folders; verified staging data was resumed without overwriting existing destinations. Windows read-only source headers were removed only after destination verification. Inaccessible originals were preserved.

Use manifest source/destination mapping. To restore, copy destination files back without overwriting user files, verify critical hashes, and set UNICORE_OCCT_SDK_ROOT / UNICORE_GODOT_ENV_ROOT to restored paths. Original worker/build manifest are retained under SDK/OCCT/migration-original-build.

Historical receipts retain their original paths: translate `.tools/occt-sdk/` and `.tools/godot472-migration/` through the manifest. Historical acceptance evidence under docs was not moved or edited.

Relocation reduces repository footprint. C: source and D: destination are different volumes; no whole-machine free-space saving is claimed. Previously compressed files may occupy more space at the destination.

## Remaining components and limitations

- Inaccessible scratch directories remain; their sizes are unknown. Report totals cover accessible regular files only.
- Existing shared D:/msys64 and C:/Qt toolchains remain in place; external SDK build still requires them.
- SDK package archives remain with their locked SDK-local names for offline reconstruction.
- Project .godot cache remains local because Godot imports use the project directory; editor scan verified it.
- Other historical HPC benchmark directories remain in .tools; historical reports and receipts are preserved.
- Legacy SCons build still uses its established local intermediate paths; active Godot472 builder uses external cache.

- .tools/hpc23-bench: 817649820 bytes
- .tools/hpc22: 498479590 bytes
- .tools/engines: 211687494 bytes
- .tools/godot: 114631456 bytes
- .tools/extreme-axial: 78149702 bytes
- .tools/godot-cpp-4.7: 53500139 bytes
- .tools/stage5-final-native: 42767688 bytes
- .tools/cae-appdata: 32660421 bytes
- .tools/python-packages: 22784988 bytes
- .tools/scons-migrate: 22784988 bytes
- .tools/hpc24-paired: 19578502 bytes
- .tools/hpc24-final-paired: 19578460 bytes
- .tools/molecular-native-2as4khhu: 10805891 bytes
- .tools/molecular-native-o6zi8uc_: 10200668 bytes
- .tools/molecular-native-883glfnc: 10200183 bytes
- .tools/hpc24-initial: 9789303 bytes
- .tools/step-calculix: 9213978 bytes
- .tools/molecular-script-a68wwea5: 8059710 bytes
- .tools/molecular-script-4669g3vh: 8008402 bytes
- .tools/molecular-script-d0l712ju: 8007916 bytes
- .tools/hpc23-tight: 7555908 bytes
- .tools/packages: 6444676 bytes
- .tools/script-package-check: 5480662 bytes
- .tools/hpc21-equivalence: 2935951 bytes
- .tools/hpc22-fallback: 2526704 bytes
- .tools/hpc23-configs: 2501652 bytes
- .tools/lifetime-large: 1896752 bytes
- .tools/extreme-thermal: 1432326 bytes
- .tools/crash-isolation: 414631 bytes
- .tools/hpc22-final: 195805 bytes
- .tools/hpc23-final: 195281 bytes
- .tools/hpc21-baseline: 195279 bytes
- .tools/hpc21-final: 195275 bytes
- .tools/extreme-final-validation: 191718 bytes
- .tools/hpc-baseline: 191717 bytes
- .tools/cae-upgrade-regression: 191366 bytes
- .tools/cae-upgrade-final: 191236 bytes
- .tools/extreme-extended-final: 191191 bytes
- .tools/mesh-regression: 187135 bytes
- .tools/all-solvers-native-regression: 183353 bytes
- .tools/regression: 182708 bytes
- .tools/molecular-native-regression-final: 182223 bytes
- .tools/molecular-native-regression: 182222 bytes
- .tools/stage51-baseline: 131681 bytes
- .tools/extreme-baseline: 37181 bytes
- .tools/extreme-final: 37180 bytes
- .tools/cae-upgrade-manifest: 37178 bytes
- .tools/mesh-final-regression: 36773 bytes
- .tools/engineering-cycle-regression: 33773 bytes
- .tools/hpc24-modes: 33188 bytes
- .tools/extreme-config: 19278 bytes
- .tools/dynamic-import-367713: 18397 bytes
- .tools/hpc24-options: 16921 bytes
- .tools/hpc23-options: 12727 bytes
- .tools/hpc24-config: 11119 bytes
- .tools/extreme-restart: 10516 bytes
- .tools/test-appdata: 8400 bytes
- .tools/extreme-checkpoint: 8349 bytes
- .tools/hpc24-checkpoint: 7381 bytes
- .tools/hpc23-checkpoint-block-jacobi: 6317 bytes
- .tools/hpc23-checkpoint-ic0: 6171 bytes
- .tools/extreme-cli: 4921 bytes
- .tools/hpc24-cli: 4849 bytes
- .tools/hpc23-smoke: 1537 bytes
- .tools/mesh-fingerprint-fix: 1274 bytes
- .tools/extreme-example: 777 bytes
- .tools/crash-minimal: 117 bytes
- .tools/extreme-cancel: 47 bytes

Final editor scan after the remaining GUI output redirects: exit 0, no script errors.
