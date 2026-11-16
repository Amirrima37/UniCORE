#pragma once
#include "math/symmetric_modes.hpp"
namespace unicore::dynamics {
using modal::Vector;
using modal::Matrix;
using modal::inner;
using modal::norm;
struct Options {
    double dt=.001,alpha_mass=0,beta_stiffness=0,tolerance=1e-11,seconds=30;
    int steps=100,linear_iterations=2000;
    std::vector<int>outputs;
    void validate(size_t full_dofs)const{
        if(!std::isfinite(dt)||dt<=0||!std::isfinite(dt*dt)||dt*dt==0||steps<1||steps>20000||!std::isfinite(dt*steps))throw std::runtime_error("INVALID_DYNAMIC_TIME_SETTINGS");
        if(!std::isfinite(alpha_mass)||alpha_mass<0||!std::isfinite(beta_stiffness)||beta_stiffness<0)throw std::runtime_error("INVALID_RAYLEIGH_DAMPING");
        if(linear_iterations<1||linear_iterations>20000||!std::isfinite(tolerance)||tolerance<1e-12||tolerance>1e-10||!std::isfinite(seconds)||seconds<=0||seconds>60)throw std::runtime_error("INVALID_DYNAMIC_SOLVER_OPTIONS");
        if(outputs.size()<2||outputs.size()>1001||full_dofs*outputs.size()>200000||outputs.front()!=0||outputs.back()!=steps)throw std::runtime_error("INVALID_DYNAMIC_OUTPUT_BOUND");
        for(size_t i=1;i<outputs.size();++i)if(outputs[i]<=outputs[i-1]||outputs[i]>steps)throw std::runtime_error("INVALID_DYNAMIC_OUTPUT_STEPS");
    }
};
struct Guard {
    const std::atomic<bool>&cancel;
    double seconds;
    std::chrono::steady_clock::time_point start=std::chrono::steady_clock::now();
    void check()const{if(cancel.load())throw std::runtime_error("CANCELLED");if(std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count()>seconds)throw std::runtime_error("DYNAMIC_WALL_TIME_LIMIT");}
};
struct Load {
    int dof=0;std::string kind="constant";double amplitude=0,start=0,end=0,omega=0,phase=0;
    void validate(size_t dofs)const{
        if(dof<0||size_t(dof)>=dofs||!std::isfinite(amplitude)||!std::isfinite(start)||start<0||!std::isfinite(end)||!std::isfinite(omega)||!std::isfinite(phase))throw std::runtime_error("INVALID_DYNAMIC_LOAD");
        if(kind=="constant"){if(start!=0||end!=0||omega!=0||phase!=0)throw std::runtime_error("INVALID_CONSTANT_LOAD");}
        else if(kind=="step"){if(end!=0||omega!=0||phase!=0)throw std::runtime_error("INVALID_STEP_LOAD");}
        else if(kind=="ramp"){if(end<=start||omega!=0||phase!=0)throw std::runtime_error("INVALID_RAMP_LOAD");}
        else if(kind=="sine"){if(end!=0||omega<=0)throw std::runtime_error("INVALID_SINE_LOAD");}
        else throw std::runtime_error("UNSUPPORTED_DYNAMIC_LOAD_KIND");
    }
    double value(double t)const{
        double v=amplitude;
        if(kind=="step")v=t>=start?amplitude:0;
        else if(kind=="ramp")v=amplitude*std::clamp((t-start)/(end-start),0.,1.);
        else if(kind=="sine")v=t>=start?amplitude*std::sin(omega*(t-start)+phase):0;
        if(!std::isfinite(v))throw std::runtime_error("NONFINITE_DYNAMIC_FORCE");return v;
    }
};
inline void finite(const Vector&v){for(double x:v)if(!std::isfinite(x))throw std::runtime_error("NONFINITE_DYNAMIC_STATE");}
// Cached CSR and IC(0) setup. No changes to static/modal PCG tolerances.
struct PreparedCG {
    const Matrix&A;math::Preconditioner pre;int iterations=0,limit;double tolerance,max_residual=0;
    PreparedCG(const Matrix&a,const Options&o,const Guard&guard):A(a),limit(o.linear_iterations),tolerance(o.tolerance){
        guard.check();math::SolverOptions options;options.preconditioner="ic0";
        pre.build(A.view(),A.diagonal,std::vector<bool>(A.diagonal.size(),false),1,options,guard.cancel);
    }
    Vector solve(const Vector&rhs,const Guard&guard){
        guard.check();finite(rhs);size_t n=rhs.size();Vector x(n),r=rhs,z(n),p(n);double scale=norm(rhs);
        if(!std::isfinite(scale))throw std::runtime_error("NONFINITE_DYNAMIC_RHS");if(scale==0)return x;
        pre.apply(r,z);p=z;double rz=inner(r,z);
        for(int it=0;it<limit;++it){guard.check();auto ap=A.apply(p);double curvature=inner(p,ap);
            if(!std::isfinite(curvature)||curvature<=0||!std::isfinite(rz)||rz<=0)throw std::runtime_error("DYNAMIC_PCG_BREAKDOWN");
            double alpha=rz/curvature;for(size_t i=0;i<n;++i){x[i]+=alpha*p[i];r[i]-=alpha*ap[i];}++iterations;
            if(norm(r)<=tolerance*scale){auto actual=A.apply(x);for(size_t i=0;i<n;++i)actual[i]=rhs[i]-actual[i];double true_residual=norm(actual)/scale;
                if(std::isfinite(true_residual)&&true_residual<=1e-9){max_residual=std::max(max_residual,true_residual);finite(x);return x;}
                r=std::move(actual);pre.apply(r,z);p=z;rz=inner(r,z);continue;}
            pre.apply(r,z);double next=inner(r,z),beta=next/rz;for(size_t i=0;i<n;++i)p[i]=z[i]+beta*p[i];rz=next;
        }throw std::runtime_error("DYNAMIC_LINEAR_NONCONVERGENCE");
    }
};
struct Frame {int step=0;double time=0,kinetic=0,elastic=0,dissipation=0,work=0,balance=0,residual=0;Vector u,v,a;};
struct History {std::vector<Frame>frames;double setup_ms=0,integration_ms=0,max_equilibrium_residual=0,max_linear_residual=0,max_energy_balance=0;int linear_iterations=0,effective_setups=1;std::string preconditioner,fallback;};
inline math::Sparse combine(const Matrix&K,const Matrix&M,double k,double m){
    math::Sparse rows(K.diagonal.size());
    for(size_t i=0;i<rows.size();++i){for(size_t j=K.offsets[i];j<K.offsets[i+1];++j)rows[i][K.columns[j]]+=k*K.values[j];for(size_t j=M.offsets[i];j<M.offsets[i+1];++j)rows[i][M.columns[j]]+=m*M.values[j];}return rows;
}
inline History integrate(const Matrix&K,const Matrix&M,Vector u,Vector v,const std::vector<Load>&loads,const Options&o,const Guard&guard,std::atomic<int>*phase=nullptr){
    const size_t n=K.diagonal.size();o.validate(n);guard.check();
    if(M.diagonal.size()!=n||u.size()!=n||v.size()!=n||n>3000||loads.size()>4096)throw std::runtime_error("INVALID_DYNAMIC_SYSTEM");finite(u);finite(v);for(auto&l:loads)l.validate(n);
    auto start=std::chrono::steady_clock::now();double h=o.dt,h2=h*h/4;
    Matrix effective(combine(K,M,h2+h*o.beta_stiffness/2,1+h*o.alpha_mass/2));
    PreparedCG mass_system(M,o,guard),system(effective,o,guard);History out;out.preconditioner=system.pre.selected;out.fallback=system.pre.fallback;
    auto damping=[&](const Vector&x){auto mx=M.apply(x),kx=K.apply(x);for(size_t i=0;i<n;++i)mx[i]=o.alpha_mass*mx[i]+o.beta_stiffness*kx[i];return mx;};
    auto force=[&](double t){Vector f(n);for(auto&l:loads)f[l.dof]+=l.value(t);finite(f);return f;};
    auto f=force(0),ku=K.apply(u),cv=damping(v);Vector rhs(n);for(size_t i=0;i<n;++i)rhs[i]=f[i]-ku[i]-cv[i];Vector a=mass_system.solve(rhs,guard);
    out.setup_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();start=std::chrono::steady_clock::now();
    double dissipation=0,work=0,initial_energy=.5*inner(v,M.apply(v))+.5*inner(u,K.apply(u));size_t output=0;
    auto record=[&](int step){auto ma=M.apply(a),kv=K.apply(u),dv=damping(v);Vector defect(n);for(size_t i=0;i<n;++i)defect[i]=ma[i]+dv[i]+kv[i]-f[i];
        double denominator=norm(ma)+norm(dv)+norm(kv)+norm(f),residual=denominator>0?norm(defect)/denominator:norm(defect);
        if(!std::isfinite(residual)||residual>1e-8)throw std::runtime_error("DYNAMIC_EQUILIBRIUM_FAILURE");out.max_equilibrium_residual=std::max(out.max_equilibrium_residual,residual);
        double kinetic=.5*inner(v,M.apply(v)),elastic=.5*inner(u,kv),balance=kinetic+elastic+dissipation-work-initial_energy;
        if(!std::isfinite(kinetic)||!std::isfinite(elastic)||!std::isfinite(dissipation)||!std::isfinite(work)||!std::isfinite(balance)||kinetic<0||elastic<0||dissipation<0)throw std::runtime_error("INVALID_DYNAMIC_ENERGY");out.max_energy_balance=std::max(out.max_energy_balance,std::abs(balance));
        if(output<o.outputs.size()&&o.outputs[output]==step){out.frames.push_back({step,step*h,kinetic,elastic,dissipation,work,balance,residual,u,v,a});++output;}
    };
    record(0);if(phase)*phase=4;
    for(int step=1;step<=o.steps;++step){guard.check();Vector up(n),vp(n);for(size_t i=0;i<n;++i){up[i]=u[i]+h*v[i]+h2*a[i];vp[i]=v[i]+h*a[i]/2;}
        auto next_force=force(step*h),kup=K.apply(up),cvp=damping(vp);for(size_t i=0;i<n;++i)rhs[i]=next_force[i]-kup[i]-cvp[i];auto next_a=system.solve(rhs,guard);
        Vector next_u(n),next_v(n),average_v(n),du(n),average_force(n);
        for(size_t i=0;i<n;++i){next_u[i]=up[i]+h2*next_a[i];next_v[i]=vp[i]+h*next_a[i]/2;average_v[i]=(next_v[i]+v[i])/2;du[i]=next_u[i]-u[i];average_force[i]=(next_force[i]+f[i])/2;}
        finite(next_u);finite(next_v);finite(next_a);double increment=h*inner(average_v,damping(average_v));if(increment<0||!std::isfinite(increment))throw std::runtime_error("INVALID_DAMPING_DISSIPATION");dissipation+=increment;work+=inner(average_force,du);
        u=std::move(next_u);v=std::move(next_v);a=std::move(next_a);f=std::move(next_force);record(step);math::progress_iteration=step;math::progress_residual=out.max_equilibrium_residual;
    }
    if(out.frames.size()!=o.outputs.size())throw std::runtime_error("INCOMPLETE_DYNAMIC_HISTORY");guard.check();
    out.integration_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();out.linear_iterations=system.iterations+mass_system.iterations;out.max_linear_residual=std::max(system.max_residual,mass_system.max_residual);return out;
}
}
