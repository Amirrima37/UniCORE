# Engineering model migration

Current document schema 1 remains unchanged: SI m-N-Pa-kg, parts, mesh,
analysis and results. Existing Extreme identity/provenance code remains intact.
No external exporter may reinterpret its indices without an explicit mapping.

Next schema must add stable geometry/node/element/face IDs, named selections,
material and unit identities, coordinate systems and immutable analysis settings.
Results require association (point/cell/integration point), tensor order and
strain definition, time/frequency/complex conventions, units and source IDs.
Unsupported mappings must reject. Existing structural and thermal importers
must not receive fabricated or incomplete fields from external solvers.
This schema extension is not yet implemented.
