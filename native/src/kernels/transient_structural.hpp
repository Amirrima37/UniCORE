#pragma once
#include "kernels/modal_solver.hpp"
#include "math/newmark.hpp"
namespace unicore::dynamics {
struct Model {modal::Model fem;Vector initial_u,initial_v;std::vector<Load>loads;Options options;};
struct Result {History history;std::vector<int>active_dofs;size_t stiffness_nnz=0,mass_nnz=0;double total_mass=0,assembly_ms=0;};
inline Result solve(const Model&m,const std::atomic<bool>&cancel,std::atomic<int>*phase=nullptr){
    const auto&s=m.fem.structure;size_t n=3*s.nodes.size();m.options.validate(n);Guard guard{cancel,m.options.seconds};guard.check();
    if(!n||n>3000||s.elements.empty()||s.elements.size()>6000||!s.hexes.empty()||s.fixed.size()!=n||s.prescribed.size()!=n||m.fem.density.size()!=s.elements.size()||m.initial_u.size()!=n||m.initial_v.size()!=n||m.loads.size()>4096)throw std::runtime_error("INVALID_DYNAMIC_FEM_MODEL");
    finite(m.initial_u);finite(m.initial_v);for(auto&p:s.nodes)for(double x:p)if(!std::isfinite(x))throw std::runtime_error("NONFINITE_DYNAMIC_COORDINATE");
    if(!s.force.empty())throw std::runtime_error("DYNAMIC_FORCES_REQUIRE_LOAD_HISTORIES");
    Result r;std::vector<int>map(n,-1);
    for(size_t i=0;i<n;++i){if(!std::isfinite(s.prescribed[i])||s.prescribed[i]!=0)throw std::runtime_error("DYNAMIC_MOVING_SUPPORT_UNSUPPORTED");if(s.fixed[i]&&(m.initial_u[i]!=0||m.initial_v[i]!=0))throw std::runtime_error("DYNAMIC_INITIAL_SUPPORT_MOTION");if(!s.fixed[i]){map[i]=int(r.active_dofs.size());r.active_dofs.push_back(int(i));}}
    structural::validate_rigid_modes(s,structural::cells_of(s));if(r.active_dofs.empty())throw std::runtime_error("NO_ACTIVE_DYNAMIC_DOFS");
    Vector u,v;for(int id:r.active_dofs){u.push_back(m.initial_u[id]);v.push_back(m.initial_v[id]);}
    std::vector<Load>loads;for(auto l:m.loads){l.validate(n);if(map[l.dof]>=0){l.dof=map[l.dof];loads.push_back(l);}}
    if(phase)*phase=3;auto start=std::chrono::steady_clock::now();math::Sparse stiffness(u.size()),mass(u.size());
    for(size_t e=0;e<s.elements.size();++e){guard.check();auto&t=s.elements[e];auto local=structural::element(s,t);auto me=modal::tet_mass(local.volume,m.fem.density[e]);r.total_mass+=local.volume*m.fem.density[e];
        for(int i=0;i<12;++i){int a=map[3*t.nodes[i/3]+i%3];if(a<0)continue;for(int j=0;j<12;++j){int b=map[3*t.nodes[j/3]+j%3];if(b<0)continue;stiffness[a][b]+=local.K[i][j];if(me[12*i+j]!=0)mass[a][b]+=me[12*i+j];}}}
    if(!std::isfinite(r.total_mass)||r.total_mass<=0)throw std::runtime_error("INVALID_DYNAMIC_MASS");Matrix K(stiffness),M(mass);r.stiffness_nnz=K.values.size();r.mass_nnz=M.values.size();math::Sparse().swap(stiffness);math::Sparse().swap(mass);
    r.assembly_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();r.history=integrate(K,M,u,v,loads,m.options,guard,phase);return r;
}
}
