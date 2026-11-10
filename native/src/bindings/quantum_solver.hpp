#pragma once
#include "particle_metrics.hpp"
#include "kernels/quantum_solver.hpp"
namespace godot {
class UniCoreQuantumSolver : public RefCounted {
    GDCLASS(UniCoreQuantumSolver, RefCounted)
    unicore::QuantumSolver solver;
    bool ready = false;
    static bool parse(const Dictionary &state, unicore::QuantumSolver &result);
    static PackedFloat32Array pack(const unicore::FloatBuffer &data);

  protected:
    static void _bind_methods();

  public:
    bool set_state(const Dictionary &state);
    bool advance(double dt, int64_t substeps);
    Dictionary get_snapshot();
    Dictionary export_state();
    bool import_state(const Dictionary &state);
    void clear();
};
} // namespace godot
