"""C3D10 isoparametric geometry and consistent TRI6 Cartesian traction.

Canonical order follows CalculiX, not Gmsh. Cubic Bernstein bounds certify the
Jacobian sign over the entire reference tetrahedron, beyond sampled Gauss tests.
"""
import math,itertools
GMSH_TO_CCX=[0,1,2,3,4,5,6,7,9,8]
EDGES=[(0,1),(1,2),(2,0),(0,3),(1,3),(2,3)]
FACES=[[0,2,1,6,5,4],[0,1,3,4,8,7],[1,2,3,5,9,8],[2,0,3,6,7,9]]
A=.5854101966249685;B=.1381966011250105
GAUSS4=[(B,B,B),(A,B,B),(B,A,B),(B,B,A)]
def shape(l):return [x*(2*x-1) for x in l]+[4*l[a]*l[b] for a,b in EDGES]
def derivatives(l):
    dl=[(-1,-1,-1),(1,0,0),(0,1,0),(0,0,1)]
    return [[(4*l[i]-1)*v for v in dl[i]] for i in range(4)]+[[4*(dl[a][j]*l[b]+l[a]*dl[b][j]) for j in range(3)] for a,b in EDGES]
def det(a,b,c):return sum(a[i]*(b[(i+1)%3]*c[(i+2)%3]-b[(i+2)%3]*c[(i+1)%3]) for i in range(3))
def jacobian(points,l):
    d=derivatives(l)
    # Translation removed to avoid cancellation for distant CAD coordinates.
    columns=[[sum((p[k]-points[0][k])*g[j] for p,g in zip(points,d)) for k in range(3)] for j in range(3)]
    return det(*columns)
INDICES=[(i,j,k,3-i-j-k) for i in range(4) for j in range(4-i) for k in range(4-i-j)]
LATTICE=[tuple(x/3 for x in index) for index in INDICES]
def bernstein(l,index):return 6/math.prod(math.factorial(i) for i in index)*math.prod(x**i for x,i in zip(l,index))
def inverse(matrix):
    n=len(matrix);a=[list(row)+[float(i==j) for j in range(n)] for i,row in enumerate(matrix)]
    for col in range(n):
        pivot=max(range(col,n),key=lambda i:abs(a[i][col]));a[col],a[pivot]=a[pivot],a[col]
        scale=a[col][col];a[col]=[x/scale for x in a[col]]
        for i in range(n):
            if i!=col:
                factor=a[i][col];a[i]=[x-factor*y for x,y in zip(a[i],a[col])]
    return [row[n:] for row in a]
BERNSTEIN_INVERSE=inverse([[bernstein(l,i) for i in INDICES] for l in LATTICE])
def element_quality(points):
    samples=[jacobian(points,l) for l in LATTICE]
    coefficients=[sum(a*b for a,b in zip(row,samples)) for row in BERNSTEIN_INVERSE]
    lo=min(coefficients);hi=max(coefficients)
    lengths=[math.dist(points[a],points[b]) for a,b in EDGES]
    tolerance=max(lengths)**3*1e-12
    if not all(math.isfinite(x) for x in coefficients) or lo<=tolerance:raise ValueError('C3D10 Jacobian cannot be certified positive over the reference element; refine curved boundaries')
    corner=det(*[[points[i][j]-points[0][j] for j in range(3)] for i in [1,2,3]])
    corner_ratio=12*(abs(corner)/2)**(2/3)/sum(x*x for x in lengths)
    gauss=[jacobian(points,[1-sum(x),*x]) for x in GAUSS4]
    # Degree-three rule, exact for the cubic TET10 Jacobian determinant.
    volume=(-.8*jacobian(points,[.25]*4)+.45*sum(jacobian(points,l) for l in [(0.5,1/6,1/6,1/6),(1/6,.5,1/6,1/6),(1/6,1/6,.5,1/6),(1/6,1/6,1/6,.5)]))/6
    return dict(jacobian=lo,jacobian_max=hi,gauss_jacobian_min=min(gauss),gauss_jacobian_max=max(gauss),volume=volume,corner_mean_ratio=corner_ratio,mean_ratio=corner_ratio,quadratic_quality=corner_ratio*lo/hi,edge_ratio=max(lengths)/min(lengths),edge_min=min(lengths),edge_max=max(lengths),positive_bernstein_certificate=True)
def mesh_quality(nodes,cells,cad_volume):
    from mesh_quality import metrics
    base=metrics(nodes,[c[:4] for c in cells],cad_volume);per=[]
    for eid,c in enumerate(cells):
        if len(c)!=10 or len(set(c))!=10 or any(type(i) is not int or not 0<=i<len(nodes) for i in c):raise ValueError('Invalid/mixed C3D10 connectivity')
        q=element_quality([nodes[i] for i in c]);q['id']=eid;per.append(q)
    values=[q['quadratic_quality'] for q in per];hist=[0]*10
    for q in values:hist[min(9,max(0,int(q*10)))]+=1
    volume=math.fsum(q['volume'] for q in per)
    base.update(per_element=per,minimum_jacobian=min(q['jacobian'] for q in per),maximum_jacobian=max(q['jacobian_max'] for q in per),minimum_volume=min(q['volume'] for q in per),maximum_volume=max(q['volume'] for q in per),mesh_volume=volume,absolute_volume_difference=abs(volume-cad_volume),relative_volume_difference=abs(volume/cad_volume-1),minimum_quadratic_quality=min(values),quality_histogram=hist,worst_element=values.index(min(values)),quality_metric='quadratic_quality = corner mean ratio * Bernstein detJ lower/upper bound',jacobian_validation='degree-3 Bernstein global positive certificate + 4 CalculiX integration points',volume_integration='degree-3 exact 5-point tetrahedron rule')
    base.update(gauss_jacobian_min=min(q['gauss_jacobian_min'] for q in per),gauss_jacobian_max=max(q['gauss_jacobian_max'] for q in per))
    return base
def subtri(face):
    a,b,c,ab,bc,ca=face
    return [[a,ab,ca],[ab,b,bc],[ca,bc,c],[ab,bc,ca]]
def exterior(cells):
    faces={}
    for eid,c in enumerate(cells):
        for side,local in enumerate(FACES,1):
            f=[c[i] for i in local];key=tuple(sorted(f[:3]))
            if key in faces:
                old=faces[key]
                if old is None or set(old['nodes'])!=set(f):raise ValueError('Nonconforming quadratic interior face')
                faces[key]=None
            else:faces[key]=dict(element=eid,side=side,nodes=f)
    return {tuple(sorted(f['nodes'])):f for f in faces.values() if f is not None}
# Positive seven-point degree-five triangle rule, weights sum to 1/2.
TRI_RULE=[((1/3,1/3,1/3),.225/2)]
for x,y,w in [(.059715871789770,.470142064105115,.132394152788506/2),(.797426985353087,.101286507323456,.125939180544827/2)]:
    for l in [(x,y,y),(y,x,y),(y,y,x)]:TRI_RULE.append((l,w))
def face_rule(points,triangle):
    dl=[(-1,-1),(1,0),(0,1)];weights=[0.]*6;area=0.;first=[0.]*3
    a,b,c=triangle
    factor=abs((b[1]-a[1])*(c[2]-a[2])-(b[2]-a[2])*(c[1]-a[1]))
    for local,w in TRI_RULE:
        l=[sum(local[i]*triangle[i][j] for i in range(3)) for j in range(3)]
        n=[v*(2*v-1) for v in l]+[4*l[a]*l[b] for a,b in [(0,1),(1,2),(2,0)]]
        d=[[(4*l[i]-1)*v for v in dl[i]] for i in range(3)]+[[4*(dl[a][j]*l[b]+l[a]*dl[b][j]) for j in range(2)] for a,b in [(0,1),(1,2),(2,0)]]
        a,b=[[sum((p[k]-points[0][k])*g[j] for p,g in zip(points,d)) for k in range(3)] for j in range(2)]
        cross=[a[(i+1)%3]*b[(i+2)%3]-a[(i+2)%3]*b[(i+1)%3] for i in range(3)];ds=math.sqrt(sum(x*x for x in cross))*w*factor
        if ds<=0 or not math.isfinite(ds):raise ValueError('Invalid quadratic boundary area')
        area+=ds
        for i in range(6):weights[i]+=n[i]*ds
        for k in range(3):first[k]+=sum(n[i]*points[i][k] for i in range(6))*ds
    return weights,area,first

def face_integrals(points):
    # Curved area norm is not polynomial: bounded adaptive refinement of the
    # degree-five rule, rather than claiming exact curved traction integration.
    def integrate(triangle,depth=0):
        a,b,c=triangle;ab=[(x+y)/2 for x,y in zip(a,b)];bc=[(x+y)/2 for x,y in zip(b,c)];ca=[(x+y)/2 for x,y in zip(c,a)]
        children=[(a,ab,ca),(ab,b,bc),(ca,bc,c),(ab,bc,ca)]
        coarse=face_rule(points,triangle);fine=[face_rule(points,t) for t in children]
        combined=([math.fsum(q[0][i] for q in fine) for i in range(6)],math.fsum(q[1] for q in fine),[math.fsum(q[2][k] for q in fine) for k in range(3)])
        scale=max(1.,max(abs(x) for p in points for x in p));tolerance=coarse[1]*1e-10
        if max(abs(a-b) for a,b in zip(coarse[0],combined[0]))<=tolerance and abs(coarse[1]-combined[1])<=tolerance and max(abs(a-b) for a,b in zip(coarse[2],combined[2]))<=tolerance*scale:return combined
        if depth>=4:raise ValueError('Quadratic curved traction integration did not converge; refine the loaded CAD face')
        fine=[integrate(t,depth+1) for t in children]
        return ([math.fsum(q[0][i] for q in fine) for i in range(6)],math.fsum(q[1] for q in fine),[math.fsum(q[2][k] for q in fine) for k in range(3)])
    return integrate([(1.,0.,0.),(0.,1.,0.),(0.,0.,1.)])
def boundary_loads(model):
    spec=model['quadratic_boundary'];nodes=model['nodes'];cells=model['elements'];outside=exterior(cells);faces=spec['faces'];groups=spec['groups']
    def node_id(value):
        if type(value) not in [int,float] or not math.isfinite(value) or value!=int(value) or not 0<=value<len(nodes):raise ValueError('Invalid quadratic boundary node ID')
        return int(value)
    faces={name:[[node_id(i) for i in f] for f in triangles] for name,triangles in faces.items()}
    groups={name:[node_id(i) for i in ids] for name,ids in groups.items()}
    all_faces=[tuple(sorted(f)) for triangles in faces.values() for f in triangles]
    if set(faces)!=set(groups) or len(all_faces)!=len(set(all_faces)) or set(all_faces)!=set(outside):raise ValueError('Quadratic physical groups do not partition the complete exterior')
    for name,triangles in faces.items():
        actual={i for f in triangles for i in f}
        if actual!=set(groups[name]):raise ValueError('Missing midside nodes in physical face group')
        for f in triangles:
            if len(f)!=6 or tuple(sorted(f)) not in outside:raise ValueError('Nonexterior/unmapped quadratic face')
            if f!=outside[tuple(sorted(f))]['nodes']:raise ValueError('Quadratic face node order/orientation does not match the C3D10 element face')
    selected=faces[spec['load_face']];weights={};area=0.;first=[0.]*3;seen=set();mapping=[]
    for f in selected:
        key=tuple(sorted(f))
        if key in seen:raise ValueError('Duplicate quadratic loaded face')
        seen.add(key);entry=outside[key];mapping.append(dict(element=entry['element'],ccx_face=entry['side'],nodes=f))
        w,a,m=face_integrals([nodes[i] for i in f]);area+=a
        for i,value in zip(f,w):weights[i]=weights.get(i,0)+value
        for k in range(3):first[k]+=m[k]
    if area<=0:raise ValueError('Zero loaded quadratic area')
    force=spec['force']
    if len(force)!=3 or not all(type(x) in [int,float] and math.isfinite(x) for x in force):raise ValueError('Nonfinite quadratic surface force')
    loads=[[i,k,weight*force[k]/area] for i,weight in sorted(weights.items()) for k in range(3) if force[k]!=0 and abs(weight)>area*1e-15]
    total=[math.fsum(row[2] for row in loads if row[1]==k) for k in range(3)];moment=[0.]*3
    for i,k,value in loads:
        f=[0.]*3;f[k]=value;p=nodes[i]
        for j in range(3):moment[j]+=p[(j+1)%3]*f[(j+2)%3]-p[(j+2)%3]*f[(j+1)%3]
    expected=[(first[(j+1)%3]*force[(j+2)%3]-first[(j+2)%3]*force[(j+1)%3])/area for j in range(3)]
    if max(abs(a-b) for a,b in zip(total,force))>max(1e-9,max(abs(x) for x in force)*1e-10) or max(abs(a-b) for a,b in zip(moment,expected))>max(1e-8,max(abs(x) for x in expected)*1e-10):raise ValueError('Quadratic surface force/moment integration failed')
    constraints=[[i,k,0.] for i in sorted(set(groups[spec['support']])) for k in range(3)]
    return loads,constraints,dict(area=area,resultant=total,moment=moment,expected_moment=expected,element_faces=mapping,rule='adaptive 7-point degree-5 TRI6 Cartesian traction; 1e-10 relative rule refinement tolerance, depth <=4; force/area on actual quadratic face')
