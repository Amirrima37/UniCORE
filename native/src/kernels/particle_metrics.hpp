#pragma once
#include <cstddef>
namespace unicore {
// No engine dependencies. Vector operations intentionally round to float like Godot's single precision Vector3.
struct Vec3 {
    float x = 0, y = 0, z = 0;
    Vec3 scaled(float m) const { return {x*m, y*m, z*m}; }
    Vec3 cross(Vec3 p) const { return {y*p.z-z*p.y, z*p.x-x*p.z, x*p.y-y*p.x}; }
    void add(Vec3 p) { x += p.x; y += p.y; z += p.z; }
    float length_squared() const { return x*x+y*y+z*z; }
};
struct Metrics { double kinetic_energy = 0; Vec3 momentum, angular_momentum; };
template<class Position, class Velocity, class Mass>
Metrics reduce(std::size_t count, Position position, Velocity velocity, Mass mass) {
    Metrics result;
    for (std::size_t i = 0; i < count; ++i) {
        const double m = mass(i);
        const Vec3 v = velocity(i), r = position(i), p = v.scaled(static_cast<float>(m));
        result.kinetic_energy += 0.5*m*v.length_squared();
        result.momentum.add(p);
        result.angular_momentum.add(r.cross(p));
    }
    return result;
}
}
