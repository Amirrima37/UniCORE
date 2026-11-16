#pragma once
#include "kernels/structural_solver.hpp"
#include "math/symmetric_modes.hpp"
namespace unicore::modal {
// Physical mass density is separate from the unchanged static Material ABI.
struct Model {structural::Model structure;Vector density;Limits options;};
inline std::array<double,144> tet_mass(double volume,double density){
    if(!std::isfinite(volume)||volume<=0||!std::isfinite(density)||density<=0)throw std::runtime_error("INVALID_MODAL_DENSITY_OR_VOLUME");
    std::array<double,144>mass{};double scale=density*volume/20;
    if(!std::isfinite(scale)||scale<=0)throw std::runtime_error("INVALID_MODAL_MASS_SCALE");
    for(int a=0;a<4;++a)for(int b=0;b<4;++b)for(int c=0;c<3;++c)mass[(3*a+c)*12+3*b+c]=scale*(a==b?2:1);
    return mass;
}
struct Result {Spectrum spectrum;std::vector<int>active_dofs;size_t stiffness_nnz=0,mass_nnz=0;double total_mass=0,assembly_ms=0,solve_ms=0;};
inline Result solve(const Model&m,const std::atomic<bool>&cancel,std::atomic<int>*phase=nullptr){
    m.options.validate();Guard guard{cancel,std::chrono::steady_clock::now(),m.options.seconds};guard.check();
    const auto&s=m.structure;size_t n=s.nodes.size()*3;
    if(!n||n>6000||s.elements.empty()||s.elements.size()>12000||!s.hexes.empty())throw std::runtime_error("MODAL_REQUIRES_BOUNDED_TET4");
    if(s.fixed.size()!=n||s.prescribed.size()!=n||(!s.force.empty()&&s.force.size()!=n)||m.density.size()!=s.elements.size())throw std::runtime_error("INVALID_MODAL_MODEL");
    for(const auto&p:s.nodes)for(double v:p)if(!std::isfinite(v))throw std::runtime_error("NONFINITE_MODAL_COORDINATE");
    for(size_t i=0;i<n;++i){if(!std::isfinite(s.prescribed[i])||s.prescribed[i]!=0)throw std::runtime_error("MODAL_REQUIRES_HOMOGENEOUS_CONSTRAINTS");if(!s.force.empty()&&s.force[i]!=0)throw std::runtime_error("MODAL_STATIC_FORCE_UNSUPPORTED");}
    auto cells=structural::cells_of(s);structural::validate_rigid_modes(s,cells);
    Result r;std::vector<int>map(n,-1);for(size_t i=0;i<n;++i)if(!s.fixed[i]){map[i]=int(r.active_dofs.size());r.active_dofs.push_back(int(i));}
    if(r.active_dofs.size()<size_t(m.options.modes))throw std::runtime_error("INSUFFICIENT_ACTIVE_MODAL_DOFS");
    math::Sparse stiffness(r.active_dofs.size()),mass(r.active_dofs.size());if(phase)*phase=3;
    auto begin=std::chrono::steady_clock::now();
    for(size_t e=0;e<s.elements.size();++e){guard.check();const auto&t=s.elements[e];auto local=structural::element(s,t);auto me=tet_mass(local.volume,m.density[e]);r.total_mass+=local.volume*m.density[e];
        for(int i=0;i<12;++i){int a=map[3*t.nodes[i/3]+i%3];if(a<0)continue;for(int j=0;j<12;++j){int b=map[3*t.nodes[j/3]+j%3];if(b<0)continue;stiffness[a][b]+=local.K[i][j];if(me[i*12+j]!=0)mass[a][b]+=me[i*12+j];}}}
    if(!std::isfinite(r.total_mass)||r.total_mass<=0)throw std::runtime_error("INVALID_MODAL_TOTAL_MASS");
    Matrix K(stiffness),M(mass);r.stiffness_nnz=K.values.size();r.mass_nnz=M.values.size();r.assembly_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-begin).count();
    // Release assembly hash maps before eigenvector workspaces are allocated.
    math::Sparse().swap(stiffness);math::Sparse().swap(mass);if(phase)*phase=4;
    begin=std::chrono::steady_clock::now();r.spectrum=lowest(K,M,m.options,guard);r.solve_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-begin).count();return r;
}
}
