#pragma once
// Sparse block inverse iteration; dense work is limited to the small Ritz space.
#include "math/sparse_pcg.hpp"
#include <numeric>
#include <cstdint>
namespace unicore::modal {
using Vector=std::vector<double>;
using Block=std::vector<Vector>;
inline double inner(const Vector&a,const Vector&b){double s=0;for(size_t i=0;i<a.size();++i)s+=a[i]*b[i];return s;}
inline double norm(const Vector&a){return std::sqrt(inner(a,a));}
struct Limits {
    int modes=6,iterations=300;
    double tolerance=1e-7,seconds=30;
    void validate()const{if(modes<1||modes>12||iterations<1||iterations>500||!std::isfinite(tolerance)||tolerance<1e-9||tolerance>1e-5||!std::isfinite(seconds)||seconds<=0||seconds>60)throw std::runtime_error("INVALID_MODAL_OPTIONS");}
};
struct Guard {
    const std::atomic<bool>&cancel;
    std::chrono::steady_clock::time_point start=std::chrono::steady_clock::now();
    double seconds;
    void check()const{if(cancel.load())throw std::runtime_error("CANCELLED");if(std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count()>seconds)throw std::runtime_error("MODAL_WALL_TIME_LIMIT");}
};
struct Matrix {
    std::vector<size_t> offsets;
    std::vector<int> columns;
    Vector values,diagonal;
    explicit Matrix(const math::Sparse&a){
        size_t n=a.size();if(!n||n>6000)throw std::runtime_error("MODAL_DOF_LIMIT");
        offsets.push_back(0);diagonal.resize(n);
        for(size_t i=0;i<n;++i){std::vector<std::pair<int,double>>row(a[i].begin(),a[i].end());std::sort(row.begin(),row.end());
            for(auto [j,v]:row){if(j<0||size_t(j)>=n||!std::isfinite(v))throw std::runtime_error("INVALID_MODAL_MATRIX");if(v!=0){columns.push_back(j);values.push_back(v);}if(size_t(j)==i)diagonal[i]=v;}
            if(!(diagonal[i]>0))throw std::runtime_error("MODAL_NONPOSITIVE_DIAGONAL");offsets.push_back(values.size());}
        for(size_t i=0;i<n;++i)for(size_t k=offsets[i];k<offsets[i+1];++k){int j=columns[k];auto found=a[j].find(int(i));double other=found==a[j].end()?0:found->second;
            if(std::abs(values[k]-other)>1e-12*std::max({std::abs(values[k]),std::abs(other),std::sqrt(diagonal[i])*std::sqrt(diagonal[j])}))throw std::runtime_error("NONSYMMETRIC_MODAL_MATRIX");}
    }
    compute::CSRView view()const{return {offsets,columns,values};}
    Vector apply(const Vector&x)const{Vector y(x.size());for(size_t i=0;i<x.size();++i){long double sum=0;for(size_t k=offsets[i];k<offsets[i+1];++k)sum+=static_cast<long double>(values[k])*x[columns[k]];y[i]=double(sum);}return y;}
};
// Cyclic Jacobi on a symmetric Ritz matrix, never on the full FEM matrix.
inline std::pair<Vector,Block> jacobi(Block a,const Guard&guard){
    int n=int(a.size());Block v(n,Vector(n));for(int i=0;i<n;++i)v[i][i]=1;
    bool converged=false;
    for(int sweep=0;sweep<100;++sweep){guard.check();double scale=0,off=0;for(int i=0;i<n;++i){scale=std::max(scale,std::abs(a[i][i]));for(int j=i+1;j<n;++j)off=std::max(off,std::abs(a[i][j]));}
        if(off<=1e-14*scale){converged=true;break;}
        for(int p=0;p<n;++p)for(int q=p+1;q<n;++q){if(std::abs(a[p][q])<=1e-16*scale)continue;
            double theta=.5*std::atan2(2*a[p][q],a[q][q]-a[p][p]),c=std::cos(theta),s=std::sin(theta);
            double pp=c*c*a[p][p]-2*c*s*a[p][q]+s*s*a[q][q],qq=s*s*a[p][p]+2*c*s*a[p][q]+c*c*a[q][q];
            for(int k=0;k<n;++k)if(k!=p&&k!=q){double x=c*a[k][p]-s*a[k][q],y=s*a[k][p]+c*a[k][q];a[k][p]=a[p][k]=x;a[k][q]=a[q][k]=y;}
            a[p][p]=pp;a[q][q]=qq;a[p][q]=a[q][p]=0;
            for(int k=0;k<n;++k){double x=c*v[k][p]-s*v[k][q],y=s*v[k][p]+c*v[k][q];v[k][p]=x;v[k][q]=y;}}
    }
    if(!converged)throw std::runtime_error("MODAL_RITZ_NONCONVERGENCE");
    std::vector<int>ids(n);std::iota(ids.begin(),ids.end(),0);std::stable_sort(ids.begin(),ids.end(),[&](int i,int j){return a[i][i]<a[j][j];});
    Vector eigen(n);Block columns(n,Vector(n));for(int j=0;j<n;++j){eigen[j]=a[ids[j]][ids[j]];for(int i=0;i<n;++i)columns[j][i]=v[i][ids[j]];}
    return {eigen,columns};
}
struct Spectrum {Vector eigenvalues,residuals;Block vectors;int iterations=0,linear_iterations=0;std::string preconditioner,fallback;};
inline Spectrum lowest(const Matrix&K,const Matrix&M,const Limits&o,const Guard&guard){
    o.validate();size_t n=K.diagonal.size();if(M.diagonal.size()!=n||size_t(o.modes)>n)throw std::runtime_error("INVALID_MODAL_DIMENSIONS");
    int b=std::min(int(n),std::max(2*o.modes,o.modes+6));
    math::SolverOptions options;options.preconditioner="ic0";options.relative_tolerance=1e-12;options.absolute_tolerance=0;
    std::vector<bool>free(n,false);math::Preconditioner pre;pre.build(K.view(),K.diagonal,free,1,options,guard.cancel);
    Spectrum out;out.preconditioner=pre.selected;out.fallback=pre.fallback;
    auto inverse=[&](const Vector&rhs){
        Vector x(n),r=rhs,z(n),p(n);pre.apply(r,z);p=z;double rz=inner(r,z),initial=norm(rhs);
        if(!std::isfinite(initial)||initial==0)throw std::runtime_error("INVALID_MODAL_RHS");
        for(int it=0;it<20000;++it){guard.check();auto ap=K.apply(p);double curvature=inner(p,ap);if(!std::isfinite(curvature)||curvature<=0||!std::isfinite(rz)||rz<=0)throw std::runtime_error("MODAL_K_NOT_POSITIVE_DEFINITE");
            double alpha=rz/curvature;for(size_t i=0;i<n;++i){x[i]+=alpha*p[i];r[i]-=alpha*ap[i];}++out.linear_iterations;
            if(norm(r)<=1e-12*initial){auto actual=K.apply(x);for(size_t i=0;i<n;++i)actual[i]=rhs[i]-actual[i];if(norm(actual)<=1e-9*initial)return x;
                // Reliable residual replacement: recurrence residuals can drift
                // on slender continuum meshes. Restart CG with the true defect.
                r=std::move(actual);pre.apply(r,z);p=z;rz=inner(r,z);continue;}
            pre.apply(r,z);double next=inner(r,z),beta=next/rz;for(size_t i=0;i<n;++i)p[i]=z[i]+beta*p[i];rz=next;
        }throw std::runtime_error("MODAL_LINEAR_ITERATION_LIMIT");
    };
    auto orthogonalize=[&](Block&q){Block mq;
        for(auto &x:q){guard.check();auto mx=M.apply(x);double initial=inner(x,mx);if(!std::isfinite(initial)||initial<=0)throw std::runtime_error("MODAL_M_NOT_POSITIVE_DEFINITE");
            for(int pass=0;pass<2;++pass)for(size_t j=0;j<mq.size();++j){double c=inner(q[j],mx);for(size_t i=0;i<n;++i){x[i]-=c*q[j][i];mx[i]-=c*mq[j][i];}}
            double mass=inner(x,mx);if(!std::isfinite(mass)||mass<=initial*1e-28)throw std::runtime_error("MODAL_SUBSPACE_RANK_LOSS");
            double scale=1/std::sqrt(mass);for(size_t i=0;i<n;++i){x[i]*=scale;mx[i]*=scale;}mq.push_back(std::move(mx));}
    };
    Block q(b,Vector(n));uint64_t state=0x94d049bb133111ebULL;
    for(auto&x:q)for(auto&v:x){state^=state>>12;state^=state<<25;state^=state>>27;v=double((state*2685821657736338717ULL)>>11)*0x1.0p-53-.5;}
    orthogonalize(q);
    for(int iteration=1;iteration<=o.iterations;++iteration){guard.check();Block y;for(auto&x:q)y.push_back(inverse(M.apply(x)));orthogonalize(y);
        Block ky;for(auto&x:y)ky.push_back(K.apply(x));Block projected(b,Vector(b));
        for(int i=0;i<b;++i)for(int j=0;j<=i;++j)projected[i][j]=projected[j][i]=.5*(inner(y[i],ky[j])+inner(y[j],ky[i]));
        auto [lambda,rotation]=jacobi(projected,guard);q.assign(b,Vector(n));
        for(int j=0;j<b;++j)for(int k=0;k<b;++k)for(size_t i=0;i<n;++i)q[j][i]+=y[k][i]*rotation[j][k];
        bool converged=true;out.residuals.clear();
        for(int j=0;j<o.modes;++j){auto kx=K.apply(q[j]),mx=M.apply(q[j]);double denominator=norm(kx)+std::abs(lambda[j])*norm(mx);
            for(size_t i=0;i<n;++i)kx[i]-=lambda[j]*mx[i];double residual=norm(kx)/denominator;
            if(!(lambda[j]>0)||!std::isfinite(lambda[j])||!(denominator>0)||!std::isfinite(residual))throw std::runtime_error("INVALID_MODAL_EIGENPAIR");
            out.residuals.push_back(residual);if(residual>o.tolerance)converged=false;}
        out.iterations=iteration;math::progress_iteration=iteration;math::progress_residual=*std::max_element(out.residuals.begin(),out.residuals.end());
        if(converged){out.eigenvalues.assign(lambda.begin(),lambda.begin()+o.modes);out.vectors.assign(q.begin(),q.begin()+o.modes);
            for(auto&x:out.vectors){size_t pivot=0;for(size_t i=1;i<n;++i)if(std::abs(x[i])>std::abs(x[pivot]))pivot=i;if(x[pivot]<0)for(double&v:x)v=-v;}
            for(int i=0;i<o.modes;++i)for(int j=0;j<=i;++j)if(std::abs(inner(out.vectors[i],M.apply(out.vectors[j]))-(i==j?1.:0.))>1e-9)throw std::runtime_error("MODAL_MASS_ORTHOGONALITY_FAILURE");
            return out;}
    }throw std::runtime_error("MODAL_EIGEN_ITERATION_LIMIT");
}
}
