#include "nuclear_solver.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
using namespace godot;
static std::string string_value(const String &value) {
    return std::string(value.utf8().get_data());
}
void UniCoreNuclearSolver::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_state", "state", "models"), &UniCoreNuclearSolver::set_state);
    ClassDB::bind_method(D_METHOD("advance", "dt"), &UniCoreNuclearSolver::advance);
    ClassDB::bind_method(D_METHOD("get_snapshot"), &UniCoreNuclearSolver::get_snapshot);
    ClassDB::bind_method(D_METHOD("clear"), &UniCoreNuclearSolver::clear);
}
bool UniCoreNuclearSolver::set_state(const Dictionary &state, const Dictionary &models) {
    for (auto key : {"schema_version", "active_nuclei_count", "active_rad_count", "total_decay_events",
                     "total_fission_events"})
        if (!state.has(key) || state[key].get_type() != Variant::INT)
            return false;
    if (int64_t(state["schema_version"]) != 1)
        return false;
    unicore::NuclearSolver next;
    for (auto key : {"half_life_multiplier", "control_rod_depth", "containment_radius"}) {
        if (!state.has(key))
            return false;
        auto v = state[key];
        if ((v.get_type() != Variant::FLOAT && v.get_type() != Variant::INT) || !std::isfinite(double(v)))
            return false;
    }
    next.multiplier = double(state["half_life_multiplier"]);
    next.rods = double(state["control_rod_depth"]);
    next.radius = double(state["containment_radius"]);
    next.active_nuclei = int64_t(state["active_nuclei_count"]);
    next.active_radiation = int64_t(state["active_rad_count"]);
    next.total_decays = int64_t(state["total_decay_events"]);
    next.total_fissions = int64_t(state["total_fission_events"]);
    struct Field {
        const char *key;
        Variant::Type type;
    };
    const Field fields[] = {{"nuclei_positions", Variant::PACKED_VECTOR3_ARRAY},
                            {"nuclei_velocities", Variant::PACKED_VECTOR3_ARRAY},
                            {"nuclei_masses", Variant::PACKED_FLOAT32_ARRAY},
                            {"nuclei_half_lives", Variant::PACKED_FLOAT32_ARRAY},
                            {"nuclei_channels", Variant::PACKED_INT32_ARRAY},
                            {"nuclei_active", Variant::PACKED_BYTE_ARRAY},
                            {"nuclei_isotope_keys", Variant::PACKED_STRING_ARRAY},
                            {"rad_positions", Variant::PACKED_VECTOR3_ARRAY},
                            {"rad_velocities", Variant::PACKED_VECTOR3_ARRAY},
                            {"rad_masses", Variant::PACKED_FLOAT32_ARRAY},
                            {"rad_lifetimes", Variant::PACKED_FLOAT32_ARRAY},
                            {"rad_types", Variant::PACKED_INT32_ARRAY},
                            {"rad_active", Variant::PACKED_BYTE_ARRAY}};
    for (auto field : fields)
        if (!state.has(field.key) || state[field.key].get_type() != field.type)
            return false;
    PackedVector3Array np = state["nuclei_positions"], nv = state["nuclei_velocities"],
                       rp = state["rad_positions"], rv = state["rad_velocities"];
    PackedFloat32Array nm = state["nuclei_masses"], nh = state["nuclei_half_lives"], rm = state["rad_masses"],
                       rl = state["rad_lifetimes"];
    PackedByteArray na = state["nuclei_active"], ra = state["rad_active"];
    PackedInt32Array nc = state["nuclei_channels"], rt = state["rad_types"];
    PackedStringArray nk = state["nuclei_isotope_keys"];
    int64_t n = np.size(), r = rp.size();
    if (n > 10000 || r > 20000 || nv.size() != n || nm.size() != n || nh.size() != n || nc.size() != n ||
        na.size() != n || nk.size() != n || rv.size() != r || rm.size() != r || rl.size() != r ||
        rt.size() != r || ra.size() != r)
        return false;
    next.nuclei.resize(n);
    next.radiation.resize(r);
    if (n) {
        const auto pp = np.ptr(), vv = nv.ptr();
        const auto mm = nm.ptr(), hh = nh.ptr();
        const auto cc = nc.ptr();
        const auto aa = na.ptr();
        for (int64_t i = 0; i < n; ++i)
            next.nuclei[i] = {
                {pp[i].x, pp[i].y, pp[i].z}, {vv[i].x, vv[i].y, vv[i].z}, mm[i], hh[i], cc[i], aa[i],
                string_value(nk[i])};
    }
    if (r) {
        const auto pp = rp.ptr(), vv = rv.ptr();
        const auto mm = rm.ptr(), ll = rl.ptr();
        const auto tt = rt.ptr();
        const auto aa = ra.ptr();
        for (int64_t i = 0; i < r; ++i)
            next.radiation[i] = {
                {pp[i].x, pp[i].y, pp[i].z}, {vv[i].x, vv[i].y, vv[i].z}, mm[i], ll[i], tt[i], aa[i]};
    }
    if (models.size() > 1000)
        return false;
    Array keys = models.keys();
    for (int64_t i = 0; i < keys.size(); ++i) {
        if (keys[i].get_type() != Variant::STRING || models[keys[i]].get_type() != Variant::DICTIONARY)
            return false;
        String key = keys[i];
        Dictionary data = models[key];
        unicore::Isotope iso;
        iso.symbol = string_value(data.get("symbol", key));
        iso.daughter = string_value(data.get("daughter_symbol", String()));
        auto number = [&](const char *name, double fallback, double &out) {
            Variant v = data.get(name, fallback);
            if (v.get_type() != Variant::FLOAT && v.get_type() != Variant::INT)
                return false;
            out = double(v);
            return true;
        };
        if (!number("atomic_mass_u", 1, iso.mass) || !number("half_life_seconds", INFINITY, iso.half) ||
            !number("q_value_mev", 1, iso.q) || !std::isfinite(iso.mass) || iso.mass < 0 || iso.mass > 1e10 ||
            std::isnan(iso.half) || !std::isfinite(iso.q) || std::abs(iso.q) > 1e10)
            return false;
        Variant channel = data.get("decay_channel", 0), fissile = data.get("is_fissile", false);
        if (channel.get_type() != Variant::INT || fissile.get_type() != Variant::BOOL ||
            int64_t(channel) < 0 || int64_t(channel) > 4)
            return false;
        iso.channel = int64_t(channel);
        if (iso.mass < 1e-8 && iso.channel != 0)
            return false;
        iso.fissile = bool(fissile);
        next.isotopes[string_value(key)] = iso;
    }
    for (auto key : {"He-4", "Electron", "Neutron", "Kr-92", "Ba-141"})
        if (next.isotopes.find(key) == next.isotopes.end())
            return false;
    if (!next.valid())
        return false;
    // Same engine utility RNG as the original GDScript, with no calls into GDScript.
    next.random = []() { return UtilityFunctions::randf(); };
    next.random_range = [](double a, double b) { return UtilityFunctions::randf_range(a, b); };
    solver = std::move(next);
    ready = true;
    ++revision;
    return true;
}
bool UniCoreNuclearSolver::advance(double dt) {
    if (!ready || tick == uint64_t(INT64_MAX) || !solver.advance(dt))
        return false;
    ++tick;
    ++revision;
    return true;
}
Dictionary UniCoreNuclearSolver::get_snapshot() const {
    Dictionary out;
    out["schema_version"] = 1;
    out["units"] = "simulation";
    out["revision"] = int64_t(revision);
    out["simulation_tick"] = int64_t(tick);
    out["ready"] = ready;
    out["rng_policy"] = "godot_global";
    out["rng_restorable"] = false;
    if (!ready)
        return out;
    out["half_life_multiplier"] = solver.multiplier;
    out["control_rod_depth"] = solver.rods;
    out["containment_radius"] = solver.radius;
    auto vector = [](unicore::Vec3 v) { return Vector3(v.x, v.y, v.z); };
    PackedVector3Array np, nv, rp, rv;
    PackedFloat32Array nm, nh, rm, rl;
    PackedInt32Array nc, rt;
    PackedByteArray na, ra;
    PackedStringArray nk;
    const size_t n = solver.nuclei.size(), r = solver.radiation.size();
    np.resize(n);
    nv.resize(n);
    nm.resize(n);
    nh.resize(n);
    nc.resize(n);
    na.resize(n);
    nk.resize(n);
    if (n) {
        auto pp = np.ptrw(), vv = nv.ptrw();
        auto mm = nm.ptrw(), hh = nh.ptrw();
        auto cc = nc.ptrw();
        auto aa = na.ptrw();
        for (size_t i = 0; i < n; ++i) {
            const auto &v = solver.nuclei[i];
            pp[i] = vector(v.p);
            vv[i] = vector(v.v);
            mm[i] = v.mass;
            hh[i] = v.half;
            cc[i] = v.channel;
            aa[i] = v.active;
            nk.set(i, String(v.key.c_str()));
        }
    }
    rp.resize(r);
    rv.resize(r);
    rm.resize(r);
    rl.resize(r);
    rt.resize(r);
    ra.resize(r);
    if (r) {
        auto pp = rp.ptrw(), vv = rv.ptrw();
        auto mm = rm.ptrw(), ll = rl.ptrw();
        auto tt = rt.ptrw();
        auto aa = ra.ptrw();
        for (size_t i = 0; i < r; ++i) {
            const auto &v = solver.radiation[i];
            pp[i] = vector(v.p);
            vv[i] = vector(v.v);
            mm[i] = v.mass;
            ll[i] = v.life;
            tt[i] = v.type;
            aa[i] = v.active;
        }
    }
    out["nuclei_positions"] = np;
    out["nuclei_velocities"] = nv;
    out["nuclei_masses"] = nm;
    out["nuclei_half_lives"] = nh;
    out["nuclei_channels"] = nc;
    out["nuclei_active"] = na;
    out["nuclei_isotope_keys"] = nk;
    out["rad_positions"] = rp;
    out["rad_velocities"] = rv;
    out["rad_masses"] = rm;
    out["rad_lifetimes"] = rl;
    out["rad_types"] = rt;
    out["rad_active"] = ra;
    out["active_nuclei_count"] = solver.active_nuclei;
    out["active_rad_count"] = solver.active_radiation;
    out["total_decay_events"] = solver.total_decays;
    out["total_fission_events"] = solver.total_fissions;
    out["total_energy"] = solver.energy();
    out["total_momentum"] = vector(solver.momentum());
    int64_t neutrons = 0;
    for (const auto &v : solver.radiation)
        if (v.active && v.type == 4)
            ++neutrons;
    out["neutron_count"] = neutrons;
    PackedInt32Array kinds, channels, prompts;
    PackedVector3Array positions;
    PackedStringArray symbols;
    PackedFloat64Array energies;
    for (const auto &event : solver.events) {
        kinds.append(event.type);
        channels.append(event.channel);
        prompts.append(event.prompt);
        positions.append(vector(event.position));
        symbols.append(String(event.symbol.c_str()));
        energies.append(event.energy);
    }
    out["event_types"] = kinds;
    out["event_channels"] = channels;
    out["event_prompt_counts"] = prompts;
    out["event_positions"] = positions;
    out["event_symbols"] = symbols;
    out["event_energies"] = energies;
    return out;
}
void UniCoreNuclearSolver::clear() {
    solver = {};
    ready = false;
    tick = 0;
    ++revision;
}
