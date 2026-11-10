#pragma once
#include "particle_metrics.hpp"
#include "kernels/nuclear_solver.hpp"
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
namespace godot {
class UniCoreNuclearSolver : public RefCounted {
    GDCLASS(UniCoreNuclearSolver, RefCounted)
    unicore::NuclearSolver solver;
    bool ready = false;
    uint64_t revision = 0, tick = 0;

  protected:
    static void _bind_methods();

  public:
    bool set_state(const Dictionary &state, const Dictionary &models);
    bool advance(double dt);
    Dictionary get_snapshot() const;
    void clear();
};
} // namespace godot
