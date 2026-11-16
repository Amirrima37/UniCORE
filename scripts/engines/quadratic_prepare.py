"""Validate C3D10 geometry and write the existing CalculiX input format."""
import sys,json,math,base64,struct
from pathlib import Path
from quadratic_tet import element_quality,boundary_loads
def number(value):
    # CalculiX's free-format reader bounds a numeric token to 20 characters.
    # Retain the most significant digits fitting that upstream field limit.
    for digits in range(17,9,-1):
        text=format(value,f'.{digits}g')
        if len(text)<=20:return text
    raise ValueError('Numeric value cannot fit CalculiX input field')
def prepare(model):
    if model.get('schema')!=1 or model.get('units')!='SI' or model.get('analysis')!='static_structural' or model.get('element_type')!='C3D10' or model.get('node_order')!='CalculiX C3D10':raise ValueError('Expected canonical SI linear static C3D10 model')
    if 'nodes_binary64' in model:
        raw=base64.b64decode(model.pop('nodes_binary64'),validate=True)
        if len(raw)!=len(model['nodes'])*24:raise ValueError('Invalid lossless quadratic coordinate transport')
        model['nodes']=[list(p) for p in struct.iter_unpack('<ddd',raw)]
    nodes=model['nodes'];cells=model['elements']
    if not nodes or not cells or len(nodes)>200000 or len(cells)>1000000:raise ValueError('C3D10 mesh count bounds')
    for p in nodes:
        if len(p)!=3 or not all(type(x) in [int,float] and math.isfinite(x) for x in p):raise ValueError('Nonfinite C3D10 coordinate')
    minimum=math.inf
    for c in cells:
        if len(c)!=10 or len(set(c))!=10 or any(type(i) is not int or not 0<=i<len(nodes) for i in c):raise ValueError('Invalid C3D10 connectivity')
        minimum=min(minimum,element_quality([nodes[i] for i in c])['jacobian'])
    material=model['material'];E=material.get('E',0);nu=material.get('nu',-2)
    if type(E) not in [int,float] or type(nu) not in [int,float] or not math.isfinite(E) or not math.isfinite(nu) or E<=0 or not -1<nu<.5:raise ValueError('Invalid isotropic material')
    if 'quadratic_boundary' in model:
        model['loads'],model['constraints'],model['surface_load_proof']=boundary_loads(model)
    for kind in ['loads','constraints']:
        for row in model.get(kind,[]):
            if len(row)!=3 or type(row[0]) is not int or not 0<=row[0]<len(nodes) or type(row[1]) is not int or not 0<=row[1]<3 or not math.isfinite(row[2]):raise ValueError('Invalid C3D10 DOF mapping')
    lines=['*HEADING','UniCORE C3D10 SI quadratic structural','*NODE,NSET=NALL']
    lines += [str(i+1)+','+','.join(number(x) for x in p) for i,p in enumerate(nodes)]
    lines+=['*ELEMENT,TYPE=C3D10,ELSET=EALL']
    lines += [str(i+1)+','+','.join(str(j+1) for j in c) for i,c in enumerate(cells)]
    if 'materials' in model:
        owners=model['element_materials'];materials=model['materials']
        if len(owners)!=len(cells) or any(type(k) is not int or not 0<=k<len(materials) for k in owners):raise ValueError('Incomplete material ownership')
        for k,m in enumerate(materials):
            if not math.isfinite(m['E']) or m['E']<=0 or not math.isfinite(m['nu']) or not -1<m['nu']<.5:raise ValueError('Invalid assembly material')
            ids=[str(i+1) for i,v in enumerate(owners) if v==k]
            if not ids:raise ValueError('Empty material region')
            lines+=['*ELSET,ELSET=REGION'+str(k)]+ids
            lines+=['*MATERIAL,NAME=MAT'+str(k),'*ELASTIC',number(m['E'])+','+number(m['nu']),'*SOLID SECTION,ELSET=REGION'+str(k)+',MATERIAL=MAT'+str(k)]
        lines+=['*BOUNDARY']
    else:
        lines+=['*MATERIAL,NAME=ELASTIC','*ELASTIC',number(E)+','+number(nu),'*SOLID SECTION,ELSET=EALL,MATERIAL=ELASTIC','*BOUNDARY']
    lines += [f'{i+1},{k+1},{k+1},'+number(v) for i,k,v in model.get('constraints',[])]
    lines+=['*STEP','*STATIC','*CLOAD']
    lines += [f'{i+1},{k+1},'+number(v) for i,k,v in model.get('loads',[])]
    lines+=['*NODE PRINT,NSET=NALL','U,RF','*EL PRINT,ELSET=EALL','S','*NODE FILE','U','*EL FILE','S','*END STEP','']
    model['quadratic_validation']=dict(minimum_bernstein_jacobian=minimum,certificate='positive cubic Bernstein coefficients over whole reference tetrahedron')
    return model,'\n'.join(lines)
if __name__=='__main__':
    job=Path(sys.argv[1]);source=job/'request.json'
    try:
        if source.stat().st_size>128*1024*1024:raise ValueError('C3D10 request exceeds 128 MiB')
        model,deck=prepare(json.loads(source.read_text()));text=json.dumps(model,allow_nan=False,sort_keys=True)
        if len(deck.encode())>64*1024*1024 or len(text.encode())>128*1024*1024:raise ValueError('C3D10 prepared output bound')
        (job/'model.inp').write_text(deck);(job/'canonical-model.json').write_text(text)
    except Exception as e:(job/'prepare-error.txt').write_text(str(e));raise SystemExit(1)
