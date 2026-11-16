"""Adversarial ownership checks; no claim of solver/contact qualification."""
import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'scripts/engines'))
from assembly_mesh import compose


class Ownership(unittest.TestCase):
    def setUp(self):
        self.part = dict(instance_id='a', material_id='steel', mesh=dict(
            nodes=[[0,0,0],[1,0,0],[0,1,0],[0,0,1]], elements=[[0,1,2,3]]))

    def test_coincident_nodes_stay_independent(self):
        other = copy.deepcopy(self.part)
        other.update(instance_id='b', material_id='rubber')
        result = compose([self.part, other])
        self.assertEqual(len(result['nodes']), 8)
        self.assertTrue(set(result['elements'][0]).isdisjoint(result['elements'][1]))
        self.assertEqual(result['material_regions'], ['steel','rubber'])
        self.assertEqual(result['node_owners'], ['a']*4+['b']*4)

    def test_reject_bad_ownership_and_geometry(self):
        with self.assertRaises(ValueError): compose([self.part, self.part])
        for cell in ([0,2,1,3], [0,1,2,4], [0,1,1,3]):
            bad = copy.deepcopy(self.part)
            bad['mesh']['elements'] = [cell]
            with self.assertRaises(ValueError): compose([bad])

    def test_reject_unverified_quadratic_order(self):
        self.part['mesh']['element_order'] = 2
        with self.assertRaises(ValueError): compose([self.part])

    def test_quadratic_geometry_and_independence(self):
        mesh = self.part['mesh']
        corners = copy.deepcopy(mesh['nodes'])
        mesh['nodes'] += [[(corners[a][i]+corners[b][i])/2 for i in range(3)]
                          for a,b in [(0,1),(1,2),(2,0),(0,3),(1,3),(2,3)]]
        mesh.update(element_order=2, node_order='CalculiX C3D10', elements=[list(range(10))])
        other = copy.deepcopy(self.part)
        other['instance_id'] = 'b'
        result = compose([self.part, other])
        self.assertEqual(result['elements'], [list(range(10)),list(range(10,20))])
        mesh['nodes'][4] = [20,20,20]
        with self.assertRaises(ValueError): compose([self.part])


if __name__ == '__main__': unittest.main()
