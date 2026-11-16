# Architecture navigation

Current assembly CAD authority: [CAD 2.5.1-E](CAD_2_5_1_E_FINAL_ACCEPTANCE.md) and
[measured acceptance receipt](evidence/cad251-final-acceptance/final-receipt.json).
The earlier [CAD & Meshing 2.4](CAD_MESHING_2_4.md) and
[2.4 receipt](evidence/cad24-completion/final-receipt.json) remain preserved.
Earlier contracts: [2.1](CAD_MESHING_2_1.md), [2.2](CAD_MESHING_2_2.md),
[2.3](CAD_MESHING_2_3.md). Consult the relevant report without reading all history.

| Subsystem | Sources |
| --- | --- |
| CAD, mesh and boundary identity | [core/cae](../../core/cae/) |
| GUI workflows | [ui/cae](../../ui/cae/) |
| Owned jobs and retention | [scripts/engines](../../scripts/engines/) |
| OCCT build and provenance | [native/occt](../../native/occt/) |
| Physics kernels | [native/src](../../native/src/) |
| Acceptance and fixtures | [tests](../../tests/) |

Use `python scripts/source_files.py` for ordinary discovery. Evidence directories
contain raw historical campaigns and must remain available, but need not enter
routine context. Git ignores affect ordinary `rg --files`, not explicit reads.
No `.codexignore` support has been verified; no such file is installed here.

Development SDK and Godot testing paths now live outside the source repository.
See [external migration](../maintenance/EXTERNAL_ENVIRONMENT_MIGRATION.md) and
`scripts/engines/development_paths.py`. Historical receipts retain their original
paths; map `.tools/occt-sdk/` to `D:/PROJECT/SDK/OCCT/` and
`.tools/godot472-migration/` to
`D:/PROJECT/GODOT/TEST_ENVIRONMENTS/godot472-migration/` using the migration
manifest. Historical reports themselves are preserved.
See [Codex instruction documentation](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
and the [open ignore feature request](https://github.com/openai/codex/issues/24993).
