#include "math/newmark.hpp"
#include <iostream>
#include <iomanip>
#include <string>
using namespace unicore;
void array(std::ostream&o,const dynamics::Vector&v){o<<'[';for(size_t i=0;i<v.size();++i){if(i)o<<',';o<<v[i];}o<<']';}
int main(int argc,char**argv){try{
    std::string kind=argc>1?argv[1]:"free";dynamics::Options options;options.dt=argc>2?std::stod(argv[2]):.01;options.steps=argc>3?std::stoi(argv[3]):400;options.seconds=20;
    for(int i=0;i<=options.steps;++i)options.outputs.push_back(i);
    math::Sparse k(kind=="coupled"?2:1),m(k.size());m[0][0]=2;k[0][0]=8;
    dynamics::Vector u(k.size(),0),v(k.size(),0);u[0]=.1;v[0]=.2;std::vector<dynamics::Load>loads;
    if(kind=="damped"){options.alpha_mass=.4;options.beta_stiffness=.03;}
    else if(kind=="step"||kind=="constant"){u[0]=v[0]=0;loads.push_back({0,kind,2,0,0,0,0});}
    else if(kind=="sine"){u[0]=v[0]=0;loads.push_back({0,"sine",1,0,0,1.3,0});}
    else if(kind=="ramp"){u[0]=v[0]=0;loads.push_back({0,"ramp",2,.2,.7,0,0});}
    else if(kind=="velocity"){u[0]=0;v[0]=.3;}
    else if(kind=="phase"){u[0]=.1;v[0]=0;}
    else if(kind=="coupled"){
        m[1][1]=1;m[0][1]=m[1][0]=.3;k[0][0]=30;k[1][1]=20;k[0][1]=k[1][0]=-10;u={.1,-.03};v={.2,.1};options.alpha_mass=.2;options.beta_stiffness=.01;loads={{0,"sine",1,0,0,2.3,0},{1,"ramp",2,.2,.7,0,0}};
    }else if(kind!="free")throw std::runtime_error("UNKNOWN_TEST_CASE");
    std::atomic<bool>cancel{false};dynamics::Guard guard{cancel,20};auto result=dynamics::integrate(modal::Matrix(k),modal::Matrix(m),u,v,loads,options,guard);
    if(argc==1){if(result.frames.size()!=401||result.max_energy_balance>1e-10||result.max_equilibrium_residual>1e-10)throw std::runtime_error("DYNAMIC_UNIT_SMOKE_FAILURE");std::cout<<"Newmark unforced energy/equilibrium/output-count checks=3 failures=0\n";return 0;}
    std::cout<<std::setprecision(17)<<"{\"max_equilibrium_residual\":"<<result.max_equilibrium_residual<<",\"max_energy_balance\":"<<result.max_energy_balance<<",\"effective_system_setups\":"<<result.effective_setups<<",\"frames\":[";
    for(size_t i=0;i<result.frames.size();++i){if(i)std::cout<<',';auto&f=result.frames[i];std::cout<<"{\"time\":"<<f.time<<",\"u\":";array(std::cout,f.u);std::cout<<",\"v\":";array(std::cout,f.v);std::cout<<",\"a\":";array(std::cout,f.a);std::cout<<",\"kinetic\":"<<f.kinetic<<",\"elastic\":"<<f.elastic<<",\"dissipation\":"<<f.dissipation<<",\"work\":"<<f.work<<",\"balance\":"<<f.balance<<'}';}std::cout<<"]}\n";return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}}
