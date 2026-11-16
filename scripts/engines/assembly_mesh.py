"""Independent-mesh composition. Never weld coincident coordinates.

Input connectivity uses the existing zero-based CalculiX ordering. This module
does not detect contact or certify CAD identity; callers must supply qualified
instance meshes. It deliberately cannot generate a solver deck.
"""
import math
from quadratic_tet import element_quality


def compose(parts):
    result = dict(nodes=[], elements=[], node_owners=[], element_owners=[],
                  material_regions=[], instances={}, units='SI', schema=1,
                  element_metadata=[])
    for part in parts:
        key = part['instance_id']
        if not isinstance(key, str) or not key or key in result['instances']:
            raise ValueError('Missing or duplicate instance identity')
        material = part['material_id']
        if not isinstance(material, str) or not material:
            raise ValueError('Explicit material ownership required')
        mesh = part['mesh']
        order = mesh.get('element_order', 1)
        if order not in (1, 2):
            raise ValueError('Only TET4/TET10 supported')
        if order == 2 and mesh.get('node_order') != 'CalculiX C3D10':
            raise ValueError('Unverified quadratic node order')
        points, cells = mesh['nodes'], mesh['elements']
        if not points or not cells:
            raise ValueError('Empty instance mesh')
        for point in points:
            if len(point) != 3 or any(type(x) not in (int, float) or not math.isfinite(x) for x in point):
                raise ValueError('Invalid coordinate')
        used = set()
        for cell in cells:
            if len(cell) != (4 if order == 1 else 10) or len(set(cell)) != len(cell):
                raise ValueError('Invalid connectivity')
            if any(type(i) is not int or not 0 <= i < len(points) for i in cell):
                raise ValueError('Invalid local node index')
            used.update(cell)
            if order == 2:
                if element_quality([points[i] for i in cell])['jacobian'] <= 0:
                    raise ValueError('Nonpositive quadratic Jacobian')
            else:
                a, b, c, d = [points[i] for i in cell]
                u, v, w = [[p[i]-a[i] for i in range(3)] for p in (b, c, d)]
                determinant = sum(u[i]*(v[(i+1)%3]*w[(i+2)%3]-v[(i+2)%3]*w[(i+1)%3]) for i in range(3))
                if not math.isfinite(determinant) or determinant <= 0:
                    raise ValueError('Nonpositive tetrahedron')
        if used != set(range(len(points))):
            raise ValueError('Unowned unused nodes')
        offset = len(result['nodes'])
        element_offset = len(result['elements'])
        result['nodes'].extend([list(p) for p in points])
        result['elements'].extend([[offset+i for i in cell] for cell in cells])
        result['node_owners'].extend([key]*len(points))
        result['element_owners'].extend([key]*len(cells))
        result['material_regions'].extend([material]*len(cells))
        result['element_metadata'].extend(dict(instance_id=key, material_id=material,
            element_type='C3D4' if order==1 else 'C3D10',local_element_id=i+1,
            global_element_id=element_offset+i+1) for i in range(len(cells)))
        result['instances'][key] = dict(node_range=[offset, offset+len(points)],
                                       element_range=[element_offset, element_offset+len(cells)],
                                       element_order=order, material_id=material)
    if not result['instances']:
        raise ValueError('Empty assembly')
    return result
