#pragma once
#include "kernels/structural_solver.hpp"
#include "math/sparse_pcg.hpp"
#include <functional>
namespace unicore::thermal {
using V=structural::V;
struct Element {std::array<int,4> nodes;double conductivity,source=0,capacity=0;};
struct Surface {std::array<int,3> nodes;double flux=0,h=0,ambient=0,emissivity=0,surroundings=293.15;};
struct Model {std::vector<V>nodes;std::vector<Element>elements;std::vector<Surface>surfaces;std::vector<bool>fixed;std::vector<double>temperature;};
struct Result { math::LinearResult linear_diagnostics;double assembly_ms=0,solve_ms=0,post_ms=0;std::vector<double>temperature,reaction;std::vector<V>flux;std::vector<std::vector<V>>flux_history;std::vector<std::vector<double>>radiation_history;std::vector<std::vector<double>>history;std::vector<double>times;std::vector<double>radiation_flux,radiation_power,nonlinear_residual_history;double radiation_loss=0;int nonlinear_iterations=0;double residual=0,energy_balance=0,heat_input=0,convection_loss=0,storage_rate=0;int iterations=0;};
constexpr double stefan_boltzmann=5.670374419e-8;
// Degree-five triangle rule: exact for Ni*T^4 and Ni*Nj*4*T^3 on linear faces.
inline void radiation(const Model&m,const std::vector<double>&t,std::vector<double>&r,math::Sparse*jac=nullptr,std::vector<double>*power=nullptr){
    const double a=.059715871789770,b=.470142064105115,c=.797426985353087,d=.101286507323456;
    const double bary[7][3]={{1./3,1./3,1./3},{a,b,b},{b,a,b},{b,b,a},{c,d,d},{d,c,d},{d,d,c}};
    const double w[7]={.225,.132394152788506,.132394152788506,.132394152788506,.125939180544827,.125939180544827,.125939180544827};
    if(power)power->assign(m.surfaces.size(),0);
    for(size_t s=0;s<m.surfaces.size();++s){auto &f=m.surfaces[s];if(f.emissivity==0)continue;
        auto n=structural::cross(structural::sub(m.nodes[f.nodes[1]],m.nodes[f.nodes[0]]),structural::sub(m.nodes[f.nodes[2]],m.nodes[f.nodes[0]]));double area=std::sqrt(structural::dot(n,n))/2;
        for(int q=0;q<7;++q){double temp=0;for(int i=0;i<3;++i)temp+=bary[q][i]*t[f.nodes[i]];
            double value=f.emissivity*stefan_boltzmann*(std::pow(temp,4)-std::pow(f.surroundings,4));
            if(!std::isfinite(value)||temp<0)throw std::runtime_error("INVALID_RADIATION_TEMPERATURE");
            if(power)(*power)[s]+=area*w[q]*value;
            for(int i=0;i<3;++i){r[f.nodes[i]]+=area*w[q]*bary[q][i]*value;
                if(jac)for(int j=0;j<3;++j)(*jac)[f.nodes[i]][f.nodes[j]]+=area*w[q]*bary[q][i]*bary[q][j]*4*f.emissivity*stefan_boltzmann*std::pow(temp,3);
            }
        }
    }
}
inline Result solve(const Model &model,const std::atomic<bool>&cancel,double dt=0,int steps=0,double initial=293.15,std::atomic<int>*phase=nullptr,const std::vector<double>*restart=nullptr,double initial_time=0,std::function<void(int,const std::vector<double>&)> checkpoint={}){
    auto start=std::chrono::steady_clock::now();
    if(phase)phase->store(3);
    size_t n=model.nodes.size();if(!n||model.elements.empty()||model.fixed.size()!=n||model.temperature.size()!=n)throw std::runtime_error("INVALID_THERMAL_MODEL");
    if(!std::isfinite(initial)||initial<0)throw std::runtime_error("INVALID_INITIAL_KELVIN");
    bool transient=steps>0;if(transient&&(!std::isfinite(dt)||dt<=0||steps>200||!std::isfinite(initial)||initial<0))throw std::runtime_error("INVALID_TIME_SETTINGS");
    math::Sparse stiffness(n);std::vector<double>force(n,0),capacity(n,0);std::vector<std::array<V,4>>gradients;double total_input=0;
    structural::Model geometry;geometry.nodes=model.nodes;
    gradients.resize(model.elements.size());
    struct Prepared {double volume;std::array<V,4>g;};
    const size_t batch=math::serial_assembly?256:2048;
    for(size_t begin=0;begin<model.elements.size();begin+=batch){size_t count=std::min(batch,model.elements.size()-begin);std::vector<Prepared>prepared(count);
    math::parallel_for(count,[&](size_t index){auto &element=model.elements[begin+index];
        if(cancel.load())throw std::runtime_error("CANCELLED");
        if(!std::isfinite(element.conductivity)||element.conductivity<=0||!std::isfinite(element.source)||!std::isfinite(element.capacity)||(transient&&element.capacity<=0))throw std::runtime_error("INVALID_THERMAL_MATERIAL");
        structural::Tet tet{element.nodes,{1,0}};auto local=structural::element(geometry,tet);std::array<V,4>g;
        for(int i=0;i<4;++i)g[i]={local.B[0][3*i],local.B[1][3*i+1],local.B[2][3*i+2]};prepared[index]={local.volume,g};
    },cancel);
    math::nodal_scatter(count,[](size_t){return 4;},[&](size_t e,int i){return model.elements[begin+e].nodes[i];},
        [&](size_t index,int i,int a){const auto &element=model.elements[begin+index];const auto &g=prepared[index].g;double volume=prepared[index].volume;
            force[a]+=element.source*volume/4;capacity[a]+=element.capacity*volume/4;
            for(int j=0;j<4;++j)stiffness[a][element.nodes[j]]+=element.conductivity*volume*structural::dot(g[i],g[j]);
        },cancel);
    for(size_t index=0;index<count;++index){gradients[begin+index]=prepared[index].g;total_input+=model.elements[begin+index].source*prepared[index].volume;}
    }
    double conv_sum=0;bool nonlinear=false;
    for(auto &surface:model.surfaces){
        if(!std::isfinite(surface.emissivity)||surface.emissivity<0||surface.emissivity>1||!std::isfinite(surface.surroundings)||surface.surroundings<0)throw std::runtime_error("INVALID_RADIATION_BOUNDARY");
        nonlinear|=surface.emissivity>0;
        for(int id:surface.nodes)if(id<0||size_t(id)>=n)throw std::runtime_error("INVALID_THERMAL_SURFACE");
        if(!std::isfinite(surface.flux)||!std::isfinite(surface.h)||surface.h<0||!std::isfinite(surface.ambient)||surface.ambient<0)throw std::runtime_error("INVALID_THERMAL_BOUNDARY");
        auto a=model.nodes[surface.nodes[0]],b=model.nodes[surface.nodes[1]],c=model.nodes[surface.nodes[2]];auto normal=structural::cross(structural::sub(b,a),structural::sub(c,a));double area=std::sqrt(structural::dot(normal,normal))/2;if(area<=0)throw std::runtime_error("DEGENERATE_THERMAL_SURFACE");
        for(int i=0;i<3;++i){int id=surface.nodes[i];force[id]+=(surface.flux+surface.h*surface.ambient)*area/3;for(int j=0;j<3;++j)stiffness[id][surface.nodes[j]]+=surface.h*area*(i==j?2:1)/12;}
        total_input+=surface.flux*area;conv_sum+=(surface.h+surface.emissivity)*area;
    }
    if(!transient&&std::count(model.fixed.begin(),model.fixed.end(),true)==0&&conv_sum<=0)throw std::runtime_error("THERMAL_REFERENCE_TEMPERATURE_REQUIRED");
    Result out;out.heat_input=total_input;std::vector<double>previous=restart?*restart:std::vector<double>(n,initial);if(previous.size()!=n)throw std::runtime_error("INVALID_RESTART_SIZE");for(double t:previous)if(!std::isfinite(t)||t<0)throw std::runtime_error("INVALID_RESTART_KELVIN");
    if(transient){out.history.push_back(previous);out.times.push_back(initial_time);}
    auto assembled=std::chrono::steady_clock::now();
    for(int step=0;step<(transient?steps:1);++step){
        auto matrix=stiffness;auto rhs=force;
        if(transient)for(size_t i=0;i<n;++i){matrix[i][int(i)]+=capacity[i]/dt;rhs[i]+=capacity[i]*previous[i]/dt;}
        if(phase)phase->store(4);
        if(!nonlinear){auto linear=math::pcg(matrix,rhs,model.fixed,model.temperature,cancel);out.temperature=std::move(linear.x);out.reaction=std::move(linear.reaction);out.residual=linear.residual;out.iterations+=linear.iterations;out.linear_diagnostics.preconditioner=linear.preconditioner;out.linear_diagnostics.fallback=linear.fallback;out.linear_diagnostics.preconditioner_ms+=linear.preconditioner_ms;out.linear_diagnostics.pcg_ms+=linear.pcg_ms;out.linear_diagnostics.symmetry_ms+=linear.symmetry_ms;out.linear_diagnostics.preconditioner_bytes=std::max(out.linear_diagnostics.preconditioner_bytes,linear.preconditioner_bytes);out.linear_diagnostics.absolute_residual=linear.absolute_residual;}
        else {
            auto t=previous;if(!transient)for(double &v:t)v=std::max(v,1.0);for(size_t i=0;i<n;++i)if(model.fixed[i])t[i]=model.temperature[i];
            auto residual=[&](const std::vector<double>&x,math::Sparse*jac){std::vector<double>r(n);for(size_t i=0;i<n;++i){long double value=-force[i];for(auto entry:stiffness[i])value+=(long double)entry.second*x[entry.first];if(transient)value+=(long double)capacity[i]*(x[i]-previous[i])/dt;r[i]=double(value);}radiation(model,x,r,jac);return r;};
            auto norm=[&](const std::vector<double>&r){double value=0;for(size_t i=0;i<n;++i)if(!model.fixed[i])value+=r[i]*r[i];return std::sqrt(value);};
            double scale=1;for(double v:force)scale=std::max(scale,std::abs(v));std::vector<double> radiative_scale(n,0);radiation(model,t,radiative_scale);for(double v:radiative_scale)scale=std::max(scale,std::abs(v));bool converged=false;
            for(int it=0;it<60;++it){if(cancel.load())throw std::runtime_error("CANCELLED");auto tangent=matrix;auto r=residual(t,&tangent);double error=norm(r);out.residual=error/scale;out.nonlinear_residual_history.push_back(out.residual);
                if(out.residual<1e-9){converged=true;out.reaction=r;for(size_t i=0;i<n;++i)if(!model.fixed[i])out.reaction[i]=0;break;}
                for(double &v:r)v=-v;auto delta=math::pcg(tangent,r,model.fixed,std::vector<double>(n,0),cancel);out.iterations+=delta.iterations;out.linear_diagnostics.preconditioner=delta.preconditioner;out.linear_diagnostics.fallback=delta.fallback;out.linear_diagnostics.preconditioner_ms+=delta.preconditioner_ms;out.linear_diagnostics.pcg_ms+=delta.pcg_ms;out.linear_diagnostics.symmetry_ms+=delta.symmetry_ms;out.linear_diagnostics.preconditioner_bytes=std::max(out.linear_diagnostics.preconditioner_bytes,delta.preconditioner_bytes);out.linear_diagnostics.absolute_residual=delta.absolute_residual;
                bool accepted=false;double damping=1;
                for(int line=0;line<30;++line){auto trial=t;bool positive=true;for(size_t i=0;i<n;++i){trial[i]+=damping*delta.x[i];positive&=trial[i]>=0&&std::isfinite(trial[i]);}
                    if(positive&&norm(residual(trial,nullptr))<error){t=std::move(trial);accepted=true;break;}damping*=.5;}
                if(!accepted)throw std::runtime_error("RADIATION_LINE_SEARCH_FAILED");++out.nonlinear_iterations;
            }
            if(!converged)throw std::runtime_error("RADIATION_NONCONVERGENCE_60_ITERATIONS");out.temperature=std::move(t);
        }
        out.storage_rate=0;if(transient)for(size_t i=0;i<n;++i)out.storage_rate+=capacity[i]*(out.temperature[i]-previous[i])/dt;
        previous=out.temperature;
        if(transient&&checkpoint)checkpoint(step+1,previous);
        if(transient&&((step+1)%std::max(1,steps/40)==0||step+1==steps)){out.history.push_back(out.temperature);out.times.push_back(initial_time+(step+1)*dt);}
    }
    auto solved=std::chrono::steady_clock::now();
    if(phase)phase->store(5);
    out.flux.resize(model.elements.size());
    math::parallel_for(model.elements.size(),[&](size_t e){V q{};for(int i=0;i<4;++i)for(int j=0;j<3;++j)q[j]-=model.elements[e].conductivity*gradients[e][i][j]*out.temperature[model.elements[e].nodes[i]];out.flux[e]=q;},cancel,20000);
    for(auto &surface:model.surfaces)if(surface.h>0){auto a=model.nodes[surface.nodes[0]],b=model.nodes[surface.nodes[1]],c=model.nodes[surface.nodes[2]];auto normal=structural::cross(structural::sub(b,a),structural::sub(c,a));double area=std::sqrt(structural::dot(normal,normal))/2;double mean=0;for(int id:surface.nodes)mean+=out.temperature[id]/3;out.convection_loss+=surface.h*area*(mean-surface.ambient);}
    std::vector<double>rad(n,0);radiation(model,out.temperature,rad,nullptr,&out.radiation_power);
    for(size_t s=0;s<model.surfaces.size();++s){auto &f=model.surfaces[s];auto normal=structural::cross(structural::sub(model.nodes[f.nodes[1]],model.nodes[f.nodes[0]]),structural::sub(model.nodes[f.nodes[2]],model.nodes[f.nodes[0]]));double area=std::sqrt(structural::dot(normal,normal))/2;out.radiation_flux.push_back(out.radiation_power[s]/area);out.radiation_loss+=out.radiation_power[s];}
    for(auto &frame:out.history){std::vector<V>vectors(model.elements.size());math::parallel_for(model.elements.size(),[&](size_t e){V q{};for(int i=0;i<4;++i)for(int j=0;j<3;++j)q[j]-=model.elements[e].conductivity*gradients[e][i][j]*frame[model.elements[e].nodes[i]];vectors[e]=q;},cancel,20000);out.flux_history.push_back(std::move(vectors));
        std::vector<double>load(n,0),power,values;radiation(model,frame,load,nullptr,&power);for(size_t s=0;s<model.surfaces.size();++s){auto &f=model.surfaces[s];auto normal=structural::cross(structural::sub(model.nodes[f.nodes[1]],model.nodes[f.nodes[0]]),structural::sub(model.nodes[f.nodes[2]],model.nodes[f.nodes[0]]));values.push_back(power[s]/(std::sqrt(structural::dot(normal,normal))/2));}out.radiation_history.push_back(std::move(values));
    }
    double reaction=0;for(double value:out.reaction)reaction+=value;out.energy_balance=reaction+out.heat_input-out.convection_loss-out.radiation_loss-out.storage_rate;out.assembly_ms=std::chrono::duration<double,std::milli>(assembled-start).count();out.solve_ms=std::chrono::duration<double,std::milli>(solved-assembled).count();out.post_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-solved).count();return out;
}
}
