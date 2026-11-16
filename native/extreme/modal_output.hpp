#pragma once
#include "kernels/modal_solver.hpp"
#include <bcrypt.h>
// Windows system CNG; no third-party crypto dependency or changes to legacy proof fields.
inline std::string modal_sha256_bytes(const std::string&bytes){
    BCRYPT_ALG_HANDLE algorithm=nullptr;BCRYPT_HASH_HANDLE hash=nullptr;
    std::vector<unsigned char>object;
    struct Cleanup {BCRYPT_ALG_HANDLE&a;BCRYPT_HASH_HANDLE&h;~Cleanup(){if(h)BCryptDestroyHash(h);if(a)BCryptCloseAlgorithmProvider(a,0);}} cleanup{algorithm,hash};
    if(BCryptOpenAlgorithmProvider(&algorithm,BCRYPT_SHA256_ALGORITHM,nullptr,0)<0)throw std::runtime_error("SHA256_PROVIDER_FAILED");
    DWORD length=0,used=0;if(BCryptGetProperty(algorithm,BCRYPT_OBJECT_LENGTH,reinterpret_cast<PUCHAR>(&length),sizeof(length),&used,0)<0)throw std::runtime_error("SHA256_PROPERTY_FAILED");
    object.resize(length);unsigned char digest[32];
    if(BCryptCreateHash(algorithm,&hash,object.data(),length,nullptr,0,0)<0)throw std::runtime_error("SHA256_CREATE_FAILED");
    if(bytes.size()>8*1024*1024)throw std::runtime_error("MODAL_INPUT_BYTE_LIMIT");
    if(BCryptHashData(hash,reinterpret_cast<PUCHAR>(const_cast<char*>(bytes.data())),ULONG(bytes.size()),0)<0)throw std::runtime_error("SHA256_UPDATE_FAILED");
    if(BCryptFinishHash(hash,digest,sizeof(digest),0)<0)throw std::runtime_error("SHA256_FINISH_FAILED");
    const char*hex="0123456789abcdef";std::string result;for(auto value:digest){result+=hex[value>>4];result+=hex[value&15];}return result;
}
inline void modal_json(std::ostream&out,const modal::Model&m,const modal::Result&r,const std::string&sha){
    out<<"\"modal_schema\":1,\"job_sha256\":\""<<sha<<"\",\"solver\":\"sparse_block_inverse_iteration_ritz\",\"converged\":true,\"normalization\":\"phi_T_M_phi=1\",\"amplitude_interpretation\":\"relative_mode_shape_not_operating_displacement\",\"coordinate_units\":\"m\",\"density_units\":\"kg/m^3\",\"eigenvector_units\":\"kg^-1/2\",\"dof_order\":\"3*node+[x,y,z]\",\"node_count\":"<<m.structure.nodes.size()<<",\"active_dof_count\":"<<r.active_dofs.size()<<",\"requested_modes\":"<<m.options.modes<<",\"eigenpair_tolerance\":"<<m.options.tolerance<<",\"eigen_iteration_limit\":"<<m.options.iterations<<",\"wall_time_limit_s\":"<<m.options.seconds<<",\"stiffness_nnz\":"<<r.stiffness_nnz<<",\"mass_nnz\":"<<r.mass_nnz<<",\"total_mass_kg\":"<<r.total_mass<<",\"assembly_ms\":"<<r.assembly_ms<<",\"solve_ms\":"<<r.solve_ms<<",\"iterations\":"<<r.spectrum.iterations<<",\"linear_iterations\":"<<r.spectrum.linear_iterations<<",\"selected_preconditioner\":\""<<r.spectrum.preconditioner<<"\",\"preconditioner_fallback\":\""<<r.spectrum.fallback<<"\",\"nodes\":";json(out,m.structure.nodes);
    out<<",\"active_dof_ids\":[";for(size_t i=0;i<r.active_dofs.size();++i){if(i)out<<',';out<<r.active_dofs[i];}out<<"],\"elements\":[";
    for(size_t i=0;i<m.structure.elements.size();++i){if(i)out<<',';auto&t=m.structure.elements[i];out<<'['<<t.nodes[0]<<','<<t.nodes[1]<<','<<t.nodes[2]<<','<<t.nodes[3]<<']';}out<<"],\"materials\":[";
    for(size_t i=0;i<m.density.size();++i){if(i)out<<',';auto material=m.structure.elements[i].material;out<<"{\"E_Pa\":"<<material.E<<",\"nu\":"<<material.nu<<",\"density_kg_m3\":"<<m.density[i]<<'}';}out<<"],\"modes\":[";
    for(int j=0;j<m.options.modes;++j){if(j)out<<',';double lambda=r.spectrum.eigenvalues[j],omega=std::sqrt(lambda);std::vector<double>full(m.structure.nodes.size()*3);
        for(size_t i=0;i<r.active_dofs.size();++i)full[r.active_dofs[i]]=r.spectrum.vectors[j][i];
        out<<"{\"mode_index\":"<<j+1<<",\"eigenvalue_rad2_s2\":"<<lambda<<",\"angular_frequency_rad_s\":"<<omega<<",\"frequency_Hz\":"<<omega/(2*std::acos(-1.))<<",\"generalized_residual\":"<<r.spectrum.residuals[j]<<",\"converged\":true,\"displacement_flat\":";json(out,full);out<<'}';}
    out<<']';
}
