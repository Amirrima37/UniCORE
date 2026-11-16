#pragma once
#include <charconv>
#include <sstream>
#include <locale>
// Read from the existing bounded file buffer. No token heap allocations and no
// locale facets. Keep the stream positioned for the version-1 text trailer.
inline double job_number(std::istream& input){
 auto* buffer=input.rdbuf();auto whitespace=[](int c){return c==' '||c=='\n'||c=='\r'||c=='\t'||c=='\v'||c=='\f';};
 int c=buffer->sgetc();while(whitespace(c))c=buffer->snextc();
 char token[1024];size_t length=0;
 while(c!=std::char_traits<char>::eof()&&!whitespace(c)){
  if(length==sizeof(token))throw std::runtime_error("NUMERIC_TOKEN_TOO_LONG");
  token[length++]=char(c);c=buffer->snextc();
 }
 const char* begin=token;const char* end=token+length;
 if(begin!=end&&*begin=='+'){++begin;if(begin!=end&&(*begin=='-'||*begin=='+'))throw std::runtime_error("INVALID_FINITE_NUMBER");}
 double value=0;auto parsed=std::from_chars(begin,end,value,std::chars_format::general);
 // Preserve legacy acceptance/rounding of decimal underflow, including zero.
 if(parsed.ec==std::errc::result_out_of_range){std::istringstream legacy(std::string(token,length));legacy.imbue(std::locale::classic());if((legacy>>value)&&legacy.peek()==std::char_traits<char>::eof()&&std::isfinite(value))return value;}
 if(begin==end||parsed.ec!=std::errc{}||parsed.ptr!=end||!std::isfinite(value))throw std::runtime_error("INVALID_FINITE_NUMBER");
 return value;
}
