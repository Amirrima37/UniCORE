#pragma once
// Coarse exclusive intervals: no per-token clock or process-counter calls.
struct PreparationDiagnostics {
 using Clock=std::chrono::steady_clock;
 static double cpu(){FILETIME a,b,k,u;if(!GetProcessTimes(GetCurrentProcess(),&a,&b,&k,&u))return 0;ULARGE_INTEGER x{},y{};x.LowPart=k.dwLowDateTime;x.HighPart=k.dwHighDateTime;y.LowPart=u.dwLowDateTime;y.HighPart=u.dwHighDateTime;return (x.QuadPart+y.QuadPart)*1e-4;}
 Clock::time_point wall=Clock::now();double process=cpu();std::ostringstream phases;
 void mark(const char*name){auto now=Clock::now();double c=cpu();if(phases.tellp()>0)phases<<',';phases<<'"'<<name<<"\":{\"wall_ms\":"<<std::chrono::duration<double,std::milli>(now-wall).count()<<",\"cpu_ms\":"<<c-process<<'}';wall=now;process=c;}
 void write(const std::filesystem::path&output,const std::filesystem::path&input,size_t nodes,size_t cells){PROCESS_MEMORY_COUNTERS m{};GetProcessMemoryInfo(GetCurrentProcess(),&m,sizeof(m));std::ofstream f(output/"preparation.json");f<<"{\"schema\":1,\"exclusive_phases\":{"<<phases.str()<<"},\"input_bytes\":"<<std::filesystem::file_size(input)<<",\"nodes\":"<<nodes<<",\"elements\":"<<cells<<",\"peak_working_set_bytes\":"<<m.PeakWorkingSetSize<<'}';}
};
