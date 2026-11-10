#pragma once
#include "molecular_solver.hpp"
namespace unicore {
inline Vec3 divide(Vec3 v, float s) {
    return {v.x / s, v.y / s, v.z / s};
}
inline float dot(Vec3 a, Vec3 b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}
struct GravityConfig {
    double g = 1, theta = 0.5, softening = 0.05, c = 50;
    bool relativity = true;
    int64_t pn = 2, primary = 0;
    bool valid() const {
        return std::isfinite(g) && std::isfinite(theta) && theta >= 0 && std::isfinite(softening) &&
               softening >= 0 && std::isfinite(c) && c > 0 && pn >= 0 && pn <= 2;
    }
};
class GravityTree {
    struct Node {
        Vec3 origin, size, center, com, pos;
        double mass = 0, particle_mass = 0;
        int particle = -1, depth = 0;
        bool empty = true, leaf = true;
        std::array<int, 8> children;
        std::vector<size_t> coincident;
        Node() {
            children.fill(-1);
        }
    };
    std::vector<Node> nodes;
    const std::vector<Vec3> *positions = nullptr;
    const std::vector<float> *masses = nullptr;
    int add(Vec3 origin, Vec3 size, int depth) {
        Node n;
        n.origin = origin;
        n.size = size;
        n.center = plus(origin, size.scaled(0.5f));
        n.depth = depth;
        nodes.push_back(n);
        return int(nodes.size() - 1);
    }
    int octant(Vec3 c, Vec3 p) const {
        return (p.x >= c.x ? 1 : 0) | (p.y >= c.y ? 2 : 0) | (p.z >= c.z ? 4 : 0);
    }
    int child(int parent, int k) {
        if (nodes[parent].children[k] >= 0)
            return nodes[parent].children[k];
        auto half = nodes[parent].size.scaled(0.5f);
        auto origin = nodes[parent].origin;
        if (k & 1)
            origin.x += half.x;
        if (k & 2)
            origin.y += half.y;
        if (k & 4)
            origin.z += half.z;
        int result = add(origin, half, nodes[parent].depth + 1);
        nodes[parent].children[k] = result;
        return result;
    }
    bool approximate(Vec3 a, Vec3 b) const {
        auto eq = [](float x, float y) {
            return x == y || std::abs(x - y) < std::max(1e-5f, 1e-5f * std::abs(x));
        };
        return eq(a.x, b.x) && eq(a.y, b.y) && eq(a.z, b.z);
    }
    void update(int current, Vec3 pos, double mass) {
        auto &n = nodes[current];
        double total = n.mass + mass;
        n.com = total > 1e-12
                    ? divide(plus(n.com.scaled(float(n.mass)), pos.scaled(float(mass))), float(total))
                    : pos;
        n.mass = total;
    }
    void insert(size_t i) {
        int current = 0;
        Vec3 p = (*positions)[i];
        double mass = std::max(0.0, double((*masses)[i]));
        while (true) {
            if (nodes[current].empty) {
                auto &n = nodes[current];
                n.empty = false;
                n.particle = int(i);
                n.pos = p;
                n.particle_mass = mass;
                n.mass = mass;
                n.com = p;
                return;
            }
            if (nodes[current].leaf) {
                if (nodes[current].depth >= 32 || approximate(p, nodes[current].pos)) {
                    auto &n = nodes[current];
                    if (n.coincident.empty())
                        n.coincident.push_back(n.particle);
                    n.coincident.push_back(i);
                    update(current, p, mass);
                    return;
                }
                nodes[current].leaf = false;
                auto old_pos = nodes[current].pos;
                int old_index = nodes[current].particle;
                double old_mass = nodes[current].particle_mass;
                nodes[current].particle = -1;
                int old_child = child(current, octant(nodes[current].center, old_pos));
                auto &n = nodes[old_child];
                n.empty = false;
                n.pos = old_pos;
                n.particle = old_index;
                n.particle_mass = old_mass;
                n.mass = old_mass;
                n.com = old_pos;
            }
            update(current, p, mass);
            current = child(current, octant(nodes[current].center, p));
        }
    }

  public:
    void build(const std::vector<Vec3> &p, const std::vector<float> &m) {
        nodes.clear();
        positions = &p;
        masses = &m;
        if (p.empty())
            return;
        Vec3 lo = p[0], hi = p[0];
        for (auto v : p) {
            lo = {std::min(lo.x, v.x), std::min(lo.y, v.y), std::min(lo.z, v.z)};
            hi = {std::max(hi.x, v.x), std::max(hi.y, v.y), std::max(hi.z, v.z)};
        }
        auto extent = minus(hi, lo);
        double dimension = std::max({double(extent.x), double(extent.y), double(extent.z), 1e-4});
        auto center = plus(lo, hi).scaled(0.5f);
        double half = dimension * 0.5 * 1.02;
        add(minus(center, {float(half), float(half), float(half)}),
            {float(half * 2), float(half * 2), float(half * 2)}, 0);
        for (size_t i = 0; i < p.size(); ++i)
            insert(i);
    }
    void query(size_t index, Vec3 target, const GravityConfig &config, Vec3 &acc, double &potential) const {
        acc = {};
        potential = 0;
        if (nodes.empty())
            return;
        std::vector<int> stack{0};
        auto accumulate = [&](Vec3 p, double mass) {
            auto r = minus(p, target);
            double denom = double(r.length_squared()) + config.softening * config.softening;
            if (denom > 1e-12) {
                double inv = 1.0 / std::sqrt(denom);
                double inv3 = inv * inv * inv;
                acc.add(r.scaled(float(config.g * mass * inv3)));
                potential -= config.g * mass / std::sqrt(denom);
            }
        };
        while (!stack.empty()) {
            int current = stack.back();
            stack.pop_back();
            const auto &n = nodes[current];
            if (n.empty)
                continue;
            if (n.leaf) {
                if (n.coincident.empty()) {
                    if (n.particle >= 0 && size_t(n.particle) != index)
                        accumulate(n.pos, n.particle_mass);
                } else
                    for (auto i : n.coincident)
                        if (i != index)
                            accumulate((*positions)[i], (*masses)[i]);
                continue;
            }
            auto r = minus(n.com, target);
            double d2 = r.length_squared();
            double size = double(n.size.x);
            if (size * size <= config.theta * config.theta * d2)
                accumulate(n.com, n.mass);
            else
                for (int c = 0; c < 8; ++c)
                    if (n.children[c] >= 0 && !nodes[n.children[c]].empty)
                        stack.push_back(n.children[c]);
        }
    }
};
class GravitySolver {
  public:
    GravityConfig config;
    MolecularState state;
    bool valid_state(const MolecularState &s) const {
        if (s.positions.size() != s.velocities.size() || s.positions.size() != s.masses.size())
            return false;
        for (size_t i = 0; i < s.positions.size(); ++i)
            if (!finite(s.positions[i]) || !finite(s.velocities[i]) || !std::isfinite(s.masses[i]) ||
                std::abs(s.positions[i].x) > 1e15 || std::abs(s.positions[i].y) > 1e15 ||
                std::abs(s.positions[i].z) > 1e15)
                return false;
        return true;
    }
    bool evaluate_state(const MolecularState &s, std::vector<Vec3> &forces, double &potential) const {
        if (!config.valid() || !valid_state(s))
            return false;
        GravityTree tree;
        tree.build(s.positions, s.masses);
        forces.resize(s.positions.size());
        potential = 0;
        const size_t n = s.positions.size();
        const double c2 = config.c * config.c, e2 = config.softening * config.softening;
        size_t primary = n ? size_t(std::clamp<int64_t>(config.primary, 0, n - 1)) : 0;
        for (size_t i = 0; i < n; ++i) {
            Vec3 a;
            double phi;
            tree.query(i, s.positions[i], config, a, phi);
            potential += double(s.masses[i]) * phi;
            if (config.relativity && config.pn != 0) {
                Vec3 correction{};
                auto pair = [&](size_t j) {
                    auto r = minus(s.positions[j], s.positions[i]);
                    double d2 = double(r.length_squared()) + e2, d = std::sqrt(d2),
                           gm = config.g * double(s.masses[j]);
                    return r.scaled(float(5.0 * gm / d)).scaled(float(gm / (c2 * d2 * d)));
                };
                if (config.pn == 1) {
                    if (i != primary)
                        correction = pair(primary);
                } else
                    for (size_t j = 0; j < std::min(n, size_t(64)); ++j)
                        if (i != j)
                            correction.add(pair(j));
                a.add(correction);
            }
            if (config.relativity && !(config.pn != 0 && config.primary >= 0)) {
                double beta = std::clamp(double(s.velocities[i].length_squared()) / c2, 0.0, 0.999);
                double gamma = 1 / std::sqrt(1 - beta);
                a = divide(minus(a, s.velocities[i].scaled(float(double(dot(a, s.velocities[i])) / c2))),
                           float(gamma));
            }
            forces[i] = a.scaled(s.masses[i]);
            if (!finite(forces[i]))
                return false;
        }
        potential *= 0.5;
        return std::isfinite(potential);
    }
    bool evaluate(const std::vector<Vec3> &p, std::vector<Vec3> &f, double &energy) const {
        auto s = state;
        s.positions = p;
        return evaluate_state(s, f, energy);
    }
    bool advance(double dt, int substeps) {
        if (!std::isfinite(dt) || dt <= 0 || substeps < 1 || substeps > 10000 || !valid_state(state) ||
            !config.valid() || state.tick > uint64_t(INT64_MAX) - uint64_t(substeps))
            return false;
        auto next = state;
        std::vector<Vec3> a0(next.positions.size());
        double ignored;
        for (int k = 0; k < substeps; ++k) {
            if (dt >= 1e-5 && !next.positions.empty()) {
                if (!evaluate_state(next, next.forces, ignored))
                    return false;
                for (size_t i = 0; i < next.positions.size(); ++i) {
                    a0[i] = next.forces[i].scaled(float(1.0 / std::max(double(next.masses[i]), 1e-12)));
                    next.positions[i].add(
                        plus(next.velocities[i].scaled(float(dt)), a0[i].scaled(float(0.5 * dt * dt))));
                }
                if (!evaluate_state(next, next.forces, ignored))
                    return false;
                for (size_t i = 0; i < next.velocities.size(); ++i) {
                    auto a1 = next.forces[i].scaled(float(1.0 / std::max(double(next.masses[i]), 1e-12)));
                    next.velocities[i].add(plus(a0[i], a1).scaled(float(0.5 * dt)));
                }
            }
            if (config.relativity)
                for (auto &v : next.velocities) {
                    double length = std::sqrt(v.length_squared()), maximum = config.c * 0.9995;
                    if (length >= maximum)
                        v = v.scaled(float(maximum / length));
                }
            if (!valid_state(next))
                return false;
            ++next.tick;
        }
        state = std::move(next);
        return true;
    }
};
} // namespace unicore
