#pragma once
#include "particle_metrics.hpp"
#include <vector>
#include <unordered_map>
#include <array>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
namespace unicore {
inline Vec3 plus(Vec3 a, Vec3 b) { return {a.x+b.x,a.y+b.y,a.z+b.z}; }
inline Vec3 minus(Vec3 a, Vec3 b) { return {a.x-b.x,a.y-b.y,a.z-b.z}; }
inline bool finite(Vec3 v) { return std::isfinite(v.x)&&std::isfinite(v.y)&&std::isfinite(v.z); }
struct MolecularConfig {
    double sigma=1, epsilon=1, cutoff=2.5, radius=0.2, restitution=1;
    double target_temperature=1, thermostat_tau=0.2, boltzmann_constant=1;
    Vec3 box={10,10,10};
    bool thermostat_enabled=true;
    bool valid() const {
        const double values[]={sigma,epsilon,cutoff,radius,restitution,target_temperature,thermostat_tau,boltzmann_constant};
        for (auto value:values) if (!std::isfinite(value)) return false;
        return sigma>0 && cutoff>1e-6 && radius>=0 && finite(box) &&
            box.x>radius && box.y>radius && box.z>radius &&
            std::isfinite(sigma*sigma) && std::isfinite(cutoff*cutoff);
    }
};
struct MolecularState {
    std::vector<Vec3> positions, velocities, forces;
    std::vector<float> masses;
    uint64_t tick=0;
};
using Cell=std::array<int64_t,3>;
struct CellHash {
    size_t operator()(const Cell &c) const {
        return (uint64_t(c[0])*73856093u)^(uint64_t(c[1])*19349663u)^(uint64_t(c[2])*83492791u);
    }
};
class MolecularSolver {
    using Grid=std::unordered_map<Cell,std::vector<size_t>,CellHash>;
    bool position_valid(Vec3 v) const {
        // Bound coordinate conversion well inside int64; invalid states never reach the grid.
        return finite(v) && std::abs(double(v.x)/config.cutoff)<1e12 &&
            std::abs(double(v.y)/config.cutoff)<1e12 && std::abs(double(v.z)/config.cutoff)<1e12;
    }
public:
    MolecularConfig config;
    MolecularState state;
    bool valid_state(const MolecularState &s) const {
        if (s.positions.size()!=s.velocities.size() || s.positions.size()!=s.masses.size()) return false;
        for (size_t i=0;i<s.positions.size();++i)
            if (!position_valid(s.positions[i]) || !finite(s.velocities[i]) || !std::isfinite(s.masses[i])) return false;
        return true;
    }
    bool evaluate(const std::vector<Vec3> &positions, std::vector<Vec3> &forces, double &potential) const {
        if (!config.valid()) return false;
        const size_t n=positions.size();
        forces.assign(n,{}); potential=0;
        Grid grid;
        grid.reserve(n);
        const double inverse=1.0/config.cutoff;
        for(size_t i=0;i<n;++i) {
            const auto p=positions[i];
            if (!position_valid(p)) return false;
            grid[{int64_t(std::floor(p.x*inverse)),int64_t(std::floor(p.y*inverse)),int64_t(std::floor(p.z*inverse))}].push_back(i);
        }
        const double sig2=config.sigma*config.sigma, rc2=config.cutoff*config.cutoff;
        const double shift2=sig2/rc2, shift6=shift2*shift2*shift2;
        const double shift=4.0*config.epsilon*(shift6*shift6-shift6);
        std::vector<size_t> neighbors;
        for(size_t i=0;i<n;++i) {
            neighbors.clear(); const auto p=positions[i];
            const int64_t xmin=std::floor((double(p.x)-config.cutoff)*inverse), xmax=std::floor((double(p.x)+config.cutoff)*inverse);
            const int64_t ymin=std::floor((double(p.y)-config.cutoff)*inverse), ymax=std::floor((double(p.y)+config.cutoff)*inverse);
            const int64_t zmin=std::floor((double(p.z)-config.cutoff)*inverse), zmax=std::floor((double(p.z)+config.cutoff)*inverse);
            for(auto x=xmin;x<=xmax;++x) for(auto y=ymin;y<=ymax;++y) for(auto z=zmin;z<=zmax;++z) {
                const auto bucket=grid.find({x,y,z});
                if(bucket==grid.end()) continue;
                for(auto j:bucket->second) if(j>i && minus(p,positions[j]).length_squared()<rc2) neighbors.push_back(j);
            }
            // Match SpatialHashGrid's sorted neighbors and the reference's accumulation order.
            std::sort(neighbors.begin(),neighbors.end());
            for(auto j:neighbors) {
                const auto r=minus(p,positions[j]);
                const double r2=std::max(double(r.length_squared()),0.04*sig2);
                const double inv=1.0/r2, sr2=sig2*inv, sr6=sr2*sr2*sr2, sr12=sr6*sr6;
                const auto force=r.scaled(float(24.0*config.epsilon*inv*(2.0*sr12-sr6)));
                forces[i].add(force); forces[j]=minus(forces[j],force);
                potential+=4.0*config.epsilon*(sr12-sr6)-shift;
            }
        }
        if(!std::isfinite(potential)) return false;
        for(auto force:forces) if(!finite(force)) return false;
        return true;
    }
    double temperature(const MolecularState &s) const {
        if(s.velocities.empty()) return 0;
        double kinetic=0;
        for(size_t i=0;i<s.velocities.size();++i) kinetic+=0.5*double(s.masses[i])*s.velocities[i].length_squared();
        const double kb=config.boltzmann_constant>0?config.boltzmann_constant:1.0;
        return 2.0*kinetic/(3.0*double(s.velocities.size())*kb);
    }
    bool advance(double dt,int substeps) {
        if(!std::isfinite(dt)||dt<=0||substeps<1||substeps>10000||!config.valid()||!valid_state(state)) return false;
        // Atomic commit: failed stages never expose half an integration to Godot.
        if(state.tick>uint64_t(std::numeric_limits<int64_t>::max())-uint64_t(substeps)) return false;
        auto next=state;
        std::vector<Vec3> a0(next.positions.size());
        for(int step=0;step<substeps;++step) {
            if(dt>=1e-5 && !next.positions.empty()) {
                double ignored;
                if(!evaluate(next.positions,next.forces,ignored)) return false;
                for(size_t i=0;i<next.positions.size();++i) {
                    const double inverse=1.0/std::max(double(next.masses[i]),1e-12);
                    a0[i]=next.forces[i].scaled(float(inverse));
                    next.positions[i].add(plus(next.velocities[i].scaled(float(dt)),a0[i].scaled(float(0.5*dt*dt))));
                }
                if(!evaluate(next.positions,next.forces,ignored)) return false;
                for(size_t i=0;i<next.velocities.size();++i) {
                    const auto a1=next.forces[i].scaled(float(1.0/std::max(double(next.masses[i]),1e-12)));
                    next.velocities[i].add(plus(a0[i],a1).scaled(float(0.5*dt)));
                }
            }
            const auto box=minus(config.box,{float(config.radius),float(config.radius),float(config.radius)});
            const double e=std::clamp(config.restitution,0.0,1.0);
            for(size_t i=0;i<next.positions.size();++i) {
                auto &p=next.positions[i]; auto &v=next.velocities[i];
                auto reflect=[&](float &x,float &velocity,float b) {
                    if(x>b) { x=float(double(b)-(double(x)-b)*e); velocity=float(-double(velocity)*e); }
                    else if(x<-b) { x=float(-double(b)+(-double(b)-x)*e); velocity=float(-double(velocity)*e); }
                    x=std::clamp(x,-b,b);
                };
                reflect(p.x,v.x,box.x); reflect(p.y,v.y,box.y); reflect(p.z,v.z,box.z);
            }
            if(config.thermostat_enabled&&!next.velocities.empty()) {
                const double t=std::max(temperature(next),1e-9), tau=std::max(config.thermostat_tau,1e-4);
                const double factor=1.0+(dt/tau)*((config.target_temperature/t)-1.0);
                const double scale=std::clamp(std::sqrt(std::max(factor,0.0)),0.5,2.0);
                for(auto &v:next.velocities) v=v.scaled(float(scale));
            }
            if(!valid_state(next)) return false;
            ++next.tick;
        }
        state=std::move(next); return true;
    }
};
}
