#include "kernels/geometry_metrics.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
int main(){
 using namespace unicore::geometry;constexpr double pi=3.14159265358979323846;
 auto near=[](double a,double b){assert(std::abs(a-b)<1e-10*std::max(1.0,std::abs(b)));};
 auto b=measure(Kind::Box,{2,3,4},0,2);near(b.volume,24);near(b.area,52);near(b.mass,48);near(b.inertia[0],100);near(b.inertia[1],80);near(b.inertia[2],52);
 auto c=measure(Kind::Cylinder,{2,3,2},0,2);near(c.volume,3*pi);near(c.area,8*pi);near(c.inertia[1],3*pi);near(c.inertia[0],6*pi);
 auto p=measure(Kind::Pipe,{2,3,2},1,2);near(p.volume,2.25*pi);near(p.area,10.5*pi);near(p.inertia[1],p.mass*.625);
 auto s=measure(Kind::Sphere,{2,2,2},0,1);near(s.volume,4*pi/3);near(s.area,4*pi);near(s.inertia[0],s.mass*.4);
 bool rejected=false;try{measure(Kind::Pipe,{2,3,2},3,1);}catch(...){rejected=true;}assert(rejected);
 rejected=false;try{measure(Kind::Box,{1,1,1},0,-1);}catch(...){rejected=true;}assert(rejected);
 std::cout<<"Analytical primitive volumes, areas, masses, centroid inertia and invalid inputs passed\n";
}
