#include "kernels/gravity_solver.hpp"
#include "kernels/quantum_solver.hpp"
#include "kernels/nuclear_solver.hpp"
#include <cassert>
int main(){
 unicore::GravitySolver gravity;gravity.config.relativity=false;gravity.config.theta=0;gravity.state.positions={{-1,0,0},{1,0,0}};gravity.state.velocities={{0,0,0},{0,0,0}};gravity.state.masses={1,2};
 std::vector<unicore::Vec3> forces;double energy;assert(gravity.evaluate_state(gravity.state,forces,energy));double denominator=4+0.05*0.05;double expected=4/std::pow(denominator,1.5);assert(std::abs(forces[0].x-expected)<1e-6);assert(std::abs(forces[0].x+forces[1].x)<1e-6);assert(std::abs(energy+2/std::sqrt(denominator))<1e-6);
 unicore::QuantumSolver wave;wave.grid_size_1d=17;wave.domain_length_1d=4;wave.psi_real_1d.resize(17);wave.psi_imag_1d.resize(17);wave.potential_1d.resize(17);wave.prob_density_1d.resize(17);double pi=std::acos(-1.0),dx=4.0/16;
 for(int i=0;i<17;++i)wave.psi_real_1d[i]=std::sqrt(0.5)*std::sin(pi*i/16);wave._update_prob_density_1d();assert(wave.advance(0.001,1000));double eigenvalue=(1-std::cos(pi/16))/(dx*dx),phase=-2000*std::atan(eigenvalue*0.001/2);assert(std::abs(double(wave.psi_real_1d[8])-std::sqrt(0.5)*std::cos(phase))<0.0003);assert(std::abs(double(wave.psi_imag_1d[8])-std::sqrt(0.5)*std::sin(phase))<0.0003);assert(std::abs(wave.compute_norm()-1)<0.0003);
 unicore::NuclearSolver nuclear;nuclear.radius=1000;unicore::Isotope parent;parent.mass=10;parent.half=1;parent.channel=1;parent.daughter="D";parent.symbol="P";nuclear.isotopes["P"]=parent;unicore::Isotope daughter;daughter.mass=5;nuclear.isotopes["D"]=daughter;unicore::Isotope alpha;alpha.mass=4;nuclear.isotopes["He-4"]=alpha;
 nuclear.nuclei.push_back({{0,0,0},{0,0,0},10,1,1,1,"P"});nuclear.active_nuclei=1;int draws=0;nuclear.random=[&](){++draws;return 0.25;};nuclear.random_range=[&](double a,double b){++draws;return a+(b-a)*0.25;};assert(nuclear.advance(1));assert(nuclear.total_decays==1&&nuclear.radiation.size()==1&&draws==3);assert(std::abs(nuclear.energy()-25000)<0.025);assert(std::sqrt(nuclear.momentum().length_squared())<0.0001);assert(nuclear.events[0].energy==2500);
 int before=draws;assert(!nuclear.advance(NAN));assert(draws==before);
}
