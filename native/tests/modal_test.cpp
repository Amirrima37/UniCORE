#include "kernels/modal_solver.hpp"
#include <iostream>
#include <functional>
using namespace unicore;
int checks=0;
void require(bool ok,const char*label){++checks;if(!ok)throw std::runtime_error(label);}
void rejects(const std::function<void()>&f,const std::string&message){bool caught=false;try{f();}catch(const std::exception&e){caught=std::string(e.what()).find(message)!=std::string::npos;}require(caught,message.c_str());}
int main(){try{
    std::atomic<bool>cancel{false};modal::Limits o;o.modes=3;
    // Congruence transform: M=L L^T, K=L diag(2,2,9) L^T.
    double L[3][3]={{2,0,0},{1,3,0},{-.5,.4,1.2}},lambda[3]={2,2,9};
    math::Sparse k(3),m(3);for(int i=0;i<3;++i)for(int j=0;j<3;++j)for(int a=0;a<3;++a){m[i][j]+=L[i][a]*L[j][a];k[i][j]+=L[i][a]*lambda[a]*L[j][a];}
    modal::Matrix K(k),M(m);modal::Guard guard{cancel,std::chrono::steady_clock::now(),30};auto r=modal::lowest(K,M,o,guard);
    for(int j=0;j<3;++j){require(std::abs(r.eigenvalues[j]-lambda[j])<1e-11,"known generalized eigenvalue");require(r.residuals[j]<1e-12,"true residual");for(int i=0;i<3;++i)require(std::abs(modal::inner(r.vectors[j],M.apply(r.vectors[i]))-(i==j?1:0))<1e-12,"mass orthogonality");require(std::abs(modal::inner(r.vectors[j],K.apply(r.vectors[j]))-lambda[j])<1e-11,"energy Rayleigh identity");}
    // Repeated-eigenvalue subspace: phi_1,phi_2 must have zero projection
    // on the independent third generalized eigenvector L^-T e_3.
    modal::Vector third{0.2638888888888889,-0.1111111111111111,0.8333333333333333};
    for(int j=0;j<2;++j)require(std::abs(modal::inner(third,M.apply(r.vectors[j])))<1e-12,"repeated invariant subspace");
    // Independent sine eigenpairs of a Dirichlet second-difference operator.
    math::Sparse tk(30),tm(30);for(int i=0;i<30;++i){tk[i][i]=2;tm[i][i]=3;if(i){tk[i][i-1]=-1;tk[i-1][i]=-1;}}
    modal::Matrix TK(tk),TM(tm);o.modes=2;o.tolerance=1e-8;
    auto tr=modal::lowest(TK,TM,o,guard);auto again=modal::lowest(TK,TM,o,guard);
    for(int j=0;j<2;++j){double exact=(2-2*std::cos((j+1)*std::acos(-1.)/31))/3;require(std::abs(tr.eigenvalues[j]/exact-1)<1e-10,"sine eigenvalue");
        modal::Vector v(30);for(int i=0;i<30;++i)v[i]=std::sqrt(2./93)*std::sin((i+1)*(j+1)*std::acos(-1.)/31);
        require(std::abs(std::abs(modal::inner(v,TM.apply(tr.vectors[j])))-1)<1e-10,"sine eigenvector sign invariant");require(tr.vectors[j]==again.vectors[j],"repeatable vectors");}
    o.iterations=1;rejects([&]{modal::lowest(TK,TM,o,guard);},"EIGEN_ITERATION_LIMIT");o.iterations=300;
    auto nonsymmetric=tk;nonsymmetric[0][1]=-.5;rejects([&]{modal::Matrix bad(nonsymmetric);},"NONSYMMETRIC");
    auto indefinite=tm;indefinite[0][0]=-1;rejects([&]{modal::Matrix bad(indefinite);},"NONPOSITIVE");
    math::Sparse ik(2),im(2);ik[0][0]=ik[1][1]=1;ik[0][1]=ik[1][0]=2;im[0][0]=im[1][1]=1;modal::Limits two;two.modes=2;
    rejects([&]{modal::lowest(modal::Matrix(ik),modal::Matrix(im),two,guard);},"NOT_POSITIVE_DEFINITE");
    auto rankdef=im;rankdef[0][1]=rankdef[1][0]=1;
    rejects([&]{modal::lowest(modal::Matrix(im),modal::Matrix(rankdef),two,guard);},"SUBSPACE_RANK_LOSS");
    auto invalid=tm;invalid[0][0]=NAN;rejects([&]{modal::Matrix bad(invalid);},"INVALID_MODAL_MATRIX");
    cancel=true;rejects([&]{modal::lowest(TK,TM,o,guard);},"CANCELLED");cancel=false;
    modal::Guard expired{cancel,std::chrono::steady_clock::now()-std::chrono::seconds(2),1};rejects([&]{modal::lowest(TK,TM,o,expired);},"WALL_TIME_LIMIT");
    structural::Model s;s.nodes={{0,0,0},{1,0,0},{0,1,0},{0,0,1}};structural::Tet t{{0,1,2,3},{1000,.25}};
    auto base=structural::element(s,t);auto mass=modal::tet_mass(base.volume,6); // total physical mass = 1 kg
    for(int axis=0;axis<3;++axis){double sum=0;for(int i=0;i<4;++i)for(int j=0;j<4;++j)sum+=mass[(3*i+axis)*12+3*j+axis];require(std::abs(sum-1)<1e-14,"integrated translation mass");}
    for(int i=0;i<12;++i)for(int j=0;j<12;++j){require(mass[i*12+j]==mass[j*12+i],"symmetric mass");if(i%3!=j%3)require(mass[i*12+j]==0,"uncoupled translation blocks");}
    // The scalar mass has eigenvalue rho V/4 for translation, rho V/20
    // for any sum-zero vector; test the full 12-dimensional quadratic form.
    for(int i=0;i<12;++i){modal::Vector x(12);x[i]=1;if(i>=3)x[i-3]=-1;double energy=0;for(int a=0;a<12;++a)for(int b=0;b<12;++b)energy+=x[a]*mass[a*12+b]*x[b];require(std::abs(energy-(i<3?.1:.1))<1e-14,"known positive mass quadratic form");}
    for(auto&v:s.nodes){v[0]+=7;v[1]-=2;v[2]+=4;}auto shifted=modal::tet_mass(structural::element(s,t).volume,6);require(shifted==mass,"translation invariant mass");
    for(auto&v:s.nodes)for(double&x:v)x*=2;auto scaled=modal::tet_mass(structural::element(s,t).volume,6);for(int i=0;i<144;++i)require(std::abs(scaled[i]-8*mass[i])<1e-14,"cubic mass scaling");
    structural::Tet permuted{{1,2,0,3},{1000,.25}};auto pm=modal::tet_mass(structural::element(s,permuted).volume,6);int perm[4]={1,2,0,3};for(int i=0;i<12;++i)for(int j=0;j<12;++j)require(pm[i*12+j]==scaled[(3*perm[i/3]+i%3)*12+3*perm[j/3]+j%3],"even node permutation mass");
    for(double density:{0.,-1.,double(INFINITY),double(NAN)})rejects([&]{modal::tet_mass(1,density);},"DENSITY_OR_VOLUME");
    std::cout<<"modal checks="<<checks<<" failures=0\n";return 0;
}catch(const std::exception&e){std::cerr<<"modal check "<<checks<<" FAILED "<<e.what()<<'\n';return 1;}}
