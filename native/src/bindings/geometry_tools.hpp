#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
namespace godot {
class UniCoreGeometryTools : public RefCounted {
    GDCLASS(UniCoreGeometryTools,RefCounted)
protected: static void _bind_methods();
public: Dictionary measure_primitive(const Dictionary &part) const;
    Dictionary validate_material(const Dictionary &material, const String &analysis) const;
};
}
