#include "kernels/structural_solver.hpp"
#include <iostream>
#include <cassert>
int main() {
    namespace s=unicore::structural;
    s::Model m;m.nodes={{0,0,0},{1,0,0},{0,1,0},{0,0,1}};
    s::Tet t{{0,1,2,3},{1000,.25}};auto e=s::element(m,t);
    assert(std::abs(e.volume-1.0/6)<1e-14);
    // Exact affine displacement patch: diagonal extension and engineering shear.
    double u[12];for(int i=0;i<4;++i){auto x=m.nodes[i];u[i*3]=.01*x[0]+.04*x[1];u[i*3+1]=.02*x[1];u[i*3+2]=.03*x[2];}
    double expected[6]={.01,.02,.03,.04,0,0};
    for(int i=0;i<6;++i){double strain=0;for(int j=0;j<12;++j)strain+=e.B[i][j]*u[j];assert(std::abs(strain-expected[i])<1e-14);}
    // All translations and rotations must produce zero element internal force.
    for(int mode=0;mode<6;++mode) {
        double rigid[12]{};
        for(int i=0;i<4;++i){auto x=m.nodes[i];if(mode<3)rigid[3*i+mode]=1;else {s::V axis{};axis[mode-3]=1;auto v=s::cross(axis,x);for(int j=0;j<3;++j)rigid[3*i+j]=v[j];}}
        for(int i=0;i<12;++i){double value=0;for(int j=0;j<12;++j)value+=e.K[i][j]*rigid[j];assert(std::abs(value)<1e-10);}
    }
    bool failed=false;t.material.nu=.5;try{s::element(m,t);}catch(...){failed=true;}assert(failed);
    std::cout<<"Structural affine patch, six rigid modes, material validation passed\n";
}
