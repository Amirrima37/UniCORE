#pragma once
#include <vector>
#include <algorithm>
#include "math/parallel_for.hpp"
namespace unicore::math {
// Standalone diagnostic/fallback; configure before starting solver workers.
inline bool serial_assembly=false;
// Exclusive ownership of each global node; element order is retained per row.
// Temporary storage is O(batch size * nodes per element), never O(global nnz).
template<class Count,class Node,class Scatter>
void nodal_scatter(size_t count,Count arity,Node node,Scatter scatter,const std::atomic<bool>&cancel){
    if(serial_assembly){for(size_t e=0;e<count;++e){if(cancel.load())throw std::runtime_error("CANCELLED");for(int i=0;i<arity(e);++i)scatter(e,i,node(e,i));}return;}
    struct Occurrence {int node;size_t element;int local;};
    std::vector<Occurrence> occurrences;occurrences.reserve(count*8);
    for(size_t e=0;e<count;++e)for(int i=0;i<arity(e);++i)occurrences.push_back({node(e,i),e,i});
    std::sort(occurrences.begin(),occurrences.end(),[](const Occurrence&a,const Occurrence&b){
        if(a.node!=b.node)return a.node<b.node;if(a.element!=b.element)return a.element<b.element;return a.local<b.local;});
    std::vector<size_t> groups;
    for(size_t i=0;i<occurrences.size();++i)if(i==0||occurrences[i].node!=occurrences[i-1].node)groups.push_back(i);
    groups.push_back(occurrences.size());
    parallel_for(groups.size()-1,[&](size_t group){for(size_t k=groups[group];k<groups[group+1];++k){const auto&o=occurrences[k];scatter(o.element,o.local,o.node);}},cancel);
}
}
