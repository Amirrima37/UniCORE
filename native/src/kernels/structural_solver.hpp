#pragma once
#include <array>
#include <chrono>
#include <vector>
#include <unordered_map>
#include <cmath>
#include <atomic>
#include <stdexcept>
#include <algorithm>
#include "math/sparse_pcg.hpp"
#include "math/parallel_for.hpp"
#include "math/nodal_scatter.hpp"
namespace unicore::structural {
using V = std::array<double,3>;
struct Material { double E, nu; };
struct Tet { std::array<int,4> nodes; Material material; };
struct Hex { std::array<int,8> nodes; Material material; };
struct Model { std::vector<V> nodes; std::vector<Tet> elements; std::vector<Hex> hexes; std::vector<double> prescribed; std::vector<double> force; std::vector<bool> fixed; };
struct Field { std::array<double,6> strain{}, stress{}; double von_mises=0; };
struct Result { math::LinearResult linear_diagnostics; double element_preparation_ms=0,pattern_container_ms=0,preconditioner_ms=0,pcg_ms=0,linear_post_ms=0,integration_ms=0,scatter_ms=0,csr_ms=0,constraint_ms=0;double assembly_ms=0,solve_ms=0,post_ms=0;std::vector<double> displacement, reaction; std::vector<Field> fields; double residual=0; int iterations=0; };
inline V sub(V a,V b) { return {a[0]-b[0],a[1]-b[1],a[2]-b[2]}; }
inline V cross(V a,V b) { return {a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]}; }
inline double dot(V a,V b) {return a[0]*b[0]+a[1]*b[1]+a[2]*b[2];}
struct Element { double B[6][12]{}, D[6][6]{}, K[12][12]{}, volume; };
inline Element element(const Model &m,const Tet &t) {
    Element e{};
    const double E=t.material.E, nu=t.material.nu;
    if (!std::isfinite(E)||E<=0||!std::isfinite(nu)||nu<=-1||nu>=0.5) throw std::runtime_error("INVALID_MATERIAL");
    for(int id:t.nodes) if(id<0||size_t(id)>=m.nodes.size()) throw std::runtime_error("INVALID_CONNECTIVITY");
    V a=sub(m.nodes[t.nodes[1]],m.nodes[t.nodes[0]]), b=sub(m.nodes[t.nodes[2]],m.nodes[t.nodes[0]]), c=sub(m.nodes[t.nodes[3]],m.nodes[t.nodes[0]]);
    double determinant=dot(a,cross(b,c));
    if(!std::isfinite(determinant)||determinant<=1e-24) throw std::runtime_error("DEGENERATE_ELEMENT");
    e.volume=std::abs(determinant)/6;
    V g[4]{}; g[1]=cross(b,c); g[2]=cross(c,a); g[3]=cross(a,b);
    for(int j=0;j<3;++j) {for(int i=1;i<4;++i) g[i][j]/=determinant; g[0][j]=-g[1][j]-g[2][j]-g[3][j];}
    for(int i=0;i<4;++i) {
        int k=3*i; double x=g[i][0],y=g[i][1],z=g[i][2];
        e.B[0][k]=x; e.B[1][k+1]=y; e.B[2][k+2]=z;
        e.B[3][k]=y; e.B[3][k+1]=x; e.B[4][k+1]=z; e.B[4][k+2]=y; e.B[5][k]=z; e.B[5][k+2]=x;
    }
    double mu=E/(2*(1+nu)), lambda=E*nu/((1+nu)*(1-2*nu));
    for(int i=0;i<3;++i) for(int j=0;j<3;++j) e.D[i][j]=lambda+(i==j?2*mu:0);
    for(int i=3;i<6;++i) e.D[i][i]=mu;
    double DB[6][12]{};
    for(int i=0;i<6;++i) for(int j=0;j<12;++j) for(int k=0;k<6;++k) DB[i][j]+=e.D[i][k]*e.B[k][j];
    for(int i=0;i<12;++i) for(int j=0;j<12;++j) for(int k=0;k<6;++k) e.K[i][j]+=e.B[k][i]*DB[k][j]*e.volume;
    return e;
}
// Shared cell integration; engineering shear order xx, yy, zz, xy, yz, xz.
struct Cell { std::vector<int> nodes; Material material; };
struct Local { int n; std::vector<double> K, B; double D[6][6]{}, volume=0, min_jacobian=1e300, max_aspect=1; };
inline Local integrate(const Model &m,const Cell &cell) {
    int count=int(cell.nodes.size()), n=count*3; Local out;out.n=n;out.K.resize(n*n);out.B.resize(6*n);
    if(count==4) {
        Tet t{{cell.nodes[0],cell.nodes[1],cell.nodes[2],cell.nodes[3]},cell.material};auto e=element(m,t);
        out.volume=e.volume;out.min_jacobian=e.volume*6;
        for(int i=0;i<12;++i)for(int j=0;j<12;++j)out.K[i*12+j]=e.K[i][j];
        for(int i=0;i<6;++i){for(int j=0;j<12;++j)out.B[i*12+j]=e.B[i][j];for(int j=0;j<6;++j)out.D[i][j]=e.D[i][j];}
        return out;
    }
    if(count!=8)throw std::runtime_error("UNSUPPORTED_ELEMENT");
    double E=cell.material.E,nu=cell.material.nu;
    if(!std::isfinite(E)||E<=0||!std::isfinite(nu)||nu<=-1||nu>=.5)throw std::runtime_error("INVALID_MATERIAL");
    double mu=E/(2*(1+nu)),lambda=E*nu/((1+nu)*(1-2*nu));
    for(int i=0;i<3;++i)for(int j=0;j<3;++j)out.D[i][j]=lambda+(i==j?2*mu:0);
    for(int i=3;i<6;++i)out.D[i][i]=mu;
    const int sign[8][3]={{-1,-1,-1},{1,-1,-1},{1,1,-1},{-1,1,-1},{-1,-1,1},{1,-1,1},{1,1,1},{-1,1,1}};
    auto point=[&](double x,double y,double z,bool stiffness){
        V gradients[8]; V columns[3]{};
        for(int a=0;a<8;++a){
            int id=cell.nodes[a];if(id<0||size_t(id)>=m.nodes.size())throw std::runtime_error("INVALID_CONNECTIVITY");
            V d{sign[a][0]*(1+sign[a][1]*y)*(1+sign[a][2]*z)/8.0,sign[a][1]*(1+sign[a][0]*x)*(1+sign[a][2]*z)/8.0,sign[a][2]*(1+sign[a][0]*x)*(1+sign[a][1]*y)/8.0};
            gradients[a]=d;for(int j=0;j<3;++j)for(int k=0;k<3;++k)columns[j][k]+=m.nodes[id][k]*d[j];
        }
        double det=dot(columns[0],cross(columns[1],columns[2]));
        if(!std::isfinite(det)||det<=1e-24)throw std::runtime_error("INVERTED_OR_DEGENERATE_HEX");
        V inverse[3]={cross(columns[1],columns[2]),cross(columns[2],columns[0]),cross(columns[0],columns[1])};
        std::vector<double>B(6*n,0);
        for(int a=0;a<8;++a){V g{};for(int j=0;j<3;++j)for(int k=0;k<3;++k)g[k]+=gradients[a][j]*inverse[j][k]/det;
            int k=3*a;B[k]=g[0];B[n+k+1]=g[1];B[2*n+k+2]=g[2];B[3*n+k]=g[1];B[3*n+k+1]=g[0];B[4*n+k+1]=g[2];B[4*n+k+2]=g[1];B[5*n+k]=g[2];B[5*n+k+2]=g[0];}
        if(!stiffness){out.B=B;return;}
        out.volume+=det;out.min_jacobian=std::min(out.min_jacobian,det);
        double lengths[3];for(int j=0;j<3;++j)lengths[j]=std::sqrt(dot(columns[j],columns[j]));
        out.max_aspect=std::max(out.max_aspect,*std::max_element(lengths,lengths+3)/ *std::min_element(lengths,lengths+3));
        std::vector<double>DB(6*n,0);for(int i=0;i<6;++i)for(int j=0;j<n;++j)for(int k=0;k<6;++k)DB[i*n+j]+=out.D[i][k]*B[k*n+j];
        for(int i=0;i<n;++i)for(int j=0;j<n;++j)for(int k=0;k<6;++k)out.K[i*n+j]+=B[k*n+i]*DB[k*n+j]*det;
    };
    double q=1/std::sqrt(3.0);for(int i:{-1,1})for(int j:{-1,1})for(int k:{-1,1})point(i*q,j*q,k*q,true);
    point(0,0,0,false);return out;
}
inline std::vector<Cell> cells_of(const Model &m){std::vector<Cell> cells;for(auto&t:m.elements)cells.push_back({{t.nodes.begin(),t.nodes.end()},t.material});for(auto&h:m.hexes)cells.push_back({{h.nodes.begin(),h.nodes.end()},h.material});return cells;}
inline std::array<double,3> principal_stresses(const std::array<double,6>&s){
    double a[3][3]={{s[0],s[3],s[5]},{s[3],s[1],s[4]},{s[5],s[4],s[2]}};
    for(int it=0;it<32;++it){int p=0,q=1;for(int i=0;i<3;++i)for(int j=i+1;j<3;++j)if(std::abs(a[i][j])>std::abs(a[p][q])){p=i;q=j;}
        if(std::abs(a[p][q])<1e-13*std::max({1.0,std::abs(a[0][0]),std::abs(a[1][1]),std::abs(a[2][2])}))break;
        double angle=.5*std::atan2(2*a[p][q],a[q][q]-a[p][p]),c=std::cos(angle),ss=std::sin(angle);
        double pp=c*c*a[p][p]-2*ss*c*a[p][q]+ss*ss*a[q][q],qq=ss*ss*a[p][p]+2*ss*c*a[p][q]+c*c*a[q][q];
        for(int k=0;k<3;++k)if(k!=p&&k!=q){double x=c*a[k][p]-ss*a[k][q],y=ss*a[k][p]+c*a[k][q];a[k][p]=a[p][k]=x;a[k][q]=a[q][k]=y;}
        a[p][p]=pp;a[q][q]=qq;a[p][q]=a[q][p]=0;
    }
    std::array<double,3>result{a[0][0],a[1][1],a[2][2]};std::sort(result.begin(),result.end(),std::greater<double>());return result;
}
inline void validate_rigid_modes(const Model&m,const std::vector<Cell>&cells){
    std::vector<int>parent(m.nodes.size());for(size_t i=0;i<parent.size();++i)parent[i]=int(i);
    auto root=[&](int i){while(parent[i]!=i){parent[i]=parent[parent[i]];i=parent[i];}return i;};
    for(auto&cell:cells){for(int id:cell.nodes)if(id<0||size_t(id)>=parent.size())throw std::runtime_error("INVALID_CONNECTIVITY");for(int id:cell.nodes)parent[root(id)]=root(cell.nodes[0]);}
    std::unordered_map<int,std::vector<int>>groups;for(size_t i=0;i<parent.size();++i)groups[root(int(i))].push_back(int(i));
    for(auto&group:groups){V center{};for(int id:group.second)for(int j=0;j<3;++j)center[j]+=m.nodes[id][j]/group.second.size();double length=0;for(int id:group.second){auto r=sub(m.nodes[id],center);length=std::max(length,std::sqrt(dot(r,r)));}if(length<=0)throw std::runtime_error("DEGENERATE_COMPONENT");
        std::vector<std::array<double,6>>rows;for(int id:group.second){V r=sub(m.nodes[id],center);for(double&x:r)x/=length;for(int c=0;c<3;++c)if(m.fixed[3*id+c]){std::array<double,6>row{};row[c]=1;V axis{};for(int j=0;j<3;++j){axis={0,0,0};axis[j]=1;row[j+3]=cross(axis,r)[c];}rows.push_back(row);}}
        int rank=0;for(int col=0;col<6;++col){int best=rank;for(int i=rank;i<int(rows.size());++i)if(std::abs(rows[i][col])>std::abs(rows[best][col]))best=i;if(rank>=int(rows.size())||std::abs(rows[best][col])<1e-10)continue;std::swap(rows[rank],rows[best]);double pivot=rows[rank][col];for(int j=col;j<6;++j)rows[rank][j]/=pivot;for(int i=0;i<int(rows.size());++i)if(i!=rank){double factor=rows[i][col];for(int j=col;j<6;++j)rows[i][j]-=factor*rows[rank][j];}++rank;}
        if(rank<6)throw std::runtime_error("UNDERCONSTRAINED_RIGID_BODY_MODES");
    }
}
inline Result solve(const Model &m, const std::atomic<bool> &cancel, std::atomic<int>*phase=nullptr) {
    size_t n=m.nodes.size()*3;
    if(n==0||m.force.size()!=n||m.fixed.size()!=n||(m.elements.empty()&&m.hexes.empty())) throw std::runtime_error("INVALID_MODEL");
    // The bridge supplies a full fixed face on every independent box. Generic
    // callers must still constrain rigid modes; PCG reports breakdown/nonconvergence.
    if(std::count(m.fixed.begin(),m.fixed.end(),true)<6) throw std::runtime_error("MISSING_SUPPORT");
    if(!m.prescribed.empty()&&m.prescribed.size()!=n)throw std::runtime_error("INVALID_PRESCRIBED_DISPLACEMENT");
    auto start=std::chrono::steady_clock::now();
    if(phase)phase->store(3);
    auto cells=cells_of(m);
    validate_rigid_modes(m,cells);
    auto prepared=std::chrono::steady_clock::now();
    std::vector<std::unordered_map<int,double>> K(n);
    auto allocated=std::chrono::steady_clock::now();
    double integration_ms=0,scatter_ms=0;
    // Each batch owns bounded local matrices. Group local node occurrences by
    // global node; each task exclusively owns its three matrix rows. Sorting by
    // (node, element, local node) retains the original accumulation order.
    const size_t batch=math::serial_assembly?256:2048;
    for(size_t begin=0;begin<cells.size();begin+=batch){size_t count=std::min(batch,cells.size()-begin);std::vector<Local>locals(count);
        auto tick=std::chrono::steady_clock::now();
        math::parallel_for(count,[&](size_t i){locals[i]=integrate(m,cells[begin+i]);},cancel);
        integration_ms+=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-tick).count();tick=std::chrono::steady_clock::now();
        math::nodal_scatter(count,[&](size_t e){return int(cells[begin+e].nodes.size());},
            [&](size_t e,int i){return cells[begin+e].nodes[i];},
            [&](size_t index,int local,int node){const auto&t=cells[begin+index];const auto&e=locals[index];
                for(int axis=0;axis<3;++axis){int i=3*local+axis;auto&row=K[3*node+axis];
                    for(int j=0;j<e.n;++j)row[t.nodes[j/3]*3+j%3]+=e.K[i*e.n+j];}
            },cancel);
        scatter_ms+=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-tick).count();
    }
    auto assembled=std::chrono::steady_clock::now();
    if(phase)phase->store(4);
    auto linear=unicore::math::pcg(K,m.force,m.fixed,m.prescribed,cancel,nullptr,3);
    Result out;out.element_preparation_ms=std::chrono::duration<double,std::milli>(prepared-start).count();out.pattern_container_ms=std::chrono::duration<double,std::milli>(allocated-prepared).count();out.preconditioner_ms=linear.preconditioner_ms;out.pcg_ms=linear.pcg_ms;out.linear_post_ms=linear.linear_post_ms;out.integration_ms=integration_ms;out.scatter_ms=scatter_ms;out.csr_ms=linear.csr_ms;out.constraint_ms=linear.constraint_ms;out.displacement=std::move(linear.x);out.reaction=std::move(linear.reaction);out.residual=linear.residual;out.iterations=linear.iterations;
    out.linear_diagnostics.preconditioner_ms=linear.preconditioner_ms;out.linear_diagnostics.pcg_ms=linear.pcg_ms;out.linear_diagnostics.preconditioner=linear.preconditioner;out.linear_diagnostics.fallback=linear.fallback;out.linear_diagnostics.preconditioner_bytes=linear.preconditioner_bytes;out.linear_diagnostics.symmetry_ms=linear.symmetry_ms;out.linear_diagnostics.absolute_residual=linear.absolute_residual;
    auto solved=std::chrono::steady_clock::now();
    if(phase)phase->store(5);
    out.fields.resize(cells.size());
    math::parallel_for(cells.size(),[&](size_t index){auto &t=cells[index];
        auto e=integrate(m,t); Field f;
        for(int i=0;i<6;++i)for(int j=0;j<e.n;++j)f.strain[i]+=e.B[i*e.n+j]*out.displacement[t.nodes[j/3]*3+j%3];
        for(int i=0;i<6;++i)for(int j=0;j<6;++j)f.stress[i]+=e.D[i][j]*f.strain[j];
        auto s=f.stress; f.von_mises=std::sqrt(0.5*((s[0]-s[1])*(s[0]-s[1])+(s[1]-s[2])*(s[1]-s[2])+(s[2]-s[0])*(s[2]-s[0]))+3*(s[3]*s[3]+s[4]*s[4]+s[5]*s[5]));
        out.fields[index]=f;
    },cancel);
    out.assembly_ms=std::chrono::duration<double,std::milli>(assembled-start).count();out.solve_ms=std::chrono::duration<double,std::milli>(solved-assembled).count();out.post_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-solved).count();
    return out;
}
}
