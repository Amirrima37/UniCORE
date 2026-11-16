#include "math/sparse_pcg.hpp"
#include <omp.h>
#include <chrono>
#include <iostream>
int main(){std::cout<<"dof,threads,assembly_ms,solve_ms,iterations,residual\n";for(int n:{1000,10000,100000,1000000}){auto start=std::chrono::steady_clock::now();unicore::math::Sparse a(n);std::vector<double>b(n,2);std::vector<bool>fixed(n,false);for(int i=0;i<n;++i){a[i][i]=4;if(i)a[i][i-1]=-1;else b[i]+=1;if(i+1<n)a[i][i+1]=-1;else b[i]+=1;}double assembly=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();for(int threads:{1,2,4,8,12}){omp_set_num_threads(threads);std::atomic<bool>cancel{false};start=std::chrono::steady_clock::now();auto r=unicore::math::pcg(a,b,fixed,{},cancel);double ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();for(double x:r.x)if(std::abs(x-1)>1e-7)return 1;std::cout<<n<<','<<threads<<','<<assembly<<','<<ms<<','<<r.iterations<<','<<r.residual<<'\n';}}}
