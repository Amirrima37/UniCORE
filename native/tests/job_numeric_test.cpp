#include <sstream>
#include <fstream>
#include <cmath>
#include <stdexcept>
#include <cassert>
#include <iomanip>
#include <random>
#include "../extreme/numeric_input.hpp"
int main(int argc,char**argv){
 for(int i=1;i<argc;++i){std::ifstream file(argv[i]);assert(file);std::string token;while(file>>token){std::istringstream old(token),current(token);double v;if(old>>v){assert(old.peek()==std::char_traits<char>::eof());double w=job_number(current);assert(v==w&&std::signbit(v)==std::signbit(w));}}}

 std::mt19937_64 rng(24);
 for(int i=0;i<100000;++i){double v=std::ldexp(double(rng()),int(rng()%1800)-960);if(!std::isfinite(v))continue;std::ostringstream out;out<<std::setprecision(17)<<v;std::istringstream a(out.str()),b(out.str());double old=0;a>>old;assert(a);assert(job_number(b)==old);}
 for(const char* text:{"0","-0","+1.0","1e-300","4.9406564584124654e-324","9007199254740991","1.7976931348623157e308","1e-9999"}){std::istringstream a(text),b(text);double v;a>>v;assert(a);double w=job_number(b);assert(v==w&&std::signbit(v)==std::signbit(w));}
 for(const char* text:{"","nan","inf","1e309","+-1","1x","1e","--1"}){std::istringstream f(text);bool rejected=false;try{job_number(f);}catch(const std::runtime_error&){rejected=true;}assert(rejected);}
 std::istringstream huge(std::string(1025,'1'));bool rejected=false;try{job_number(huge);}catch(...){rejected=true;}assert(rejected);
}
