#pragma once
#include <vector>
#include <chrono>
#include "math/preconditioner.hpp"
#include <unordered_map>
#include <atomic>
#include <cmath>
#include <stdexcept>
#include <algorithm>
namespace unicore::math {
using Sparse=std::vector<std::unordered_map<int,double>>;
inline std::atomic<int> progress_iteration{0};
inline std::atomic<double> progress_residual{0};
struct LinearResult {std::vector<double>x,reaction;double residual=0,csr_ms=0,constraint_ms=0,preconditioner_ms=0,pcg_ms=0,linear_post_ms=0;int iterations=0;std::string preconditioner,fallback;size_t preconditioner_bytes=0;double symmetry_ms=0,absolute_residual=0;};
inline LinearResult pcg(const Sparse &matrix,const std::vector<double>&force,const std::vector<bool>&fixed,const std::vector<double>&values,const std::atomic<bool>&cancel,const compute::LinearBackend*backend=nullptr,int block_size=1,const SolverOptions&options=solver_options){
    options.validate();
    progress_iteration=0;progress_residual=0;
    size_t n=matrix.size();if(!n||force.size()!=n||fixed.size()!=n||(!values.empty()&&values.size()!=n))throw std::runtime_error("INVALID_LINEAR_SYSTEM");
    auto profile_start=std::chrono::steady_clock::now();
    // Compact the assembled rows once; inner iterations never traverse hash maps.
    std::vector<size_t> offsets(n+1);std::vector<int>columns;std::vector<double>coefficients,diagonal(n,1);
    LinearResult out;out.x.assign(n,0);std::vector<double>r=force,z(n),p(n),ap(n);
    size_t nonzeros=0;for(auto &row:matrix)nonzeros+=row.size();columns.reserve(nonzeros);coefficients.reserve(nonzeros);std::vector<std::pair<int,double>> entries;
    for(size_t i=0;i<n;++i){
        if(cancel.load())throw std::runtime_error("CANCELLED");
        if(fixed[i]&&!values.empty())out.x[i]=values[i];
        if(!std::isfinite(out.x[i])||!std::isfinite(force[i]))throw std::runtime_error("NONFINITE_LINEAR_INPUT");
        entries.assign(matrix[i].begin(),matrix[i].end());std::sort(entries.begin(),entries.end());
        for(auto entry:entries){if(entry.first<0||size_t(entry.first)>=n||!std::isfinite(entry.second))throw std::runtime_error("INVALID_SPARSE_ENTRY");columns.push_back(entry.first);coefficients.push_back(entry.second);if(size_t(entry.first)==i&&!fixed[i])diagonal[i]=entry.second;}
        offsets[i+1]=columns.size();
        if(!fixed[i]&&(matrix[i].find(int(i))==matrix[i].end()||diagonal[i]<=0))throw std::runtime_error("SINGULAR_SYSTEM");
    }
    auto symmetry_start=std::chrono::steady_clock::now();
    // PCG acts on the free/free submatrix; prescribed couplings are RHS terms.
    for(size_t i=0;i<n;++i){if(cancel.load())throw std::runtime_error("CANCELLED");if(fixed[i])continue;
        for(size_t k=offsets[i];k<offsets[i+1];++k){int j=columns[k];if(fixed[j]||j==int(i))continue;
            auto reverse=matrix[j].find(int(i));double b=reverse==matrix[j].end()?0:reverse->second;
            double scale=std::sqrt(diagonal[i])*std::sqrt(diagonal[j]);
            if(std::abs(coefficients[k]-b)>1e-12*std::max({std::abs(coefficients[k]),std::abs(b),scale}))throw std::runtime_error("NONSYMMETRIC_SYSTEM");}}
    out.symmetry_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-symmetry_start).count();
    auto compacted=std::chrono::steady_clock::now();out.csr_ms=std::chrono::duration<double,std::milli>(compacted-profile_start).count();
    for(size_t i=0;i<n;++i){if(fixed[i])r[i]=0;else for(size_t j=offsets[i];j<offsets[i+1];++j)if(fixed[columns[j]])r[i]-=coefficients[j]*out.x[columns[j]];}
    auto constrained=std::chrono::steady_clock::now();
    compute::CSRView view{offsets,columns,coefficients};
    Preconditioner preconditioner;preconditioner.build(view,diagonal,fixed,block_size,options,cancel);preconditioner.apply(r,z);
    out.preconditioner=preconditioner.selected;out.fallback=preconditioner.fallback;out.preconditioner_bytes=preconditioner.bytes();
    out.preconditioner_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-constrained).count();
    out.constraint_ms=std::chrono::duration<double,std::milli>(constrained-compacted).count();
    auto inner=[](const std::vector<double>&a,const std::vector<double>&b){double v=0;for(size_t i=0;i<a.size();++i)v+=a[i]*b[i];return v;};
    compute::CPUBackend cpu;const compute::LinearBackend &operation=backend?*backend:cpu;if(!operation.supports_fp64())throw std::runtime_error("FP64_BACKEND_REQUIRED");
    auto iteration_start=std::chrono::steady_clock::now();
    p=z;double rz=inner(r,z),norm=std::sqrt(inner(r,r)),tolerance=std::max(options.relative_tolerance*norm,options.absolute_tolerance);
    for(int it=0;std::sqrt(inner(r,r))>tolerance&&it<options.max_iterations;++it){
        if(cancel.load())throw std::runtime_error("CANCELLED");if(!std::isfinite(rz)||rz<=0)throw std::runtime_error("PCG_PRECONDITIONER_BREAKDOWN");
        operation.apply(view,p,ap,fixed);
        double denominator=inner(p,ap);if(!std::isfinite(denominator)||denominator<=0)throw std::runtime_error("SINGULAR_SYSTEM");double alpha=rz/denominator;
        for(size_t i=0;i<n;++i){out.x[i]+=alpha*p[i];r[i]-=alpha*ap[i];}
        preconditioner.apply(r,z);
        double next=inner(r,z),beta=next/rz;rz=next;for(size_t i=0;i<n;++i)p[i]=z[i]+beta*p[i];out.iterations=it+1;progress_iteration=it+1;progress_residual=std::sqrt(inner(r,r))/std::max(norm,1.0);
    }
    if(!std::isfinite(inner(r,r))||std::sqrt(inner(r,r))>tolerance)throw std::runtime_error("PCG_ITERATION_LIMIT_OR_NONFINITE_RESIDUAL");
    auto iteration_end=std::chrono::steady_clock::now();out.pcg_ms=std::chrono::duration<double,std::milli>(iteration_end-iteration_start).count();
    out.reaction.assign(n,0);double error=0;
    for(size_t i=0;i<n;++i){double v=-force[i];for(size_t j=offsets[i];j<offsets[i+1];++j)v+=coefficients[j]*out.x[columns[j]];if(fixed[i])out.reaction[i]=v;else error+=v*v;}
    out.absolute_residual=std::sqrt(error);out.residual=std::sqrt(error)/std::max(norm,1.0);if(!std::isfinite(out.residual)||out.residual>1e-7)throw std::runtime_error("NONCONVERGENCE");out.linear_post_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-iteration_end).count();return out;
}
}
