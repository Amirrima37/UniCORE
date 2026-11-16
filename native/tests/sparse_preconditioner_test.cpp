#include "math/sparse_pcg.hpp"
#include <cassert>
#include <iostream>
using namespace unicore::math;
int main(){
 std::atomic<bool> cancel{false};
 Sparse a(6);for(int i=0;i<6;++i){a[i][i]=4;if(i){a[i][i-1]=-1;a[i-1][i]=-1;}}
 std::vector<double>x{1,2,3,4,5,6},f(6);for(int i=0;i<6;++i)for(auto e:a[i])f[i]+=e.second*x[e.first];std::vector<bool>fixed(6,false);
 for(auto method:{"jacobi","block-jacobi","ic0","auto"}){SolverOptions o;o.preconditioner=method;auto r=pcg(a,f,fixed,{},cancel,nullptr,3,o);for(int i=0;i<6;++i)assert(std::abs(r.x[i]-x[i])<1e-8);assert(r.residual<1e-9);assert(r.preconditioner_bytes>0);}
 fixed[0]=true;for(auto method:{"jacobi","block-jacobi","ic0"}){SolverOptions o;o.preconditioner=method;auto r=pcg(a,f,fixed,x,cancel,nullptr,3,o);for(int i=0;i<6;++i)assert(std::abs(r.x[i]-x[i])<1e-8);}
 auto fails=[&](const Sparse&m,const std::vector<double>&rhs,const SolverOptions&o,const std::string&expected){bool failed=false;try{pcg(m,rhs,std::vector<bool>(m.size()),{},cancel,nullptr,1,o);}catch(const std::runtime_error&e){failed=std::string(e.what()).find(expected)!=std::string::npos;}assert(failed);};
 SolverOptions o;o.max_iterations=1;fails(a,f,o,"ITERATION_LIMIT");o=SolverOptions{};auto asym=a;asym[0][1]=2;fails(asym,f,o,"NONSYMMETRIC");
 Sparse indefinite(2);indefinite[0]={{0,1},{1,2}};indefinite[1]={{0,2},{1,1}};fails(indefinite,{1,-1},o,"SINGULAR_SYSTEM");
 Sparse cycle(4);for(int i=0;i<4;++i)cycle[i][i]=1;for(auto e:std::vector<std::pair<int,int>>{{0,1},{1,2},{2,3},{0,3}}){double v=e.first==2?-.6:.6;cycle[e.first][e.second]=cycle[e.second][e.first]=v;}
 o.preconditioner="ic0";auto fallback=pcg(cycle,{1,2,3,4},std::vector<bool>(4),{},cancel,nullptr,1,o);assert(fallback.preconditioner=="jacobi"&&fallback.fallback=="IC0_INVALID_PIVOT");
 o.preconditioner="block-jacobi";auto scalar=pcg(a,f,std::vector<bool>(6),{},cancel,nullptr,1,o);assert(scalar.preconditioner=="jacobi"&&scalar.fallback=="BLOCK_STRUCTURE_UNAVAILABLE");
 o=SolverOptions{};auto zero=pcg(a,std::vector<double>(6),std::vector<bool>(6),{},cancel,nullptr,1,o);assert(zero.iterations==0&&zero.residual==0);
 o.relative_tolerance=-1;fails(a,f,o,"INVALID_SOLVER");o=SolverOptions{};cancel=true;fails(a,f,o,"CANCELLED");
 std::cout<<"Preconditioners, true residuals, prescribed values, SPD IC breakdown fallback, asymmetry, indefinite curvature, zero RHS, limits and cancellation PASS\n";
}
