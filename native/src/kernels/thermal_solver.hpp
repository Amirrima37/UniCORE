#pragma once
#include "kernels/structural_solver.hpp"
#include "math/sparse_pcg.hpp"
namespace unicore::thermal {
using V=structural::V;
struct Element {std::array<int,4> nodes;double conductivity,source=0,capacity=0;};
struct Surface {std::array<int,3> nodes;double flux=0,h=0,ambient=0;};
struct Model {std::vector<V>nodes;std::vector<Element>elements;std::vector<Surface>surfaces;std::vector<bool>fixed;std::vector<double>temperature;};
struct Result {std::vector<double>temperature,reaction;std::vector<V>flux;std::vector<std::vector<double>>history;std::vector<double>times;double residual=0,energy_balance=0,heat_input=0,convection_loss=0,storage_rate=0;int iterations=0;};
inline Result solve(const Model &model,const std::atomic<bool>&cancel,double dt=0,int steps=0,double initial=293.15,std::atomic<int>*phase=nullptr){
    if(phase)phase->store(3);
    size_t n=model.nodes.size();if(!n||model.elements.empty()||model.fixed.size()!=n||model.temperature.size()!=n)throw std::runtime_error("INVALID_THERMAL_MODEL");
    bool transient=steps>0;if(transient&&(!std::isfinite(dt)||dt<=0||steps>200||!std::isfinite(initial)||initial<0))throw std::runtime_error("INVALID_TIME_SETTINGS");
    math::Sparse stiffness(n);std::vector<double>force(n,0),capacity(n,0);std::vector<std::array<V,4>>gradients;double total_input=0;
    structural::Model geometry;geometry.nodes=model.nodes;
    for(auto &element:model.elements){
        if(cancel.load())throw std::runtime_error("CANCELLED");
        if(!std::isfinite(element.conductivity)||element.conductivity<=0||!std::isfinite(element.source)||!std::isfinite(element.capacity)||(transient&&element.capacity<=0))throw std::runtime_error("INVALID_THERMAL_MATERIAL");
        structural::Tet tet{element.nodes,{1,0}};auto local=structural::element(geometry,tet);std::array<V,4>g;
        for(int i=0;i<4;++i)g[i]={local.B[0][3*i],local.B[1][3*i+1],local.B[2][3*i+2]};gradients.push_back(g);
        for(int i=0;i<4;++i){int a=element.nodes[i];force[a]+=element.source*local.volume/4;capacity[a]+=element.capacity*local.volume/4;for(int j=0;j<4;++j)stiffness[a][element.nodes[j]]+=element.conductivity*local.volume*structural::dot(g[i],g[j]);}
        total_input+=element.source*local.volume;
    }
    double conv_sum=0;
    for(auto &surface:model.surfaces){
        for(int id:surface.nodes)if(id<0||size_t(id)>=n)throw std::runtime_error("INVALID_THERMAL_SURFACE");
        if(!std::isfinite(surface.flux)||!std::isfinite(surface.h)||surface.h<0||!std::isfinite(surface.ambient)||surface.ambient<0)throw std::runtime_error("INVALID_THERMAL_BOUNDARY");
        auto a=model.nodes[surface.nodes[0]],b=model.nodes[surface.nodes[1]],c=model.nodes[surface.nodes[2]];auto normal=structural::cross(structural::sub(b,a),structural::sub(c,a));double area=std::sqrt(structural::dot(normal,normal))/2;if(area<=0)throw std::runtime_error("DEGENERATE_THERMAL_SURFACE");
        for(int i=0;i<3;++i){int id=surface.nodes[i];force[id]+=(surface.flux+surface.h*surface.ambient)*area/3;for(int j=0;j<3;++j)stiffness[id][surface.nodes[j]]+=surface.h*area*(i==j?2:1)/12;}
        total_input+=surface.flux*area;conv_sum+=surface.h*area;
    }
    if(!transient&&std::count(model.fixed.begin(),model.fixed.end(),true)==0&&conv_sum<=0)throw std::runtime_error("THERMAL_REFERENCE_TEMPERATURE_REQUIRED");
    Result out;out.heat_input=total_input;std::vector<double>previous(n,initial);
    if(transient){out.history.push_back(previous);out.times.push_back(0);}
    for(int step=0;step<(transient?steps:1);++step){
        auto matrix=stiffness;auto rhs=force;
        if(transient)for(size_t i=0;i<n;++i){matrix[i][int(i)]+=capacity[i]/dt;rhs[i]+=capacity[i]*previous[i]/dt;}
        if(phase)phase->store(4);
        auto linear=math::pcg(matrix,rhs,model.fixed,model.temperature,cancel);out.temperature=std::move(linear.x);out.reaction=std::move(linear.reaction);out.residual=linear.residual;out.iterations+=linear.iterations;
        out.storage_rate=0;if(transient)for(size_t i=0;i<n;++i)out.storage_rate+=capacity[i]*(out.temperature[i]-previous[i])/dt;
        previous=out.temperature;
        if(transient&&((step+1)%std::max(1,steps/40)==0||step+1==steps)){out.history.push_back(out.temperature);out.times.push_back((step+1)*dt);}
    }
    if(phase)phase->store(5);
    for(size_t e=0;e<model.elements.size();++e){V q{};for(int i=0;i<4;++i)for(int j=0;j<3;++j)q[j]-=model.elements[e].conductivity*gradients[e][i][j]*out.temperature[model.elements[e].nodes[i]];out.flux.push_back(q);}
    for(auto &surface:model.surfaces)if(surface.h>0){auto a=model.nodes[surface.nodes[0]],b=model.nodes[surface.nodes[1]],c=model.nodes[surface.nodes[2]];auto normal=structural::cross(structural::sub(b,a),structural::sub(c,a));double area=std::sqrt(structural::dot(normal,normal))/2;double mean=0;for(int id:surface.nodes)mean+=out.temperature[id]/3;out.convection_loss+=surface.h*area*(mean-surface.ambient);}
    double reaction=0;for(double value:out.reaction)reaction+=value;out.energy_balance=reaction+out.heat_input-out.convection_loss-out.storage_rate;return out;
}
}
