#include "kernels/thermal_solver.hpp"
#include <iostream>
#ifdef _OPENMP
#include <omp.h>
#endif
int main(int argc,char**argv){
 if(argc>1&&std::string(argv[1])=="--serial")unicore::math::serial_assembly=true;
 namespace s=unicore::structural;namespace m=unicore::math;
 s::Model model;model.nodes={{0,0,0},{1,0,0},{1,1,0},{0,1,0},{0,0,1},{1,0,1},{1,1,1},{0,1,1}};
 auto cube=model.nodes;for(int k=1;k<64;++k)for(auto v:cube){v[0]+=2*k;model.nodes.push_back(v);}
 std::vector<s::Cell> cells;
 for(int i=0;i<2048;++i)cells.push_back(i%2?s::Cell{{0,1,3,4},{1000.+i,.25}}:s::Cell{{0,1,2,3,4,5,6,7},{1000.+i,.3}});
 for(size_t k=0;k<cells.size();++k)for(auto&id:cells[k].nodes)id+=8*(k%64);
 std::vector<s::Local> local;for(auto&c:cells)local.push_back(s::integrate(model,c));
 m::Sparse reference(model.nodes.size()*3);
 for(size_t k=0;k<cells.size();++k){auto&e=local[k];auto&t=cells[k];for(int i=0;i<e.n;++i)for(int j=0;j<e.n;++j)reference[t.nodes[i/3]*3+i%3][t.nodes[j/3]*3+j%3]+=e.K[i*e.n+j];}
 std::atomic<bool>cancel{false};
 for(int threads:{1,2,4,6,8,12}){
 #ifdef _OPENMP
 omp_set_num_threads(threads);
 #endif
 for(int repeat=0;repeat<10;++repeat){m::Sparse actual(model.nodes.size()*3);
 m::nodal_scatter(cells.size(),[&](size_t k){return int(cells[k].nodes.size());},[&](size_t k,int i){return cells[k].nodes[i];},[&](size_t k,int node,int global){auto&e=local[k];auto&t=cells[k];for(int axis=0;axis<3;++axis){int i=3*node+axis;for(int j=0;j<e.n;++j)actual[3*global+axis][3*t.nodes[j/3]+j%3]+=e.K[i*e.n+j];}},cancel);
 if(actual!=reference)throw std::runtime_error("MATRIX_MISMATCH");
 }
 }
 // Thermal TET4 matrix, volumetric source and capacity: heterogeneous cells.
 struct ThermalLocal {std::array<int,4>nodes;double k[16],f,c;};
 std::vector<ThermalLocal> thermal;
 for(int e=0;e<2048;++e){int base=8*(e%64);s::Tet tet{{base,base+1,base+3,base+4},{1,0}};auto v=s::element(model,tet);ThermalLocal t;t.nodes=tet.nodes;t.f=(e-100)*v.volume/4;t.c=(1000.+e)*v.volume/4;
 for(int i=0;i<4;++i)for(int j=0;j<4;++j){s::V a{v.B[0][3*i],v.B[1][3*i+1],v.B[2][3*i+2]},b{v.B[0][3*j],v.B[1][3*j+1],v.B[2][3*j+2]};t.k[4*i+j]=(1.+e)*v.volume*s::dot(a,b);}thermal.push_back(t);}
 m::Sparse thermal_reference(model.nodes.size());std::vector<double>rf(model.nodes.size()),rc(model.nodes.size());
 for(auto&t:thermal)for(int i=0;i<4;++i){int a=t.nodes[i];rf[a]+=t.f;rc[a]+=t.c;for(int j=0;j<4;++j)thermal_reference[a][t.nodes[j]]+=t.k[4*i+j];}
 for(int threads:{1,2,4,6,8,12}){
 #ifdef _OPENMP
 omp_set_num_threads(threads);
 #endif
 m::Sparse actual(model.nodes.size());std::vector<double>f(model.nodes.size()),c(model.nodes.size());
 m::nodal_scatter(thermal.size(),[](size_t){return 4;},[&](size_t e,int i){return thermal[e].nodes[i];},[&](size_t e,int i,int a){auto&t=thermal[e];f[a]+=t.f;c[a]+=t.c;for(int j=0;j<4;++j)actual[a][t.nodes[j]]+=t.k[4*i+j];},cancel);
 if(actual!=thermal_reference||f!=rf||c!=rc)throw std::runtime_error("THERMAL_MATRIX_MISMATCH");
 }
 std::cout<<"Heterogeneous thermal TET4 stiffness/source/capacity exact equality PASS\n";
 cancel=true;bool rejected=false;try{m::nodal_scatter(1,[](size_t){return 4;},[](size_t,int i){return i;},[](size_t,int,int){},cancel);}catch(const std::runtime_error&e){rejected=std::string(e.what())=="CANCELLED";}
 if(!rejected)return 2;
 std::cout<<"Mixed heterogeneous HEX8/TET4 matrix exact equality: 60 runs; cancellation PASS\n";
}
