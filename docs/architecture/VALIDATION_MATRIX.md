# Godot 4.7.2 migration validation (2026-11-13)

Migration status: **PARTIAL**, with the existing Workbench running graphically under the supplied 4.7.2 binary. The editor/class scan exits 0 without parser errors; the native GDExtension loads; real Vulkan Workbench captures exist at 1280×720 and 1920×1080. The 28 default regressions pass 28/28 with individual exit 0. Seven additional CalculiX/Gmsh/STEP checks each exit 0. The four Extreme build configurations pass 3,132 dynamic, structural, thermal, modal and restart assertions. Five consecutive shell startup/shutdown cycles each reach Shell ready and exit 0. Real graphical Box/Cylinder Gmsh → CalculiX runs display displacement and von Mises fields, but imported STEP → CalculiX is still unverified. The recorded Godot 4.0 minimal-project `0xC0000005` did not recur in these 4.7.2 runs. Receipts, screenshots, exact runtime hash and limits: [GODOT_4_7_2_MIGRATION.md](GODOT_4_7_2_MIGRATION.md).

# Validation checkpoint

Quick stabilization: PARTIAL. Asynchronous owned Gmsh worker and bounded DAT
import added; dedicated cancellation/timeout and malformed-result campaign still
pending. See [CALCULIX_STABILIZATION.md](CALCULIX_STABILIZATION.md).

Latest Workbench campaign (2026-11-13): **PARTIAL acceptance with real vertical
integration demonstrated**. Gmsh block/cylinder → CalculiX → existing viewport;
save/reopen and geometry/material/mesh/load staleness checks pass. Real Vulkan
screenshots exist at both requested resolutions. Reliable post-integration
default regressions: 28/28 exit 0. Axial error 5e-8; Extreme agreement ~2e-7;
cantilever refinement error 47.34% → 21.22% → 15.86% (accuracy not passed).
Owned cancellation/failure/recovery pass. See current section in
[CALCULIX_CHECKPOINT2.md](CALCULIX_CHECKPOINT2.md) for limits and evidence.
Older status tables below are historical.

External checkpoint 2: **PARTIAL**. Real CalculiX 2.23 executable acquired and
run on exported analytical TET4 patch jobs. Axial displacement/Poisson strain,
E/F scaling and input-byte tamper rejection pass. Full details and unfulfilled
acceptance requirements: [CALCULIX_CHECKPOINT2.md](CALCULIX_CHECKPOINT2.md).
The historical phase table below describes checkpoint 1; its CalculiX acquisition
blocker is superseded by this paragraph. Workbench integration remains absent.

|Phase|Status|Evidence / missing work|
|---|---|---|
|A architecture/acquisition|PARTIAL|Fail-closed contract, discovery, dependency panel; most source audits pending|
|B CAD/meshing|PARTIAL|Real Gmsh SDK smoke: OCCT block volume 6, STEP export, 932 TET4; no Workbench CAD/mesh adapter|
|C CalculiX|BLOCKED|Packaging revision resolved; executable/export/import not implemented|
|D OpenFOAM|BLOCKED|WSL discovery denied; no installation or flow calculation|
|E thermal/CHT|BLOCKED|Depends on D; no CHT claim|
|F advanced engines|BLOCKED|Source/platform/license audits pending|
|G coupling/postprocessing|BLOCKED|No participating external solver pair|

Godot registry regression: BACKEND_REGISTRY_PASS, process exit 0.
Native smoke: GMSH_OCCT_SMOKE_PASS volume=6 tet4=932, process exit 0.
Recorded rerun: volume=6, tet4=931, exit 0; mesh count is not a deterministic
acceptance target. Artifacts and full output: `evidence/gmsh/`.
Existing `test_stage6_dialog_ui.gd` passes cylinder and pipe condition workflows;
headless dummy renderer emits mesh surface warnings. No GUI screenshot was taken.
TET orientation, integrated mesh volume, physical groups, STEP reimport and
boolean tests remain pending; mesh numerical validation is not claimed.
Existing Extreme numerical tests were not rerun; original thresholds and evidence
remain unchanged. No genuine external Workbench result screenshot exists yet.

Continuation: finish Gmsh source archive integrity and source commit audit;
extend native tests through roundtrip/booleans, boundary and orientation checks;
implement actual Workbench CAD/meshing adapter; acquire CalculiX and implement
one strict static exporter plus DAT/FRD parser, analytical axial test and GUI
save/reopen/staleness acceptance. Retain original crash-investigation verdicts.

CAD expansion: PARTIAL infrastructure only; see docs/architecture/CAD_MESHING_CHECKPOINT.md. No new native or GUI acceptance claimed.
