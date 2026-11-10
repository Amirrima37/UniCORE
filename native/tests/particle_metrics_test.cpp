#include "kernels/particle_metrics.hpp"
#include <cassert>
int main() {
    unicore::Vec3 positions[] = {{1,0,0}, {0,2,0}}, velocities[] = {{0,2,0}, {3,0,0}};
    float masses[] = {2,4};
    auto result = unicore::reduce(2, [&](std::size_t i){ return positions[i]; }, [&](std::size_t i){ return velocities[i]; }, [&](std::size_t i){return masses[i];});
    assert(result.kinetic_energy == 22);
    assert(result.momentum.x == 12 && result.momentum.y == 4);
    assert(result.angular_momentum.z == -20);
    auto empty = unicore::reduce(0, [&](std::size_t i){return positions[i];}, [&](std::size_t i){return velocities[i];}, [&](std::size_t i){return masses[i];});
    assert(empty.kinetic_energy == 0);
}
