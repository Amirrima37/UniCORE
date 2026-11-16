#pragma once
#include <vector>
#include <stdexcept>
namespace unicore::compute {
enum class Backend { CPU, CUDA, ROCm, Vulkan };
constexpr bool available(Backend value){return value==Backend::CPU;}
// Immutable host FP64 CSR view. Its owner must outlive apply(). GPU implementations
// must explicitly manage device buffers/transfers and preserve solver precision.
struct CSRView {const std::vector<size_t>&offsets;const std::vector<int>&columns;const std::vector<double>&values;};
struct LinearBackend {virtual ~LinearBackend()=default;virtual bool supports_fp64()const=0;virtual void apply(const CSRView&,const std::vector<double>&,std::vector<double>&,const std::vector<bool>&)const=0;};
struct CPUBackend final:LinearBackend {
 bool supports_fp64()const override{return true;}
 void apply(const CSRView&a,const std::vector<double>&x,std::vector<double>&y,const std::vector<bool>&fixed)const override{
  size_t n=x.size();
  #ifdef _OPENMP
  #pragma omp parallel for schedule(static) if(n>=20000)
  #endif
  for(size_t i=0;i<n;++i){double sum=0;if(!fixed[i])for(size_t j=a.offsets[i];j<a.offsets[i+1];++j)if(!fixed[a.columns[j]])sum+=a.values[j]*x[a.columns[j]];y[i]=sum;}
 }
};
}
