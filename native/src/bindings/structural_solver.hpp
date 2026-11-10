#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <atomic>
namespace godot {
class UniCoreStructuralSolver : public RefCounted {
    GDCLASS(UniCoreStructuralSolver, RefCounted)
    std::atomic<bool> cancelled{false};
    std::atomic<int> phase{0};
protected: static void _bind_methods();
public:
    Dictionary generate_mesh(const Dictionary &project, int divisions) const;
    Dictionary solve_model(const Dictionary &project);
    Array get_tool_catalog() const;
    int get_phase() const {return phase.load();}
    void cancel() { cancelled.store(true); }
    void reset_cancel() { cancelled.store(false); }
};
}
