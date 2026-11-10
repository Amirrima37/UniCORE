#include "molecular_solver.hpp"
#include <godot_cpp/core/class_db.hpp>
using namespace godot;
void UniCoreMolecularSolver::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure","parameters"),&UniCoreMolecularSolver::configure);
    ClassDB::bind_method(D_METHOD("set_state","positions","velocities","masses"),&UniCoreMolecularSolver::set_state);
    ClassDB::bind_method(D_METHOD("advance","dt","substeps"),&UniCoreMolecularSolver::advance,DEFVAL(1));
    ClassDB::bind_method(D_METHOD("evaluate","positions"),&UniCoreMolecularSolver::evaluate);
    ClassDB::bind_method(D_METHOD("get_snapshot"),&UniCoreMolecularSolver::get_snapshot);
    ClassDB::bind_method(D_METHOD("export_state"),&UniCoreMolecularSolver::export_state);
    ClassDB::bind_method(D_METHOD("import_state","checkpoint"),&UniCoreMolecularSolver::import_state);
    ClassDB::bind_method(D_METHOD("clear"),&UniCoreMolecularSolver::clear);
}
PackedVector3Array UniCoreMolecularSolver::pack(const std::vector<unicore::Vec3> &values) {
    PackedVector3Array result; if(values.empty()) return result; result.resize(values.size()); auto data=result.ptrw();
    for(size_t i=0;i<values.size();++i) data[i]=Vector3(values[i].x,values[i].y,values[i].z);
    return result;
}
bool UniCoreMolecularSolver::unpack(const PackedVector3Array &values,std::vector<unicore::Vec3> &result) {
    if(values.size()>1000000) return false;
    result.resize(values.size()); if(values.is_empty()) return true; const auto data=values.ptr();
    for(int64_t i=0;i<values.size();++i) {
        result[i]={data[i].x,data[i].y,data[i].z}; if(!unicore::finite(result[i])) return false;
    }
    return true;
}
bool UniCoreMolecularSolver::configure(const Dictionary &parameters) {
    if(parameters.has("schema_version") && (parameters["schema_version"].get_type()!=Variant::INT || int64_t(parameters["schema_version"])!=1)) return false;
    auto config=solver.config;
    const char *names[]={"sigma","epsilon","cutoff_radius","particle_radius","restitution","target_temperature","thermostat_tau","boltzmann_constant"};
    double *values[]={&config.sigma,&config.epsilon,&config.cutoff,&config.radius,&config.restitution,&config.target_temperature,&config.thermostat_tau,&config.boltzmann_constant};
    for(size_t i=0;i<8;++i) if(parameters.has(names[i])) {
        const Variant value=parameters[names[i]];
        if(value.get_type()!=Variant::FLOAT&&value.get_type()!=Variant::INT) return false;
        *values[i]=double(value);
    }
    if(parameters.has("box_half_extent")) {
        const Variant value=parameters["box_half_extent"]; if(value.get_type()!=Variant::VECTOR3) return false;
        const Vector3 box=value; config.box={box.x,box.y,box.z};
    }
    if(parameters.has("thermostat_enabled")) {
        const Variant value=parameters["thermostat_enabled"]; if(value.get_type()!=Variant::BOOL) return false;
        config.thermostat_enabled=bool(value);
    }
    if(!config.valid()) return false;
    unicore::MolecularSolver validation; validation.config=config;
    if(!validation.valid_state(solver.state)) return false;
    solver.config=config; return true;
}
bool UniCoreMolecularSolver::set_state(const PackedVector3Array &positions,const PackedVector3Array &velocities,const PackedFloat32Array &masses) {
    if(positions.size()!=velocities.size()||positions.size()!=masses.size()) return false;
    unicore::MolecularState next;
    if(!unpack(positions,next.positions)||!unpack(velocities,next.velocities)) return false;
    if(masses.size()) { const auto data=masses.ptr(); next.masses.assign(data,data+masses.size()); }
    next.forces.resize(next.positions.size()); next.tick=solver.state.tick;
    if(!solver.valid_state(next)) return false;
    solver.state=std::move(next); ++revision; return true;
}
bool UniCoreMolecularSolver::advance(double dt,int64_t substeps) {
    if(substeps<1||substeps>10000) return false;
    if(!solver.advance(dt,int(substeps))) return false;
    ++revision; return true;
}
Dictionary UniCoreMolecularSolver::evaluate(const PackedVector3Array &positions) const {
    std::vector<unicore::Vec3> input,forces; double potential=0; Dictionary result;
    if(!unpack(positions,input)||!solver.evaluate(input,forces,potential)) return result;
    result["forces"]=pack(forces); result["potential_energy"]=potential; return result;
}
Dictionary UniCoreMolecularSolver::get_snapshot() const {
    Dictionary result; result["schema_version"]=1; result["units"]="simulation";
    result["revision"]=int64_t(revision); result["simulation_tick"]=int64_t(solver.state.tick);
    result["positions"]=pack(solver.state.positions); result["velocities"]=pack(solver.state.velocities);
    result["forces"]=pack(solver.state.forces);
    PackedFloat32Array masses; masses.resize(solver.state.masses.size());
    if(!solver.state.masses.empty()) { auto data=masses.ptrw();
        for(size_t i=0;i<solver.state.masses.size();++i) data[i]=solver.state.masses[i];
    }
    result["masses"]=masses; return result;
}
Dictionary UniCoreMolecularSolver::export_state() const {
    auto result=get_snapshot(); Dictionary config;
    config["schema_version"]=1; config["sigma"]=solver.config.sigma; config["epsilon"]=solver.config.epsilon;
    config["cutoff_radius"]=solver.config.cutoff; config["particle_radius"]=solver.config.radius;
    config["restitution"]=solver.config.restitution; config["target_temperature"]=solver.config.target_temperature;
    config["thermostat_tau"]=solver.config.thermostat_tau; config["boltzmann_constant"]=solver.config.boltzmann_constant;
    config["thermostat_enabled"]=solver.config.thermostat_enabled;
    config["box_half_extent"]=Vector3(solver.config.box.x,solver.config.box.y,solver.config.box.z);
    result["configuration"]=config; result["solver"]="molecular"; return result;
}
bool UniCoreMolecularSolver::import_state(const Dictionary &checkpoint) {
    const char *required[]={"schema_version","units","simulation_tick","positions","velocities","masses","forces","configuration","solver"};
    for(auto key:required) if(!checkpoint.has(key)) return false;
    if(checkpoint["schema_version"].get_type()!=Variant::INT||int64_t(checkpoint["schema_version"])!=1||
        checkpoint["solver"]!=Variant("molecular")||checkpoint["units"]!=Variant("simulation")||
        checkpoint["simulation_tick"].get_type()!=Variant::INT||int64_t(checkpoint["simulation_tick"])<0||
        checkpoint["positions"].get_type()!=Variant::PACKED_VECTOR3_ARRAY||checkpoint["velocities"].get_type()!=Variant::PACKED_VECTOR3_ARRAY||
        checkpoint["masses"].get_type()!=Variant::PACKED_FLOAT32_ARRAY||checkpoint["forces"].get_type()!=Variant::PACKED_VECTOR3_ARRAY||
        checkpoint["configuration"].get_type()!=Variant::DICTIONARY) return false;
    const Dictionary configuration=checkpoint["configuration"];
    const char *config_keys[]={"schema_version","sigma","epsilon","cutoff_radius","particle_radius","box_half_extent","restitution","target_temperature","thermostat_tau","boltzmann_constant","thermostat_enabled"};
    for(auto key:config_keys) if(!configuration.has(key)) return false;
    const auto previous=solver; const auto old_revision=revision;
    solver.state={};
    if(!configure(checkpoint["configuration"])||!set_state(checkpoint["positions"],checkpoint["velocities"],checkpoint["masses"])||
        !unpack(checkpoint["forces"],solver.state.forces)||solver.state.forces.size()!=solver.state.positions.size()) {
        solver=previous; revision=old_revision; return false;
    }
    solver.state.tick=uint64_t(int64_t(checkpoint["simulation_tick"])); ++revision; return true;
}
void UniCoreMolecularSolver::clear() { solver.state={}; ++revision; }
