#pragma once
#include <vector>
#include <unordered_map>
#include <atomic>
#include <cmath>
#include <stdexcept>
#include <algorithm>
namespace unicore::math {
using Sparse=std::vector<std::unordered_map<int,double>>;
struct LinearResult {std::vector<double>x,reaction;double residual=0;int iterations=0;};
inline LinearResult pcg(const Sparse &matrix,const std::vector<double>&force,const std::vector<bool>&fixed,const std::vector<double>&values,const std::atomic<bool>&cancel){
    size_t n=matrix.size();if(!n||force.size()!=n||fixed.size()!=n||(!values.empty()&&values.size()!=n))throw std::runtime_error("INVALID_LINEAR_SYSTEM");
    // Compact the assembled rows once; inner iterations never traverse hash maps.
    std::vector<size_t> offsets(n+1);std::vector<int>columns;std::vector<double>coefficients,diagonal(n,1);
    LinearResult out;out.x.assign(n,0);std::vector<double>r=force,z(n),p(n),ap(n);
    for(size_t i=0;i<n;++i){
        if(cancel.load())throw std::runtime_error("CANCELLED");
        if(fixed[i]&&!values.empty())out.x[i]=values[i];
        if(!std::isfinite(out.x[i])||!std::isfinite(force[i]))throw std::runtime_error("NONFINITE_LINEAR_INPUT");
        std::vector<std::pair<int,double>> entries(matrix[i].begin(),matrix[i].end());std::sort(entries.begin(),entries.end());
        for(auto entry:entries){if(entry.first<0||size_t(entry.first)>=n||!std::isfinite(entry.second))throw std::runtime_error("INVALID_SPARSE_ENTRY");columns.push_back(entry.first);coefficients.push_back(entry.second);if(size_t(entry.first)==i&&!fixed[i])diagonal[i]=entry.second;}
        offsets[i+1]=columns.size();
        if(!fixed[i]&&(matrix[i].find(int(i))==matrix[i].end()||diagonal[i]<=0))throw std::runtime_error("SINGULAR_SYSTEM");
    }
    for(size_t i=0;i<n;++i){if(fixed[i])r[i]=0;else for(size_t j=offsets[i];j<offsets[i+1];++j)if(fixed[columns[j]])r[i]-=coefficients[j]*out.x[columns[j]];z[i]=r[i]/diagonal[i];}
    auto inner=[](const std::vector<double>&a,const std::vector<double>&b){double v=0;for(size_t i=0;i<a.size();++i)v+=a[i]*b[i];return v;};
    p=z;double rz=inner(r,z),norm=std::sqrt(inner(r,r)),tolerance=1e-10*std::max(norm,1.0);
    for(int it=0;std::sqrt(inner(r,r))>tolerance&&it<20000;++it){
        if(cancel.load())throw std::runtime_error("CANCELLED");std::fill(ap.begin(),ap.end(),0);
        for(size_t i=0;i<n;++i)if(!fixed[i])for(size_t j=offsets[i];j<offsets[i+1];++j)if(!fixed[columns[j]])ap[i]+=coefficients[j]*p[columns[j]];
        double denominator=inner(p,ap);if(!std::isfinite(denominator)||denominator<=0)throw std::runtime_error("SINGULAR_SYSTEM");double alpha=rz/denominator;
        for(size_t i=0;i<n;++i){out.x[i]+=alpha*p[i];r[i]-=alpha*ap[i];z[i]=r[i]/diagonal[i];}
        double next=inner(r,z),beta=next/rz;rz=next;for(size_t i=0;i<n;++i)p[i]=z[i]+beta*p[i];out.iterations=it+1;
    }
    out.reaction.assign(n,0);double error=0;
    for(size_t i=0;i<n;++i){double v=-force[i];for(size_t j=offsets[i];j<offsets[i+1];++j)v+=coefficients[j]*out.x[columns[j]];if(fixed[i])out.reaction[i]=v;else error+=v*v;}
    out.residual=std::sqrt(error)/std::max(norm,1.0);if(!std::isfinite(out.residual)||out.residual>1e-7)throw std::runtime_error("NONCONVERGENCE");return out;
}
}
