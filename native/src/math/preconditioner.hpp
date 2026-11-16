#pragma once
#include "math/csr_backend.hpp"
#include <atomic>
#include <cmath>
#include <string>
#include <algorithm>
namespace unicore::math {
struct SolverOptions {
    std::string preconditioner="jacobi";
    int max_iterations=20000;
    double relative_tolerance=1e-10,absolute_tolerance=1e-10;
    void validate()const {
        if(preconditioner!="auto"&&preconditioner!="jacobi"&&preconditioner!="block-jacobi"&&preconditioner!="ic0")throw std::runtime_error("INVALID_PRECONDITIONER");
        if(max_iterations<1||!std::isfinite(relative_tolerance)||!std::isfinite(absolute_tolerance)||relative_tolerance<0||absolute_tolerance<0||(relative_tolerance==0&&absolute_tolerance==0))throw std::runtime_error("INVALID_SOLVER_TOLERANCE_OR_LIMIT");
    }
};
// Standalone configuration is immutable while workers run. Other callers can pass options explicitly.
inline SolverOptions solver_options;
struct Preconditioner {
    std::string selected="jacobi",fallback;
    std::vector<double> diagonal,blocks,lower;
    std::vector<size_t> offsets;
    std::vector<int> columns;
    size_t bytes()const{return sizeof(double)*(diagonal.capacity()+blocks.capacity()+lower.capacity())+sizeof(size_t)*offsets.capacity()+sizeof(int)*columns.capacity();}
    void build(const compute::CSRView&a,const std::vector<double>&d,const std::vector<bool>&fixed,int block_size,const SolverOptions&o,const std::atomic<bool>&cancel){
        diagonal=d;
        // Pilot FEM timings do not justify a universal advanced-preconditioner heuristic.
        selected=o.preconditioner=="auto"?"jacobi":o.preconditioner;
        try {
            if(selected=="block-jacobi"){
                if(block_size!=3||d.size()%3) {selected="jacobi";fallback="BLOCK_STRUCTURE_UNAVAILABLE";return;}
                blocks.assign(d.size()*3,0);
                for(size_t base=0;base<d.size();base+=3){
                    if(cancel.load())throw std::runtime_error("CANCELLED");
                    double b[9]{};
                    for(int i=0;i<3;++i){if(fixed[base+i]){b[3*i+i]=1;continue;}
                        for(size_t k=a.offsets[base+i];k<a.offsets[base+i+1];++k){int j=a.columns[k]-int(base);if(j>=0&&j<3&&!fixed[base+j])b[3*i+j]=a.values[k];}}
                    for(int i=0;i<3;++i)for(int j=0;j<=i;++j){double v=b[3*i+j];for(int k=0;k<j;++k)v-=b[3*i+k]*b[3*j+k];
                        if(i==j){if(!std::isfinite(v)||v<=0)throw std::runtime_error("BLOCK_INVALID_PIVOT");b[3*i+j]=std::sqrt(v);}else b[3*i+j]=v/b[3*j+j];}
                    for(int i=0;i<3;++i)for(int j=0;j<=i;++j)blocks[base*3+3*i+j]=b[3*i+j];
                }
            }else if(selected=="ic0"){
                offsets.resize(d.size()+1);
                size_t count=0;for(size_t i=0;i<d.size();++i)if(!fixed[i])for(size_t k=a.offsets[i];k<a.offsets[i+1]&&a.columns[k]<int(i);++k)if(!fixed[a.columns[k]]&&a.values[k]!=0)++count;
                columns.reserve(count);lower.reserve(count);
                for(size_t i=0;i<d.size();++i){
                    if(cancel.load())throw std::runtime_error("CANCELLED");
                    offsets[i]=lower.size();double pivot=fixed[i]?1:d[i];
                    if(!fixed[i])for(size_t k=a.offsets[i];k<a.offsets[i+1]&&a.columns[k]<int(i);++k){int j=a.columns[k];if(fixed[j]||a.values[k]==0)continue;
                        double v=a.values[k];size_t p=offsets[i],q=offsets[j];
                        while(p<lower.size()&&q<offsets[j+1]){if(columns[p]==columns[q]){v-=lower[p]*lower[q];++p;++q;}else if(columns[p]<columns[q])++p;else ++q;}
                        v/=diagonal[j];if(!std::isfinite(v))throw std::runtime_error("IC0_INVALID_PIVOT");columns.push_back(j);lower.push_back(v);pivot-=v*v;
                    }
                    if(!std::isfinite(pivot)||pivot<=0)throw std::runtime_error("IC0_INVALID_PIVOT");diagonal[i]=std::sqrt(pivot);offsets[i+1]=lower.size();
                }
            }
        }catch(const std::runtime_error&e){
            if(std::string(e.what())=="CANCELLED")throw;
            fallback=e.what();selected="jacobi";diagonal=d;
            std::vector<double>().swap(blocks);std::vector<double>().swap(lower);std::vector<int>().swap(columns);std::vector<size_t>().swap(offsets);
        }
    }
    void apply(const std::vector<double>&r,std::vector<double>&z)const{
        if(selected=="ic0"){
            for(size_t i=0;i<r.size();++i){double v=r[i];for(size_t k=offsets[i];k<offsets[i+1];++k)v-=lower[k]*z[columns[k]];z[i]=v/diagonal[i];}
            for(size_t i=r.size();i-->0;){z[i]/=diagonal[i];for(size_t k=offsets[i];k<offsets[i+1];++k)z[columns[k]]-=lower[k]*z[i];}
        }else if(selected=="block-jacobi"){
            for(size_t base=0;base<r.size();base+=3){const double*b=blocks.data()+base*3;double v[3];
                for(int i=0;i<3;++i){v[i]=r[base+i];for(int j=0;j<i;++j)v[i]-=b[3*i+j]*v[j];v[i]/=b[3*i+i];}
                for(int i=2;i>=0;--i){for(int j=i+1;j<3;++j)v[i]-=b[3*j+i]*v[j];v[i]/=b[3*i+i];z[base+i]=v[i];}}
        }else for(size_t i=0;i<r.size();++i)z[i]=r[i]/diagonal[i];
    }
};
}
