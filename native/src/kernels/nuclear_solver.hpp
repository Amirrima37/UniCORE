#pragma once
#include "gravity_solver.hpp"
#include <string>
#include <map>
#include <functional>
namespace unicore {
struct Isotope {
    std::string symbol, daughter;
    double mass = 1, half = INFINITY, q = 1;
    int channel = 0;
    bool fissile = false;
};
struct Nucleus {
    Vec3 p, v;
    float mass = 1, half = INFINITY;
    int channel = 0;
    uint8_t active = 1;
    std::string key;
};
struct Radiation {
    Vec3 p, v;
    float mass = 0, life = 5;
    int type = 0;
    uint8_t active = 1;
};
struct NuclearEvent {
    int type = 0, channel = 0, prompt = 0;
    Vec3 position;
    std::string symbol;
    double energy = 0;
};
class NuclearSolver {
  public:
    std::vector<Nucleus> nuclei;
    std::vector<Radiation> radiation;
    std::map<std::string, Isotope> isotopes;
    std::vector<NuclearEvent> events;
    double multiplier = 1, rods = 0, radius = 40;
    int64_t active_nuclei = 0, active_radiation = 0, total_decays = 0, total_fissions = 0;
    std::function<double()> random;
    std::function<double(double, double)> random_range;
    bool valid() const {
        if (!std::isfinite(multiplier) || !std::isfinite(rods) || rods < 0 || rods > 1 ||
            !std::isfinite(radius) || radius <= 0 || radius > 1e12 || nuclei.size() > 10000 ||
            radiation.size() > 20000)
            return false;
        int64_t n = 0, r = 0;
        for (const auto &v : nuclei) {
            if (!finite(v.p) || !finite(v.v) || std::abs(v.p.x) > 1e12 || std::abs(v.p.y) > 1e12 ||
                std::abs(v.p.z) > 1e12 || std::abs(v.v.x) > 1e12 || std::abs(v.v.y) > 1e12 ||
                std::abs(v.v.z) > 1e12 || !std::isfinite(v.mass) ||
                (v.mass < 0 || (v.mass < 1e-8 && v.channel != 0)) || v.mass > 1e10 || std::isnan(v.half) ||
                v.active > 1 || v.channel < 0 || v.channel > 4)
                return false;
            n += v.active;
        }
        for (const auto &v : radiation) {
            if (!finite(v.p) || !finite(v.v) || std::abs(v.p.x) > 1e12 || std::abs(v.p.y) > 1e12 ||
                std::abs(v.p.z) > 1e12 || std::abs(v.v.x) > 1e12 || std::abs(v.v.y) > 1e12 ||
                std::abs(v.v.z) > 1e12 || !std::isfinite(v.mass) || v.mass < 0 || !std::isfinite(v.life) ||
                v.active > 1 || v.type < 0 || v.type > 4)
                return false;
            r += v.active;
        }
        return n == active_nuclei && r == active_radiation && total_decays >= 0 && total_fissions >= 0;
    }
    Vec3 direction() {
        double c = random_range(-1, 1), s = std::sqrt(std::max(0.0, 1 - c * c)),
               phi = random_range(0, 6.2831853071795864769);
        return {float(s * std::cos(phi)), float(s * std::sin(phi)), float(c)};
    }
    void spawn_rad(Vec3 p, Vec3 v, double mass, int type, double life) {
        Radiation value{p, v, float(mass), float(life), type, 1};
        for (auto &slot : radiation)
            if (slot.active == 0) {
                slot = value;
                ++active_radiation;
                return;
            }
        if (radiation.size() < 20000) {
            radiation.push_back(value);
            ++active_radiation;
        }
    }
    void spawn_nucleus(Vec3 p, Vec3 v, const std::string &key) {
        auto found = isotopes.find(key);
        if (found == isotopes.end())
            return;
        const auto &iso = found->second;
        Nucleus value{p, v, float(iso.mass), float(iso.half), iso.channel, 1, key};
        for (auto &slot : nuclei)
            if (!slot.active) {
                slot = value;
                ++active_nuclei;
                return;
            }
        if (nuclei.size() < 10000) {
            nuclei.push_back(value);
            ++active_nuclei;
        }
    }
    void decay(size_t i) {
        const auto found = isotopes.find(nuclei[i].key);
        if (found == isotopes.end())
            return;
        const Isotope iso = found->second;
        const auto parent = nuclei[i];
        const double mass = parent.mass;
        auto daughter_it = isotopes.find(iso.daughter);
        const Isotope *daughter = daughter_it == isotopes.end() ? nullptr : &daughter_it->second;
        if (parent.channel == 1 || parent.channel == 2) {
            double md = daughter ? daughter->mass : (parent.channel == 1 ? mass - 4 : mass);
            double emitted = isotopes.at(parent.channel == 1 ? "He-4" : "Electron").mass;
            if (md <= 0)
                return;
            double q = std::max(0.0001, (mass - (md + emitted)) * 2500.0);
            Vec3 new_velocity, particle_velocity;
            if (parent.channel == 1) {
                double pcm = std::sqrt(2 * q * emitted * md / (emitted + md));
                auto axis = direction();
                particle_velocity = plus(parent.v, axis.scaled(float(pcm / emitted)));
                new_velocity = minus(parent.v, axis.scaled(float(pcm / md)));
            } else {
                double fraction = random(), electron_energy = q * fraction,
                       neutrino_energy = q - electron_energy;
                double pe = std::sqrt(2 * emitted * electron_energy), pnu = neutrino_energy / 50.0;
                auto de = direction(), dn = direction();
                auto ep = de.scaled(float(pe)), np = dn.scaled(float(pnu));
                new_velocity = divide(minus(parent.v.scaled(float(mass)), plus(ep, np)), float(md));
                particle_velocity = plus(parent.v, divide(ep, float(emitted)));
            }
            nuclei[i].key = iso.daughter;
            nuclei[i].mass = float(md);
            nuclei[i].half = daughter ? float(daughter->half) : INFINITY;
            nuclei[i].channel = daughter ? daughter->channel : 0;
            nuclei[i].v = new_velocity;
            spawn_rad(parent.p, particle_velocity, emitted, parent.channel == 1 ? 1 : 2, 5);
            ++total_decays;
            events.push_back({0, parent.channel, 0, parent.p, iso.symbol, q});
        } else if (parent.channel == 3) {
            auto axis = direction();
            auto momentum = axis.scaled(float(iso.q / 50.0));
            nuclei[i].v = minus(parent.v, divide(momentum, float(mass)));
            spawn_rad(parent.p, axis.scaled(50), 0, 3, 5);
            ++total_decays;
            events.push_back({0, 3, 0, parent.p, iso.symbol, iso.q});
        }
    }
    void fission(size_t i, Vec3 incident) {
        auto parent = nuclei[i];
        double neutron = isotopes.at("Neutron").mass, compound = double(parent.mass) + neutron;
        auto momentum = plus(parent.v.scaled(parent.mass), incident.scaled(float(neutron)));
        auto velocity = divide(momentum, float(compound));
        int prompt = random() < 0.57 ? 2 : 3;
        double kr = isotopes.at("Kr-92").mass, ba = isotopes.at("Ba-141").mass;
        double defect = compound - (kr + ba + double(prompt) * neutron), q = std::max(20.0, defect * 2500.0),
               fragment_energy = q * 0.84, neutron_energy = q * 0.16 / double(prompt);
        double pcm = std::sqrt(2 * fragment_energy * kr * ba / (kr + ba));
        auto axis = direction();
        auto vk = plus(velocity, axis.scaled(float(pcm / kr))),
             vb = minus(velocity, axis.scaled(float(pcm / ba)));
        nuclei[i].key = "Ba-141";
        nuclei[i].mass = float(ba);
        nuclei[i].half = INFINITY;
        nuclei[i].channel = 0;
        nuclei[i].v = vb;
        spawn_nucleus(parent.p, vk, "Kr-92");
        double pn = std::sqrt(2 * neutron * neutron_energy);
        for (int j = 0; j < prompt; ++j)
            spawn_rad(parent.p, plus(velocity, direction().scaled(float(pn / neutron))), neutron, 4, 7.5);
        ++total_fissions;
        events.push_back({1, 0, prompt, parent.p, "", q});
    }
    bool advance(double dt) {
        if (!std::isfinite(dt) || dt <= 0 || dt > 1e6 || total_decays > INT64_MAX - 10000 ||
            total_fissions > INT64_MAX - 20000 || !valid() || !random || !random_range)
            return false;
        auto next = *this;
        next.events.clear();
        const size_t initial_nuclei = next.nuclei.size();
        for (size_t i = 0; i < initial_nuclei; ++i) {
            if (!next.nuclei[i].active)
                continue;
            double half = double(next.nuclei[i].half) * multiplier;
            if (std::isinf(half) || half <= 0)
                continue;
            double probability = 1 - std::exp(-(0.69314718056 / half) * dt);
            if (next.random() < probability)
                next.decay(i);
        }
        if (next.active_nuclei && next.active_radiation) {
            std::vector<size_t> fissile;
            std::unordered_map<Cell, std::vector<size_t>, CellHash> grid;
            for (size_t i = 0; i < next.nuclei.size(); ++i) {
                auto found = next.isotopes.find(next.nuclei[i].key);
                if (next.nuclei[i].active && found != next.isotopes.end() && found->second.fissile) {
                    auto p = next.nuclei[i].p;
                    grid[{int64_t(std::floor(double(p.x) * 2)), int64_t(std::floor(double(p.y) * 2)),
                          int64_t(std::floor(double(p.z) * 2))}]
                        .push_back(i);
                    fissile.push_back(i);
                }
            }
            if (!fissile.empty()) {
                size_t count = next.radiation.size();
                for (size_t r = 0; r < count; ++r) {
                    if (!next.radiation[r].active || next.radiation[r].type != 4)
                        continue;
                    if (rods > 0 && next.random() < rods * 0.95) {
                        next.radiation[r].active = 0;
                        --next.active_radiation;
                        continue;
                    }
                    auto p = next.radiation[r].p;
                    size_t hit = SIZE_MAX;
                    for (int64_t x = std::floor((double(p.x) - 0.25) * 2);
                         x <= int64_t(std::floor((double(p.x) + 0.25) * 2)); ++x)
                        for (int64_t y = std::floor((double(p.y) - 0.25) * 2);
                             y <= int64_t(std::floor((double(p.y) + 0.25) * 2)); ++y)
                            for (int64_t z = std::floor((double(p.z) - 0.25) * 2);
                                 z <= int64_t(std::floor((double(p.z) + 0.25) * 2)); ++z) {
                                auto bucket = grid.find({x, y, z});
                                if (bucket != grid.end())
                                    for (auto i : bucket->second)
                                        if (minus(p, next.nuclei[i].p).length_squared() <= 0.0625)
                                            hit = std::min(hit, i);
                            }
                    if (hit != SIZE_MAX) {
                        auto incident = next.radiation[r].v;
                        next.radiation[r].active = 0;
                        --next.active_radiation;
                        next.fission(hit, incident);
                    }
                }
            }
        }
        for (auto &n : next.nuclei)
            if (n.active) {
                auto p = plus(n.p, n.v.scaled(float(dt)));
                if (double(p.length_squared()) > radius * radius) {
                    n.v = n.v.scaled(-1).scaled(0.8f);
                    p = divide(p, std::sqrt(p.length_squared())).scaled(float(radius));
                }
                n.p = p;
            }
        for (auto &r : next.radiation)
            if (r.active)
                r.p.add(r.v.scaled(float(dt)));
        next.active_radiation = 0;
        for (auto &r : next.radiation)
            if (r.active) {
                r.life = float(double(r.life) - dt);
                if (r.life <= 0 || double(r.p.length_squared()) > (radius * 2) * (radius * 2))
                    r.active = 0;
                else
                    ++next.active_radiation;
            }
        if (!next.valid())
            return false;
        *this = std::move(next);
        return true;
    }
    double energy() const {
        double value = 0;
        for (const auto &n : nuclei)
            if (n.active)
                value += double(n.mass) * 2500.0 + 0.5 * double(n.mass) * n.v.length_squared();
        for (const auto &r : radiation)
            if (r.active)
                value +=
                    r.type == 3 ? 1.0 : double(r.mass) * 2500.0 + 0.5 * double(r.mass) * r.v.length_squared();
        return value;
    }
    Vec3 momentum() const {
        Vec3 total{};
        for (const auto &n : nuclei)
            if (n.active)
                total.add(n.v.scaled(n.mass));
        for (const auto &r : radiation)
            if (r.active) {
                if (r.type == 3) {
                    float length = std::sqrt(r.v.length_squared());
                    total.add((length ? divide(r.v, length) : Vec3{}).scaled(float(1.0 / 50.0)));
                } else
                    total.add(r.v.scaled(r.mass));
            }
        return total;
    }
};
} // namespace unicore
