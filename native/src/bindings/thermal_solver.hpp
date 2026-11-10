#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <atomic>
namespace godot {
class UniCoreThermalSolver : public RefCounted {
    GDCLASS(UniCoreThermalSolver,RefCounted)
    std::atomic<bool>cancelled{false};
    std::atomic<int>phase{0};
protected: static void _bind_methods();
public:
    Dictionary solve_model(const Dictionary &project);
    int get_phase() const {return phase.load();}
    void cancel(){cancelled.store(true);}
    void reset_cancel(){cancelled.store(false);}
};
}
