#pragma once
#include <array>
#include <cmath>
#include <stdexcept>
namespace unicore::geometry {
enum class Kind {Box,Cylinder,Sphere,Pipe};
struct Metrics {double volume,area,mass;std::array<double,3> inertia;};
inline Metrics measure(Kind kind,std::array<double,3> d,double inner,double density) {
    for(double x:d)if(!std::isfinite(x)||x<=0)throw std::runtime_error("INVALID_DIMENSIONS");
    if(!std::isfinite(density)||density<=0)throw std::runtime_error("INVALID_DENSITY");
    constexpr double pi=3.14159265358979323846;
    Metrics out{};
    double x=d[0],h=d[1],z=d[2],r=x/2;
    if(kind==Kind::Box) {
        out.volume=x*h*z;out.area=2*(x*h+x*z+h*z);out.mass=out.volume*density;
        out.inertia={out.mass*(h*h+z*z)/12,out.mass*(x*x+z*z)/12,out.mass*(x*x+h*h)/12};
    } else if(kind==Kind::Sphere) {
        out.volume=4*pi*r*r*r/3;out.area=4*pi*r*r;out.mass=out.volume*density;
        out.inertia.fill(2*out.mass*r*r/5);
    } else {
        double ri=kind==Kind::Pipe ? inner/2 : 0;
        if(!std::isfinite(ri)||ri<0||ri>=r||(kind==Kind::Pipe&&ri<=0))throw std::runtime_error("INVALID_PIPE_WALL");
        out.volume=pi*(r*r-ri*ri)*h;out.area=2*pi*((r+ri)*h+r*r-ri*ri);out.mass=out.volume*density;
        double radial=r*r+ri*ri;out.inertia={out.mass*(3*radial+h*h)/12,out.mass*radial/2,out.mass*(3*radial+h*h)/12};
    }
    if(!std::isfinite(out.volume)||!std::isfinite(out.area)||!std::isfinite(out.mass))throw std::runtime_error("NUMERICAL_OVERFLOW");
    for(double v:out.inertia)if(!std::isfinite(v))throw std::runtime_error("NUMERICAL_OVERFLOW");
    return out;
}
}
