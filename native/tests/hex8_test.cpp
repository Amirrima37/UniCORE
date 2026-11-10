#include "kernels/structural_solver.hpp"
#include <cassert>
#include <iostream>
int main(){namespace s=unicore::structural;s::Model m;m.nodes={{-.5,-.5,-.5},{.5,-.5,-.5},{.5,.5,-.5},{-.5,.5,-.5},{-.5,-.5,.5},{.5,-.5,.5},{.5,.5,.5},{-.5,.5,.5}};s::Cell cell{{0,1,2,3,4,5,6,7},{1000,.25}};auto e=s::integrate(m,cell);assert(std::abs(e.volume-1)<1e-13);assert(std::abs(e.min_jacobian-.125)<1e-13);
 for(int i=0;i<24;++i)for(int j=0;j<24;++j)assert(std::abs(e.K[i*24+j]-e.K[j*24+i])<1e-10);
 for(int mode=0;mode<6;++mode){double u[24]{};for(int i=0;i<8;++i){if(mode<3)u[3*i+mode]=1;else{s::V axis{};axis[mode-3]=1;auto v=s::cross(axis,m.nodes[i]);for(int j=0;j<3;++j)u[3*i+j]=v[j];}}for(int i=0;i<24;++i){double value=0;for(int j=0;j<24;++j)value+=e.K[i*24+j]*u[j];assert(std::abs(value)<1e-10);}}
 double u[24];for(int i=0;i<8;++i){auto x=m.nodes[i];u[3*i]=.01*x[0]+.04*x[1];u[3*i+1]=.02*x[1];u[3*i+2]=.03*x[2];}double expected[6]={.01,.02,.03,.04,0,0};for(int i=0;i<6;++i){double value=0;for(int j=0;j<24;++j)value+=e.B[i*24+j]*u[j];assert(std::abs(value-expected[i])<1e-14);}
 auto eigen=s::principal_stresses({0,0,0,12,0,0});assert(std::abs(eigen[0]-12)<1e-12&&std::abs(eigen[1])<1e-12&&std::abs(eigen[2]+12)<1e-12);
 m.hexes.push_back({{0,1,2,3,4,5,6,7},{1000,.25}});m.force.resize(24,0);m.fixed.resize(24,false);m.fixed[0]=m.fixed[1]=m.fixed[2]=true;m.fixed[3]=m.fixed[4]=m.fixed[5]=true;bool failed=false;try{s::solve(m,std::atomic<bool>{false});}catch(...){failed=true;}assert(failed);
 std::swap(cell.nodes[0],cell.nodes[6]);failed=false;try{s::integrate(m,cell);}catch(...){failed=true;}assert(failed);
 std::cout<<"HEX8 volume, Gauss integration, stiffness symmetry, six rigid modes, affine strain, principal stress and invalid mesh/support tests passed\n";
}
