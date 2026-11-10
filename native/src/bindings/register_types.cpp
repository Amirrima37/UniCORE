#include "particle_metrics.hpp"
#include "molecular_solver.hpp"
#include "gravity_solver.hpp"
#include "quantum_solver.hpp"
#include "nuclear_solver.hpp"
#include "structural_solver.hpp"
#include "geometry_tools.hpp"
#include "thermal_solver.hpp"
#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/class_db.hpp>
using namespace godot;
void initialize_unicore(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    ClassDB::register_class<UniCoreNativeInfo>();
    ClassDB::register_class<UniCoreParticleMetrics>();
    ClassDB::register_class<UniCoreMolecularSolver>();
    ClassDB::register_class<UniCoreGravitySolver>();
    ClassDB::register_class<UniCoreQuantumSolver>();
    ClassDB::register_class<UniCoreNuclearSolver>();
    ClassDB::register_class<UniCoreStructuralSolver>();
    ClassDB::register_class<UniCoreGeometryTools>();
    ClassDB::register_class<UniCoreThermalSolver>();
}
void uninitialize_unicore(ModuleInitializationLevel) {}
extern "C" {
GDExtensionBool GDE_EXPORT unicore_native_init(const GDExtensionInterface *interface, GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(interface, library, initialization);
    init.register_initializer(initialize_unicore);
    init.register_terminator(uninitialize_unicore);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
}
