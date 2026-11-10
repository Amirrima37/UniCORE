#include "particle_metrics.hpp"
#include "kernels/particle_metrics.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
using namespace godot;
void UniCoreNativeInfo::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_capabilities"), &UniCoreNativeInfo::get_capabilities);
}
Dictionary UniCoreNativeInfo::get_capabilities() const {
    Dictionary result;
    result["api_version"] = 1;
    result["godot_cpp_revision"] = "9d1c396c54fc3bdfcc7da4f3abcb52b14f6cce8f";
    result["precision"] = "single";
    result["particle_metrics"] = true;
    result["molecular_solver"] = true;
    result["gravity_solver"] = true;
    result["quantum_solver"] = true;
    result["nuclear_solver"] = true;
    result["structural_solver"] = true;
    result["structural_api_version"] = 1;
    result["box_volume_mesher"] = true;
    result["primitive_geometry_metrics"] = true;
    result["materials_validation"] = true;
    result["hex8_structural"] = true;
    result["steady_thermal"] = true;
    result["transient_thermal"] = true;
    result["nuclear_rng_checkpoint"] = false;
    return result;
}
void UniCoreParticleMetrics::_bind_methods() {
    ClassDB::bind_method(D_METHOD("reduce", "positions", "velocities", "masses"), &UniCoreParticleMetrics::reduce);
}
Dictionary UniCoreParticleMetrics::reduce(const PackedVector3Array &positions, const PackedVector3Array &velocities, const PackedFloat32Array &masses) const {
    Dictionary result;
    const auto n = positions.size();
    if (velocities.size() != n || masses.size() != n) return result;
    for (int64_t i = 0; i < n; ++i) {
        const auto r = positions[i], v = velocities[i];
        if (!std::isfinite(r.x) || !std::isfinite(r.y) || !std::isfinite(r.z) ||
            !std::isfinite(v.x) || !std::isfinite(v.y) || !std::isfinite(v.z) || !std::isfinite(masses[i])) return result;
    }
    const auto convert = [](Vector3 v) { return unicore::Vec3{v.x, v.y, v.z}; };
    const auto metrics = unicore::reduce(n,
        [&](std::size_t i) { return convert(positions[i]); },
        [&](std::size_t i) { return convert(velocities[i]); },
        [&](std::size_t i) { return masses[i]; });
    result["kinetic_energy"] = metrics.kinetic_energy;
    result["linear_momentum"] = Vector3(metrics.momentum.x, metrics.momentum.y, metrics.momentum.z);
    result["angular_momentum"] = Vector3(metrics.angular_momentum.x, metrics.angular_momentum.y, metrics.angular_momentum.z);
    return result;
}
