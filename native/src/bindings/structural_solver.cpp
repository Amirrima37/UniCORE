#include "structural_solver.hpp"
#include "kernels/structural_solver.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <set>
using namespace godot;
namespace s = unicore::structural;
namespace {
Dictionary error(const char *code) {Dictionary d;d["ok"]=false;d["error"]=code;return d;}
Array array(Variant v,int size=-1) {if(v.get_type()!=Variant::ARRAY)throw std::runtime_error("INVALID_ARRAY");Array a=v;if(size>=0&&a.size()!=size)throw std::runtime_error("INVALID_ARRAY_SIZE");return a;}
double number(Variant v) {if(v.get_type()!=Variant::INT&&v.get_type()!=Variant::FLOAT)throw std::runtime_error("INVALID_NUMBER");double x=v.get_type()==Variant::INT ? double(int64_t(v)) : double(v);if(!std::isfinite(x))throw std::runtime_error("NONFINITE_NUMBER");return x;}
s::V vector(Variant v) {auto a=array(v,3);return {number(a[0]),number(a[1]),number(a[2])};}
Dictionary dict(Variant v) {if(v.get_type()!=Variant::DICTIONARY)throw std::runtime_error("INVALID_DICTIONARY");return v;}
Array xyz(s::V v) {Array a;for(double x:v)a.append(x);return a;}
s::V rotate(s::V v,s::V r){
    double x=v[0]*std::cos(r[2])-v[1]*std::sin(r[2]), y=v[0]*std::sin(r[2])+v[1]*std::cos(r[2]), z=v[2];
    double yy=y*std::cos(r[0])-z*std::sin(r[0]),zz=y*std::sin(r[0])+z*std::cos(r[0]);
    return {x*std::cos(r[1])+zz*std::sin(r[1]),yy,-x*std::sin(r[1])+zz*std::cos(r[1])};
}
const char *names[]={"X-","X+","Y-","Y+","Z-","Z+"};
}
void UniCoreStructuralSolver::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_phase"),&UniCoreStructuralSolver::get_phase);
    ClassDB::bind_method(D_METHOD("get_tool_catalog"),&UniCoreStructuralSolver::get_tool_catalog);
    ClassDB::bind_method(D_METHOD("generate_mesh","project","divisions"),&UniCoreStructuralSolver::generate_mesh);
    ClassDB::bind_method(D_METHOD("solve_model","project"),&UniCoreStructuralSolver::solve_model);
    ClassDB::bind_method(D_METHOD("cancel"),&UniCoreStructuralSolver::cancel);
    ClassDB::bind_method(D_METHOD("reset_cancel"),&UniCoreStructuralSolver::reset_cancel);
}
Array UniCoreStructuralSolver::get_tool_catalog() const {
    struct Tool {const char *domain,*name,*status,*scope;};
    const Tool tools[]={
        {"Mechanical","UniCORE Solid","Available","Static linear elastic boxes; TET4; fixed faces and total face forces; SI units"},
        {"Geometry & materials","UniCORE Model","Available","Dimensioned primitives, elastic materials, C++ box volume meshing"},
        {"Particles","UniCORE Molecular","Existing physics workspace","Native molecular dynamics; not a continuum CFD solver"},
        {"Dynamics","UniCORE Gravity","Existing physics workspace","Native N-body gravity; not flexible multibody mechanics"},
        {"Quantum","UniCORE Wave","Existing physics workspace","Native quantum wavepacket study; not optical FDTD"},
        {"Nuclear","UniCORE Nuclear","Existing physics workspace","Native nuclear dynamics and decay study"},
        {"Mechanical","Impact / nonlinear / fatigue / acoustics","Not implemented","Requires dedicated formulations and verification"},
        {"Fluids","Flow / turbulence / combustion / turbomachinery","Not implemented","No continuum fluid solver is supplied"},
        {"Electronics","Electromagnetics / circuits / cooling","Not implemented","Requires electromagnetic and thermal solvers"},
        {"Semiconductors","IC power integrity / ESD","Not implemented","Requires semiconductor and network models"},
        {"Optics","Ray optics / photonics","Not implemented","Requires optical transport and device solvers"},
        {"Systems","Optimization / twins / MBSE","Not implemented","Requires workflow and reduced model infrastructure"},
        {"Platforms","CAD import / remote solve / automation","Not implemented","Current project format supports local primitive studies"}
    };
    Array result;for(const auto &tool:tools){Dictionary d;d["domain"]=tool.domain;d["name"]=tool.name;d["status"]=tool.status;d["scope"]=tool.scope;result.append(d);}return result;
}
Dictionary UniCoreStructuralSolver::generate_mesh(const Dictionary &project,int divisions) const {
    try {
        if(divisions<1||divisions>16)throw std::runtime_error("INVALID_MESH_SIZE");
        if(String(project.get("units",""))!="m-N-Pa-kg")throw std::runtime_error("INVALID_UNITS");
        auto parts=array(project.get("parts",Variant()));
        if(parts.is_empty()||parts.size()>16)throw std::runtime_error("BODY_COUNT_LIMIT_1_TO_16");
        if(parts.size()*(divisions+1)*(divisions+1)*(divisions+1)>10000)throw std::runtime_error("MESH_NODE_LIMIT_10000");
        Array nodes,elements,material_regions;Dictionary regions;int n=divisions+1; double minimum_jacobian=1e300,maximum_aspect=1,total_volume=0;
        for(int pi=0;pi<parts.size();++pi) {
            auto p=dict(parts[pi]);if(String(p.get("kind",""))!="Box")throw std::runtime_error("UNSUPPORTED_GEOMETRY");
            auto d=vector(p.get("dimensions",Variant())),position=vector(p.get("position",Variant()));
            s::V rotation{},scale{1,1,1};if(p.has("rotation"))rotation=vector(p["rotation"]);if(p.has("scale"))scale=vector(p["scale"]);
            for(double x:scale)if(x<=0)throw std::runtime_error("INVALID_PHYSICAL_SCALE");
            for(int j=0;j<3;++j)d[j]*=scale[j];
            double det=d[0]*d[1]*d[2]/(8.0*divisions*divisions*divisions);
            if(!std::isfinite(det)||det<=1e-24)throw std::runtime_error("DEGENERATE_MESH");
            minimum_jacobian=std::min(minimum_jacobian,det);total_volume+=d[0]*d[1]*d[2];
            maximum_aspect=std::max(maximum_aspect,*std::max_element(d.begin(),d.end())/ *std::min_element(d.begin(),d.end()));
            for(double x:d)if(x<=0)throw std::runtime_error("INVALID_DIMENSIONS");
            String id=p.get("id","");if(id.is_empty()||regions.has(id))throw std::runtime_error("INVALID_BODY_ID");
            int offset=nodes.size();Array faces[6];
            for(int k=0;k<n;++k)for(int j=0;j<n;++j)for(int i=0;i<n;++i) {
                int index=nodes.size();auto v=rotate({(double(i)/divisions-.5)*d[0],(double(j)/divisions-.5)*d[1],(double(k)/divisions-.5)*d[2]},rotation);for(int c=0;c<3;++c)v[c]+=position[c];nodes.append(xyz(v));
                if(i==0)faces[0].append(index);if(i==divisions)faces[1].append(index);
                if(j==0)faces[2].append(index);if(j==divisions)faces[3].append(index);
                if(k==0)faces[4].append(index);if(k==divisions)faces[5].append(index);
            }
            for(int k=0;k<divisions;++k)for(int j=0;j<divisions;++j)for(int i=0;i<divisions;++i) {
                int a=offset+i+n*j+n*n*k;Array e;for(int v:{a,a+1,a+n+1,a+n,a+n*n,a+n*n+1,a+n*n+n+1,a+n*n+n})e.append(v);elements.append(e);material_regions.append(id);
            }
            Dictionary f;for(int j=0;j<6;++j)f[names[j]]=faces[j];regions[id]=f;
        }
        Dictionary mesh;mesh["nodes"]=nodes;mesh["elements"]=elements;mesh["regions"]=regions;mesh["revision"]=project.get("revision",0);mesh["formulation"]="HEX8";mesh["divisions"]=divisions;
        Dictionary quality;quality["minimum_jacobian"]=minimum_jacobian;quality["maximum_aspect_ratio"]=maximum_aspect;quality["inverted_elements"]=0;quality["degenerate_elements"]=0;quality["connected_components"]=parts.size();quality["total_volume"]=total_volume;
        Array warnings;if(maximum_aspect>10)warnings.append("HIGH_ASPECT_RATIO");if(parts.size()>1)warnings.append("BODIES_ARE_DISCONNECTED_NO_CONTACT_OR_BONDING");quality["warnings"]=warnings;
        mesh["quality"]=quality;mesh["material_regions"]=material_regions;mesh["boundary_coordinates"]="local parametric faces, global nodes";
        Dictionary result;result["ok"]=true;result["mesh"]=mesh;return result;
    }catch(const std::exception &e){return error(e.what());}
}
Dictionary UniCoreStructuralSolver::solve_model(const Dictionary &project) {
    phase.store(1);
    try {
        auto old_mesh=dict(project.get("mesh",Variant()));
        // Rebuild connectivity from authoritative geometry, not untrusted saved arrays.
        int divisions=int(number(old_mesh.get("divisions",0)));
        auto generated=generate_mesh(project,divisions);
        if(!bool(generated.get("ok",false)))return generated;
        auto mesh=dict(generated["mesh"]);auto nodes=array(mesh["nodes"]),hexes=array(mesh["elements"]);auto parts=array(project["parts"]);
        Dictionary analysis=project.get("analysis",Dictionary());String formulation=analysis.get("element","TET4");
        if(String(analysis.get("type","static_structural"))!="static_structural")throw std::runtime_error("UNSUPPORTED_STRUCTURAL_ANALYSIS");
        if(formulation!="TET4"&&formulation!="HEX8")throw std::runtime_error("UNSUPPORTED_ELEMENT");bool use_hex=formulation=="HEX8";
        s::Model m;for(int i=0;i<nodes.size();++i)m.nodes.push_back(vector(nodes[i]));
        m.force.resize(nodes.size()*3,0);m.fixed.resize(nodes.size()*3,false);m.prescribed.resize(nodes.size()*3,0);
        const int split[6][4]={{0,1,2,6},{0,2,3,6},{0,3,7,6},{0,7,4,6},{0,4,5,6},{0,5,1,6}};
        int cells=divisions*divisions*divisions;
        Array tetrahedra,result_elements;
        auto regions=dict(mesh["regions"]);
        for(int pi=0;pi<parts.size();++pi) {
            auto p=dict(parts[pi]),material=dict(p.get("material",Variant()));
            s::Material mat{number(material.get("E",Variant())),number(material.get("nu",Variant()))};
            if(String(material.get("model","isotropic_linear_elastic"))!="isotropic_linear_elastic")throw std::runtime_error("UNSUPPORTED_CONSTITUTIVE_MODEL");
            auto faces=dict(regions[p["id"]]);String support=p.get("support",""),loaded=p.get("load_face","");
            if(support.is_empty()&&!p.has("prescribed"))throw std::runtime_error("EACH_DISCONNECTED_BODY_REQUIRES_SUPPORT");
            if(!support.is_empty()&&!faces.has(support))throw std::runtime_error("INVALID_SUPPORT_FACE");
            Array fixed=support.is_empty()?Array():array(faces[support]);
            for(int i=0;i<fixed.size();++i)for(int c=0;c<3;++c)m.fixed[int(fixed[i])*3+c]=true;
            if(p.has("prescribed")){
                auto bc=dict(p["prescribed"]);String face=bc.get("face","");if(!faces.has(face))throw std::runtime_error("INVALID_DISPLACEMENT_FACE");
                auto ids=array(faces[face]);auto values=vector(bc.get("values",Variant()));
                for(int i=0;i<ids.size();++i)for(int c=0;c<3;++c){int dof=int(ids[i])*3+c;if(m.fixed[dof]&&std::abs(m.prescribed[dof]-values[c])>1e-14)throw std::runtime_error("CONFLICTING_DISPLACEMENTS");m.fixed[dof]=true;m.prescribed[dof]=values[c];}
            }
            auto apply_surface=[&](String face,s::V force,double pressure,bool is_pressure){
                if(!faces.has(face))throw std::runtime_error("INVALID_LOAD_FACE");
                auto load=array(faces[face]);std::set<int> ids;for(int i=0;i<load.size();++i)ids.insert(int(load[i]));
                const int face_nodes[6][4]={{0,3,7,4},{1,5,6,2},{0,4,5,1},{3,2,6,7},{0,1,2,3},{4,7,6,5}};
                struct Triangle{int ids[3];int quad[4];double area;s::V normal;};std::vector<Triangle> triangles;double total=0;
                auto center=vector(p["position"]);
                for(int h=pi*cells;h<(pi+1)*cells;++h){auto hex=array(hexes[h],8);for(auto& f:face_nodes){bool boundary=true;for(int j:f)if(!ids.count(int(hex[j])))boundary=false;if(!boundary)continue;
                    for(int half=0;half<2;++half){int local[3]={f[0],f[half+1],f[half+2]};Triangle tri{};for(int j=0;j<4;++j)tri.quad[j]=int(hex[f[j]]);for(int j=0;j<3;++j)tri.ids[j]=int(hex[local[j]]);
                        auto normal=s::cross(s::sub(m.nodes[tri.ids[1]],m.nodes[tri.ids[0]]),s::sub(m.nodes[tri.ids[2]],m.nodes[tri.ids[0]]));double length=std::sqrt(s::dot(normal,normal));if(length<=0)throw std::runtime_error("INVALID_LOAD_AREA");
                        tri.area=length/2;for(int j=0;j<3;++j)tri.normal[j]=normal[j]/length;
                        if(s::dot(tri.normal,s::sub(m.nodes[tri.ids[0]],center))<0)for(double &x:tri.normal)x=-x;
                        total+=tri.area;triangles.push_back(tri);
                    }
                }}
                if(total<=0)throw std::runtime_error("INVALID_LOAD_AREA");
                for(auto &tri:triangles){if(use_hex){for(int id:tri.quad)for(int c=0;c<3;++c)m.force[id*3+c]+=(is_pressure?-pressure*tri.normal[c]:force[c]/total)*tri.area/4;}else{for(int id:tri.ids)for(int c=0;c<3;++c)m.force[id*3+c]+=(is_pressure?-pressure*tri.normal[c]:force[c]/total)*tri.area/3;}}
            };
            if(!loaded.is_empty())apply_surface(loaded,vector(p.get("force",Variant())),0,false);
            if(p.has("pressure")){auto bc=dict(p["pressure"]);apply_surface(bc.get("face",""),{0,0,0},number(bc.get("value",Variant())),true);}
            s::V gravity{};double density=0;if(p.has("gravity")){gravity=vector(p["gravity"]);density=number(material.get("density",Variant()));if(density<=0)throw std::runtime_error("INVALID_DENSITY");}
            for(int h=pi*cells;h<(pi+1)*cells;++h){
                auto hex=array(hexes[h],8);
                s::Hex hexa;hexa.material=mat;for(int j=0;j<8;++j)hexa.nodes[j]=int(hex[j]);
                if(use_hex){m.hexes.push_back(hexa);result_elements.append(hex);}
                for(auto &local:split){s::Tet t;t.material=mat;Array indices;for(int j=0;j<4;++j){t.nodes[j]=int(hex[local[j]]);indices.append(t.nodes[j]);}tetrahedra.append(indices);if(!use_hex){m.elements.push_back(t);result_elements.append(indices);}}
                if(density>0){s::Cell cell{{hexa.nodes.begin(),hexa.nodes.end()},mat};double volume=s::integrate(m,cell).volume;for(int id:hexa.nodes)for(int c=0;c<3;++c)m.force[id*3+c]+=density*volume*gravity[c]/8;}
            }
        }
        auto solution=s::solve(m,cancelled,&phase);Array displacement,reactions,stress,strain,vm,principal;
        double maximum=0;
        for(size_t i=0;i<m.nodes.size();++i) {
            s::V u{},r{};for(int j=0;j<3;++j){u[j]=solution.displacement[3*i+j];r[j]=solution.reaction[3*i+j];}
            maximum=std::max(maximum,std::sqrt(s::dot(u,u)));displacement.append(xyz(u));reactions.append(xyz(r));
        }
        for(auto &field:solution.fields) {Array a,b;for(double v:field.stress)a.append(v);for(double v:field.strain)b.append(v);stress.append(a);strain.append(b);vm.append(field.von_mises);Array eigen;for(double x:s::principal_stresses(field.stress))eigen.append(x);principal.append(eigen);}
        Dictionary result;result["ok"]=true;result["revision"]=project.get("revision",0);result["backend"]=use_hex?"C++ HEX8 full 2x2x2 / isotropic elasticity / Jacobi PCG":"C++ TET4 / isotropic elasticity / Jacobi PCG";result["element_type"]=formulation;result["elements"]=result_elements;result["mesh_quality"]=mesh["quality"];result["stress_location"]=use_hex?"element center, unaveraged":"element constant, unaveraged";
        result["nodes"]=nodes;result["tetrahedra"]=tetrahedra;result["displacement"]=displacement;result["reactions"]=reactions;
        result["principal_stress"]=principal;result["stress"]=stress;result["strain"]=strain;result["von_mises"]=vm;result["max_displacement"]=maximum;
        result["relative_residual"]=solution.residual;result["iterations"]=solution.iterations;result["mesh_divisions"]=divisions;phase.store(6);return result;
    }catch(const std::exception &e){return error(e.what());}
}

