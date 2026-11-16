# CAD & Meshing 2.5 — incomplete implementation

Further multi-body FEM integration is recorded in [CAD 2.5.1](CAD_MESHING_2_5_1.md).
The historical CAD 2.5 PARTIAL result below is unchanged.

Verdict: **PARTIAL**. This working increment is an independent mesh composition
foundation, not a completed assembly/contact checkpoint. CAD 2.4 remains the
current qualified engineering workflow. No CAD 2.5 analysis is qualified.

## Implemented scope

`scripts/engines/assembly_mesh.py` composes already generated, already positioned
instance meshes without coordinate deduplication. Separate instance meshes keep
distinct node indices even for identical coordinates. Elements retain explicit
instance and material ownership and per-instance index ranges. Connectivity
remains zero based until a future exporter assigns CalculiX IDs.

TET4 cells require positive finite determinants. TET10 requires explicit
CalculiX ordering and uses the existing whole-element Bernstein Jacobian
certificate. Missing/duplicate instance identities, missing material identities,
unused nodes, invalid indices and invalid connectivity are rejected. Material
identity is metadata here, not a solver section assignment.

The composer is deliberately not wired into deck generation: boundary ancestry,
outward surface orientation, persistent face references and interface membership
are not yet transported or independently validated. It must not be used to
publish an assembly solution. There is no node welding or substitute contact
mechanics. No existing production path or pinned binary was modified.

## Verification and environment

Four Python unit tests pass: coincident-node independence with different material
owners; duplicate ownership/inverted/invalid connectivity rejection; unverified
quadratic order rejection; and TET10 independence plus distorted-cell rejection.
These are ownership/geometry checks, not engineering solution evidence.

The inventory script seals source files and seven original pins against the
CAD24 completion receipt. Its first external write was denied by the sandbox;
the authorized retry succeeded. The raw inventory is at
`D:/PROJECT/TEST_OUTPUTS/CAD/cad25/inventory-1794688416828853100/inventory.json`.
It includes the dirty/untracked inventory, 910 source hashes, external path
existence checks and all seven unchanged pins. It was captured after adding the
composer/tests/inventory script, not before those additions. It is not a
pre-edit baseline. The initial inventory used expanded Git untracked reporting
and encountered one inaccessible historical directory; subsequent runs use
normal directory-level reporting. No historical files were modified.

## Outstanding mandatory gates

Assembly document/definitions/instances, native pairwise geometry inspection,
persistent instance-face references, independent Gmsh orchestration, material
sections, interfaces, assembly boundary assignments, deck auditing, nonlinear
convergence validation, solver contact results, GUI, persistence and lifecycle
integration are incomplete. The installed CalculiX 2.23 manual was located at
`.tools/engines/calculix/CalculiX-2.23.0-win-x64/doc/ccx_2.23.pdf`, but its
contact syntax has not been inspected or qualified. No formulation was selected.

No real CAD25 CalculiX runs, numerical qualification matrix, GUI screenshots,
runtime/memory campaign or cancellation campaign exist. No Hertz claim is made.
CAD21–24 and the 28 default regressions were not rerun in this increment; their
historical passes are not claimed as current validation. Repository total size
was not measured: inventory size covers focused source files only, excluding
vendor, caches and historical evidence. No large artifact was added to source.

Completing these gates requires further implementation and genuine acceptance
execution. This report cannot support a CAD25 PASS.
