#pragma once
#include <atomic>
#include <exception>
#include <mutex>
#include <stdexcept>
namespace unicore::math {
template<class Function> void parallel_for(size_t count,Function function,const std::atomic<bool>&cancel,size_t minimum=128){
 std::exception_ptr error;std::mutex mutex;std::atomic<bool>failed{false};
 #ifdef _OPENMP
 #pragma omp parallel for schedule(static) if(count>=minimum)
 #endif
 for(size_t i=0;i<count;++i){if(cancel.load()||failed.load())continue;try{function(i);}catch(...){std::lock_guard<std::mutex>lock(mutex);if(!error)error=std::current_exception();failed=true;}}
 if(error)std::rethrow_exception(error);if(cancel.load())throw std::runtime_error("CANCELLED");
}
}
