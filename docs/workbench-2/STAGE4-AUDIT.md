# Stage 4 pre-change geometry-to-FEM audit

The document stores primitive kind, dimensions, position, Euler rotation, scale, material and parametric conditions. Cylinder dimensions[0] is diameter and dimensions[1] is length along local Y. The viewport creates a separate surface mesh for display; those triangles have no persistent physical meaning.

Native generate_mesh accepts only Box, stores structured HEX8 cells and six local-face node groups. Structural and thermal normal adapters regenerate that mesh, assume divisions^3 cells per body and split HEX8 into six TET4 where requested. They cannot safely consume arbitrary new saved TET4 connectivity without adapter changes. Kernels themselves already support TET4.

The independent exporter accepts 4/8-node connectivity, resolves material ownership through material_regions, extracts actual exterior faces and targets node groups for loads/thermal conditions. Its gravity path alone assumes structured HEX8 layout and must be guarded or generalized before cylinder gravity is exposed. Results retain exported connectivity for inspection.

Implementation decision: add a bounded cylinder meshing service and authoritative document dispatch, using the existing independent CPU TET4 backend. Keep normal adapters and box mesher unchanged. Reject mixed primitives in this first path, cylinder HEX8, sphere/pipe, nonuniform radial scaling and unsupported cylinder gravity. Supply stable Top/Bottom/Lateral regions and explicit exterior triangle groups. Validate orientation, determinant, conformity and polygon area convergence. Normal-mode cylinders must direct users to Extreme CPU rather than regenerate boxes.
