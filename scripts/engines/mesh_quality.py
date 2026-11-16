"""Binary64 metrics from actual TET4 coordinates; no scale-dependent shape scores."""
import math
EDGES=[(0,1),(0,2),(0,3),(1,2),(1,3),(2,3)]
def metrics(nodes,elements,cad_volume):
    qualities=[];volumes=[];ratios=[];lengths=[];determinants=[];per_element=[]
    for eid,cell in enumerate(elements):
        if len(cell)!=4 or len(set(cell))!=4 or any(type(i) is not int or not 0<=i<len(nodes) for i in cell):raise ValueError('Invalid TET4 connectivity at element '+str(eid))
        p=[nodes[i] for i in cell];a,b,c=[[p[j][i]-p[0][i] for i in range(3)] for j in [1,2,3]]
        det=sum(a[i]*(b[(i+1)%3]*c[(i+2)%3]-b[(i+2)%3]*c[(i+1)%3]) for i in range(3))
        edge=[math.dist(p[i],p[j]) for i,j in EDGES];volume=det/6
        q=12*(abs(det)/2)**(2/3)/max(sum(e*e for e in edge),1e-300);ratio=max(edge)/max(min(edge),1e-300)
        if not all(math.isfinite(v) for v in [det,q,ratio,*edge]):raise ValueError('Nonfinite mesh quality')
        determinants.append(det);qualities.append(q);volumes.append(volume);ratios.append(ratio);lengths.extend(edge)
        per_element.append(dict(id=eid,jacobian=det,volume=volume,mean_ratio=q,edge_ratio=ratio,edge_min=min(edge),edge_max=max(edge)))
    if not elements:raise ValueError('Empty TET4 mesh')
    histogram=[0]*10
    for q in qualities:histogram[min(9,max(0,int(q*10)))]+=1
    mesh_volume=math.fsum(volumes)
    return dict(minimum_jacobian=min(determinants),maximum_jacobian=max(determinants),inverted_elements=sum(v<0 for v in determinants),degenerate_elements=sum(abs(v)<=1e-12*max(e['edge_max']**3,1e-300) for v,e in zip(determinants,per_element)),minimum_volume=min(volumes),maximum_volume=max(volumes),minimum_mean_ratio=min(qualities),maximum_mean_ratio=max(qualities),mean_mean_ratio=math.fsum(qualities)/len(qualities),maximum_edge_ratio=max(ratios),edge_min=min(lengths),edge_max=max(lengths),edge_mean=math.fsum(lengths)/len(lengths),quality_histogram=histogram,histogram_range=[0,1],worst_element=min(range(len(elements)),key=qualities.__getitem__),per_element=per_element,cad_volume=cad_volume,mesh_volume=mesh_volume,absolute_volume_difference=abs(mesh_volume-cad_volume),relative_volume_difference=abs(mesh_volume/cad_volume-1),nodes=len(nodes),elements=len(elements))
