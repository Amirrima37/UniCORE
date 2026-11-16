# CAD 2.5.1-A implementation status: PARTIAL

Production changes: `core/cae/assembly_model.gd` and
`core/cae/cae_document.gd`. No numerical qualification files or pinned binaries
were changed by this implementation.

AssemblyModel supplies `uuid`, `geometry`, `synchronize`, and `validate`.
Document.execute now supports CreatePartDefinition, AddInstance,
DuplicateInstance, RemoveInstance, TranslateInstance and RotateInstance.
AssignMaterial and SetVisibility retain their existing validation and operate
independently on each instance. Existing Workbench commands also maintain the
assembly metadata. Geometry edits create a new immutable definition rather than
editing another instance's geometry. Undo restores the previous reference.

Document schema remains 1; additive assembly_schema is 1. part_definitions maps
UUID to {uuid, geometry_revision, geometry, template}. The compatibility parts
array remains the instance view, with existing fields plus instance_uuid,
definition_uuid, geometry_revision and transformation_revision. Geometry is
currently duplicated in that compatibility view and in the stored template;
this is not yet a storage-deduplicated assembly representation. Definitions
retain a template so they remain instantiable after the last instance is removed.
Material, visibility, position and rotation belong to parts. Rotation is radians
in the existing document convention; translation commands set absolute position.
Legacy documents without assembly_schema acquire identities on reopen.

Focused test: Godot 4.7.2, tests/cad251_assembly.gd, exit 0, ASSEMBLY_PASS.
Save/reopen succeeded in assembly-test.json. Example shared definition UUID:
55b6cd60-cd0f-4e6e-8626-9175f72b0dd8. Instance UUIDs:
bf9215c5-a4af-4658-a7ed-426e97b17594 and
b7a31431-eddb-417b-b1cb-bc6da44f52b4. The second box is at (3,0,0),
rotated pi/2 about Z. Its first mesh node has X=3.1, while the first
instance remains at the origin. Definition geometry stays unchanged.
Tests also cover deletion, duplicate, independent material/visibility,
copy-on-edit geometry, undo and legacy reopening. These are focused document
tests; the interactive Workbench workflow has not been independently exercised.

Missing functionality: native OCCT BREP instance placement and transformed
Gmsh assembly meshing are not connected. gmsh_study.py rejects rotation/scale;
CAD import otherwise uses source coordinates. Native worker transform exists,
but no native API failure was demonstrated in this attempt. CAD SetPosition
and SetRotation now explicitly reject unsupported placement rather than silently
claiming success. The exercised transformed mesh is the existing box mesh path,
whose GDScript fallback now applies instance rotation and scale to volume nodes.
This does not satisfy the native geometry integration completion criterion.
The full basic GUI/native regression suite was not run. No PASS claim for
CAD 2.5.1-A is made.
