"""Independent audit of actual INP bytes, without importing exporter code."""
import json, math, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts/engines'))
from development_paths import test_output_root, godot_environment_root

def audit(path):
    nodes={};elements={};sets={};sections={};materials=set();loads=[];constraints=[]
    mode='';params={}
    for line in path.read_text().splitlines():
        line=line.strip()
        if not line or line.startswith('**'):continue
        if line.startswith('*'):
            tokens=[s.strip().upper() for s in line.split(',')]
            mode=tokens[0];params=dict(t.split('=',1) for t in tokens[1:] if '=' in t)
            if mode in ['*TIE','*EQUATION','*MPC','*CONTACT PAIR','*SPRING']:raise ValueError('Unintended coupling')
            if mode=='*MATERIAL':materials.add(params['NAME'])
            if mode=='*SOLID SECTION':
                if params['ELSET'] in sections:raise ValueError('Duplicate section')
                sections[params['ELSET']]=params['MATERIAL']
            continue
        fields=[s.strip() for s in line.split(',') if s.strip()]
        if mode=='*NODE':
            key=int(fields[0]);assert key not in nodes
            nodes[key]=list(map(float,fields[1:]));assert len(nodes[key])==3
        elif mode=='*ELEMENT':
            key=int(fields[0]);assert key not in elements
            cell=list(map(int,fields[1:]));assert len(cell)==(10 if params['TYPE']=='C3D10' else 4)
            elements[key]=cell
        elif mode=='*ELSET':sets.setdefault(params['ELSET'],[]).extend(map(int,fields))
        elif mode=='*CLOAD':loads.append((int(fields[0]),int(fields[1])-1,float(fields[2])))
        elif mode=='*BOUNDARY':constraints.append(int(fields[0]))
    ownership={};node_regions={}
    for region,material in sections.items():
        assert material in materials and region in sets
        node_regions[region]=set()
        for element in sets[region]:
            assert element in elements and element not in ownership
            ownership[element]=region;node_regions[region].update(elements[element])
    assert set(ownership)==set(elements)
    for a in node_regions:
        for b in node_regions:
            if a!=b:assert node_regions[a].isdisjoint(node_regions[b])
    assert all(n in nodes for cell in elements.values() for n in cell)
    assert all(n in nodes for n in constraints)
    force=[0.,0.,0.];moment=[0.,0.,0.]
    for node,axis,value in loads:
        assert node in nodes and axis in range(3) and math.isfinite(value)
        force[axis]+=value
        f=[0.,0.,0.];f[axis]=value;p=nodes[node]
        for i in range(3):moment[i]+=p[(i+1)%3]*f[(i+2)%3]-p[(i+2)%3]*f[(i+1)%3]
    assert len(sections)>=2 and abs(force[1]-1000*len(sections))<1e-6
    return dict(deck=str(path),nodes=len(nodes),elements=len(elements),sections=sections,force_N=force,moment_Nm=moment)

if __name__=='__main__':
    out=test_output_root()/'CAD/cad251'
    rows=json.loads((out/'numerical.json').read_text())
    paths={r['job'] for r in rows}
    result=[audit(Path(p.replace('user://',str(godot_environment_root()/'roaming/Godot/app_userdata/UniCORE')+'/'))/'model.inp') for p in paths]
    (out/'deck-audit.json').write_text(json.dumps(result,indent=2))
    print('CAD251_DECK_AUDIT_PASS',len(result))
