#pragma once
#include "particle_metrics.hpp"
#include "kernels/molecular_solver.hpp"
namespace godot {
class UniCoreMolecularSolver : public RefCounted {
    GDCLASS(UniCoreMolecularSolver, RefCounted)
    unicore::MolecularSolver solver;
    uint64_t revision=0;
    static PackedVector3Array pack(const std::vector<unicore::Vec3> &values);
    static bool unpack(const PackedVector3Array &values,std::vector<unicore::Vec3> &result);
protected:
    static void _bind_methods();
public:
    bool configure(const Dictionary &parameters);
    bool set_state(const PackedVector3Array &positions,const PackedVector3Array &velocities,const PackedFloat32Array &masses);
    bool advance(double dt,int64_t substeps);
    Dictionary evaluate(const PackedVector3Array &positions) const;
    Dictionary get_snapshot() const;
    Dictionary export_state() const;
    bool import_state(const Dictionary &checkpoint);
    void clear();
};
}
