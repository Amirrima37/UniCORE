#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
namespace godot {
class UniCoreNativeInfo : public RefCounted {
    GDCLASS(UniCoreNativeInfo, RefCounted)
protected:
    static void _bind_methods();
public:
    Dictionary get_capabilities() const;
};
class UniCoreParticleMetrics : public RefCounted {
    GDCLASS(UniCoreParticleMetrics, RefCounted)
protected:
    static void _bind_methods();
public:
    Dictionary reduce(const PackedVector3Array &positions, const PackedVector3Array &velocities, const PackedFloat32Array &masses) const;
};
}
