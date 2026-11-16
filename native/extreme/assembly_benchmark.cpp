#include "kernels/structural_solver.hpp"
#include <iostream>
#include <omp.h>
using Clock=std::chrono::steady_clock;
double ms(Clock::time_point t){return std::chrono::duration<double,std::milli>(Clock::now()-t).count();}
int main(){namespace s=unicore::structural;namespace math=unicore::math;s::Model model;int n=32,m=n+1;
 for(int z=0;z<m;++z)for(int y=0;y<m;++y)for(int x=0;x<m;++x)model.nodes.push_back({double(x)/n,double(y)/n,double(z)/n});
 for(int z=0;z<n;++z)for(int y=0;y<n;++y)for(int x=0;x<n;++x){int a=x+m*y+m*m*z;model.hexes.push_back({{a,a+1,a+m+1,a+m,a+m*m,a+m*m+1,a+m*m+m+1,a+m*m+m},{1000,0}});}
 auto cells=s::cells_of(model);std::atomic<bool>cancel{false};
 math::Sparse reference;
 std::cout<<"repeat,threads,method,integration_ms,scatter_ms,total_ms,exact\n";
 for(int repeat=0;repeat<3;++repeat)for(int threads:{1,2,4,6,8,12}){omp_set_num_threads(threads);
 for(int order=0;order<2;++order){bool parallel=(order+repeat)%2;auto start=Clock::now();math::Sparse K(model.nodes.size()*3);double integration=0,scatter=0;size_t batch=parallel?2048:256;
 for(size_t begin=0;begin<cells.size();begin+=batch){size_t count=std::min(batch,cells.size()-begin);std::vector<s::Local>local(count);auto tick=Clock::now();
 math::parallel_for(count,[&](size_t k){local[k]=s::integrate(model,cells[begin+k]);},cancel);integration+=ms(tick);tick=Clock::now();
 auto add=[&](size_t k,int node,int global){auto&e=local[k];auto&t=cells[begin+k];for(int axis=0;axis<3;++axis){int i=3*node+axis;auto&row=K[3*global+axis];for(int j=0;j<e.n;++j)row[3*t.nodes[j/3]+j%3]+=e.K[i*e.n+j];}};
 if(parallel)math::nodal_scatter(count,[&](size_t k){return int(cells[begin+k].nodes.size());},[&](size_t k,int i){return cells[begin+k].nodes[i];},add,cancel);
 else for(size_t k=0;k<count;++k)for(size_t i=0;i<cells[begin+k].nodes.size();++i)add(k,int(i),cells[begin+k].nodes[i]);
 scatter+=ms(tick);
 }
 double total=ms(start);bool exact=reference.empty()||reference==K;if(!exact)return 2;
 std::cout<<repeat<<','<<threads<<','<<(parallel?"row_owned":"serial_scatter")<<','<<integration<<','<<scatter<<','<<total<<','<<exact<<std::endl;
 if(reference.empty())reference=std::move(K);
 }
 }
}
