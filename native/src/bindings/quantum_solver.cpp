#include "quantum_solver.hpp"
#include <godot_cpp/core/class_db.hpp>
using namespace godot;
void UniCoreQuantumSolver::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_state", "state"), &UniCoreQuantumSolver::set_state);
    ClassDB::bind_method(D_METHOD("advance", "dt", "substeps"), &UniCoreQuantumSolver::advance, DEFVAL(1));
    ClassDB::bind_method(D_METHOD("get_snapshot"), &UniCoreQuantumSolver::get_snapshot);
    ClassDB::bind_method(D_METHOD("export_state"), &UniCoreQuantumSolver::export_state);
    ClassDB::bind_method(D_METHOD("import_state", "state"), &UniCoreQuantumSolver::import_state);
    ClassDB::bind_method(D_METHOD("clear"), &UniCoreQuantumSolver::clear);
}
bool UniCoreQuantumSolver::parse(const Dictionary &state, unicore::QuantumSolver &out) {
    const char *required[] = {"schema_version", "dimension",     "nx",   "nz",   "length",   "depth",
                              "barrier_center", "barrier_width", "real", "imag", "potential"};
    for (auto key : required)
        if (!state.has(key))
            return false;
    for (auto key : {"schema_version", "dimension", "nx", "nz"})
        if (state[key].get_type() != Variant::INT)
            return false;
    if (int64_t(state["schema_version"]) != 1)
        return false;
    int64_t dim = state["dimension"], nx = state["nx"], nz = state["nz"];
    if ((dim != 1 && dim != 2) || nx < 3 || nx > 1000000 ||
        (dim == 2 && (nz < 3 || nz > 1000000 || nx > 1000000 / nz)) || (dim == 1 && nz != 1))
        return false;
    for (auto key : {"length", "depth", "barrier_center", "barrier_width"}) {
        Variant v = state[key];
        if ((v.get_type() != Variant::FLOAT && v.get_type() != Variant::INT) || !std::isfinite(double(v)))
            return false;
    }
    double length = state["length"], depth = state["depth"];
    if (length <= 0 || depth <= 0 || length > 1e15 || depth > 1e15)
        return false;
    const int64_t n = dim == 1 ? nx : nx * nz;
    out.active_dimension = dim;
    out.grid_size_1d = dim == 1 ? nx : 0;
    out.grid_size_2d_x = dim == 2 ? nx : 0;
    out.grid_size_2d_z = dim == 2 ? nz : 0;
    out.domain_length_1d = length;
    out.domain_size_2d = {float(length), float(depth)};
    out.barrier_center_x = double(state["barrier_center"]);
    out.barrier_width_d = double(state["barrier_width"]);
    const char *keys[] = {"real", "imag", "potential"};
    unicore::FloatBuffer *buffers[] = {dim == 1 ? &out.psi_real_1d : &out.psi_real_2d,
                                       dim == 1 ? &out.psi_imag_1d : &out.psi_imag_2d,
                                       dim == 1 ? &out.potential_1d : &out.potential_2d};
    for (int k = 0; k < 3; ++k) {
        if (state[keys[k]].get_type() != Variant::PACKED_FLOAT32_ARRAY)
            return false;
        PackedFloat32Array values = state[keys[k]];
        if (values.size() != n)
            return false;
        const auto data = values.ptr();
        buffers[k]->values.assign(data, data + n);
    }
    if (dim == 1) {
        out.prob_density_1d.resize(n);
        out._update_prob_density_1d();
    } else {
        out.prob_density_2d.resize(n);
        out._update_prob_density_2d();
    }
    return out.finite_state() && std::isfinite(out.compute_norm()) &&
           std::isfinite(out.compute_mean_position()) && std::isfinite(out.compute_expectation_energy()) &&
           std::isfinite(out.compute_transmission()) && std::isfinite(out.compute_reflection());
}
PackedFloat32Array UniCoreQuantumSolver::pack(const unicore::FloatBuffer &data) {
    PackedFloat32Array result;
    if (data.values.empty())
        return result;
    result.resize(data.size());
    auto out = result.ptrw();
    std::copy(data.values.begin(), data.values.end(), out);
    return result;
}
bool UniCoreQuantumSolver::set_state(const Dictionary &state) {
    unicore::QuantumSolver next;
    if (!parse(state, next))
        return false;
    next.tick = solver.tick;
    solver = std::move(next);
    ready = true;
    return true;
}
bool UniCoreQuantumSolver::advance(double dt, int64_t substeps) {
    return ready && solver.advance(dt, substeps);
}
Dictionary UniCoreQuantumSolver::get_snapshot() {
    Dictionary result;
    result["schema_version"] = 1;
    result["units"] = "simulation";
    result["simulation_tick"] = int64_t(solver.tick);
    result["ready"] = ready;
    if (!ready)
        return result;
    bool one = solver.active_dimension == 1;
    result["dimension"] = solver.active_dimension;
    result["nx"] = one ? solver.grid_size_1d : solver.grid_size_2d_x;
    result["nz"] = one ? 1 : solver.grid_size_2d_z;
    result["length"] = one ? solver.domain_length_1d : double(solver.domain_size_2d.x);
    result["depth"] = double(solver.domain_size_2d.y);
    result["barrier_center"] = solver.barrier_center_x;
    result["barrier_width"] = solver.barrier_width_d;
    result["real"] = pack(one ? solver.psi_real_1d : solver.psi_real_2d);
    result["imag"] = pack(one ? solver.psi_imag_1d : solver.psi_imag_2d);
    result["potential"] = pack(one ? solver.potential_1d : solver.potential_2d);
    result["density"] = pack(one ? solver.prob_density_1d : solver.prob_density_2d);
    result["norm"] = solver.compute_norm();
    result["mean_position"] = solver.compute_mean_position();
    result["energy"] = solver.compute_expectation_energy();
    result["transmission"] = solver.compute_transmission();
    result["reflection"] = solver.compute_reflection();
    return result;
}
Dictionary UniCoreQuantumSolver::export_state() {
    return get_snapshot();
}
bool UniCoreQuantumSolver::import_state(const Dictionary &state) {
    if (!state.has("units") || state["units"] != Variant("simulation") || !state.has("simulation_tick") ||
        state["simulation_tick"].get_type() != Variant::INT || int64_t(state["simulation_tick"]) < 0)
        return false;
    unicore::QuantumSolver next;
    if (!parse(state, next))
        return false;
    next.tick = uint64_t(int64_t(state["simulation_tick"]));
    solver = std::move(next);
    ready = true;
    return true;
}
void UniCoreQuantumSolver::clear() {
    solver = {};
    ready = false;
}
