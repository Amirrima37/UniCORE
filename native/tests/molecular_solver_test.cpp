#include "kernels/molecular_solver.hpp"
#include <cassert>
#include <limits>
#include <cmath>
int main() {
    unicore::MolecularSolver solver;
    solver.config.thermostat_enabled=false;
    solver.config.radius=0;
    std::vector<unicore::Vec3> forces; double potential;
    assert(solver.evaluate({{0,0,0},{1,0,0}},forces,potential));
    assert(forces[0].x==-24 && forces[1].x==24); // independent LJ derivative at r=sigma
    assert(solver.evaluate({{0,0,0},{2.5,0,0}},forces,potential));
    assert(forces[0].x==0 && potential==0); // strict cutoff
    assert(solver.evaluate({{0,0,0},{0,0,0}},forces,potential));
    assert(forces[0].length_squared()==0 && std::isfinite(potential));
    solver.state.positions={{-1,0,0},{1,0,0}};
    solver.state.velocities={{0,0.1f,0},{0,-0.1f,0}};
    solver.state.masses={1,1};
    assert(solver.advance(0.001,100));
    auto checkpoint=solver;
    assert(solver.advance(0.001,100));
    auto future=solver.state;
    solver=checkpoint;
    assert(solver.advance(0.001,100));
    assert(solver.state.positions[0].x==future.positions[0].x);
    auto before=solver.state;
    assert(!solver.advance(std::numeric_limits<double>::quiet_NaN(),1));
    assert(solver.state.positions[0].x==before.positions[0].x && solver.state.tick==before.tick);
    // Repeated construction/destruction and independent per-instance state.
    for(int repeat=0;repeat<1000;++repeat) {
        auto independent=checkpoint;
        assert(independent.advance(0.001,1));
        assert(checkpoint.state.tick==100);
    }
}
