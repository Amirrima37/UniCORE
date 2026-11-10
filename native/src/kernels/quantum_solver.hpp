#pragma once
#include <vector>
#include <cmath>
#include <algorithm>
#include <cstdint>
namespace unicore {
// Reads promote float storage to double, exactly as GDScript packed-array indexing does.
struct FloatBuffer {
    std::vector<float> values;
    struct Reference {
        float &value;
        operator double() const {
            return value;
        }
        Reference &operator=(double v) {
            value = float(v);
            return *this;
        }
        Reference &operator=(const Reference &v) {
            return *this = double(v);
        }
        Reference &operator+=(double v) {
            return *this = double(*this) + v;
        }
        Reference &operator-=(double v) {
            return *this = double(*this) - v;
        }
    };
    double operator[](int64_t i) const {
        return values[size_t(i)];
    }
    Reference operator[](int64_t i) {
        return {values[size_t(i)]};
    }
    int64_t size() const {
        return int64_t(values.size());
    }
    void resize(int64_t n) {
        values.resize(size_t(n));
    }
};
struct IntegerRange {
    int64_t first, last, step;
    struct Iterator {
        int64_t value, last, step;
        int64_t operator*() const {
            return value;
        }
        void operator++() {
            value += step;
        }
        bool operator!=(const Iterator &) const {
            return step > 0 ? value < last : value > last;
        }
    };
    Iterator begin() const {
        return {first, last, step};
    }
    Iterator end() const {
        return {last, last, step};
    }
};
inline IntegerRange range(int64_t n) {
    return {0, n, 1};
}
inline IntegerRange range(int64_t a, int64_t b) {
    return {a, b, 1};
}
inline IntegerRange range(int64_t a, int64_t b, int64_t step) {
    return {a, b, step};
}
inline double maxf(double a, double b) {
    return std::max(a, b);
}
class QuantumSolver {
  public:
    int64_t active_dimension = 1, grid_size_1d = 0, grid_size_2d_x = 0, grid_size_2d_z = 0;
    double domain_length_1d = 24, barrier_center_x = 0, barrier_width_d = 0.8;
    struct {
        float x = 16, y = 16;
    } domain_size_2d;
    FloatBuffer psi_real_1d, psi_imag_1d, potential_1d, prob_density_1d, psi_real_2d, psi_imag_2d,
        potential_2d, prob_density_2d;
    uint64_t tick = 0;
    bool finite_state() const {
        const FloatBuffer *selected[] = {active_dimension == 1 ? &psi_real_1d : &psi_real_2d,
                                         active_dimension == 1 ? &psi_imag_1d : &psi_imag_2d,
                                         active_dimension == 1 ? &potential_1d : &potential_2d,
                                         active_dimension == 1 ? &prob_density_1d : &prob_density_2d};
        for (auto buffer : selected)
            for (float v : buffer->values)
                if (!std::isfinite(v))
                    return false;
        return true;
    }
    bool advance(double dt, int64_t steps) {
        if (!std::isfinite(dt) || dt <= 0 || steps < 1 || steps > 10000 ||
            tick > uint64_t(INT64_MAX) - uint64_t(steps))
            return false;
        auto next = *this;
        for (int64_t i = 0; i < steps; ++i) {
            if (active_dimension == 1) {
                next._evolve_1d_cayley(dt);
                next._update_prob_density_1d();
            } else {
                next._evolve_2d_staggered(dt);
                next._update_prob_density_2d();
            }
            if (!next.finite_state() || !std::isfinite(next.compute_norm()) ||
                !std::isfinite(next.compute_mean_position()) ||
                !std::isfinite(next.compute_expectation_energy()) ||
                !std::isfinite(next.compute_transmission()) || !std::isfinite(next.compute_reflection()))
                return false;
            ++next.tick;
        }
        *this = std::move(next);
        return true;
    }
    void _evolve_1d_cayley(double dt) {
        int64_t n = grid_size_1d;
        if (n < 3) {
            return;
        }
        double dx = domain_length_1d / double(n - 1);
        double alpha = dt / (4.0 * dx * dx);
        FloatBuffer cp_r = FloatBuffer();
        FloatBuffer cp_i = FloatBuffer();
        FloatBuffer dp_r = FloatBuffer();
        FloatBuffer dp_i = FloatBuffer();
        cp_r.resize(n);
        cp_i.resize(n);
        dp_r.resize(n);
        dp_i.resize(n);
        FloatBuffer chi_r = FloatBuffer();
        FloatBuffer chi_i = FloatBuffer();
        chi_r.resize(n);
        chi_i.resize(n);
        for (auto j : range(1, n - 1)) {
            double v_term = dt * potential_1d[j] * 0.5;
            double diag_r = 1.0;
            double diag_i = -(2.0 * alpha + v_term);
            double lap_r = -alpha * (psi_imag_1d[j - 1] + psi_imag_1d[j + 1]);
            double lap_i = alpha * (psi_real_1d[j - 1] + psi_real_1d[j + 1]);
            chi_r[j] = diag_r * psi_real_1d[j] - diag_i * psi_imag_1d[j] + lap_r;
            chi_i[j] = diag_r * psi_imag_1d[j] + diag_i * psi_real_1d[j] + lap_i;
        }
        cp_r[0] = 0.0;
        cp_i[0] = 0.0;
        dp_r[0] = 0.0;
        dp_i[0] = 0.0;
        for (auto j : range(1, n - 1)) {
            double v_term = dt * potential_1d[j] * 0.5;
            double denom_r = 1.0 - alpha * cp_i[j - 1];
            double denom_i = (2.0 * alpha + v_term) + alpha * cp_r[j - 1];
            double denom_mag_sq = denom_r * denom_r + denom_i * denom_i;
            if (denom_mag_sq < 1e-24) {
                denom_mag_sq = 1e-24;
            }
            cp_r[j] = (-alpha * denom_i) / denom_mag_sq;
            cp_i[j] = (-alpha * denom_r) / denom_mag_sq;
            double num_r = chi_r[j] - alpha * dp_i[j - 1];
            double num_i = chi_i[j] + alpha * dp_r[j - 1];
            dp_r[j] = (num_r * denom_r + num_i * denom_i) / denom_mag_sq;
            dp_i[j] = (num_i * denom_r - num_r * denom_i) / denom_mag_sq;
        }
        psi_real_1d[n - 1] = 0.0;
        psi_imag_1d[n - 1] = 0.0;
        for (auto j : range(n - 2, 0, -1)) {
            double next_r = psi_real_1d[j + 1];
            double next_i = psi_imag_1d[j + 1];
            double prod_r = cp_r[j] * next_r - cp_i[j] * next_i;
            double prod_i = cp_r[j] * next_i + cp_i[j] * next_r;
            psi_real_1d[j] = dp_r[j] - prod_r;
            psi_imag_1d[j] = dp_i[j] - prod_i;
        }
        psi_real_1d[0] = 0.0;
        psi_imag_1d[0] = 0.0;
    }

    void _update_prob_density_1d() {
        int64_t n = grid_size_1d;
        for (auto j : range(n)) {
            double r = psi_real_1d[j];
            double i = psi_imag_1d[j];
            prob_density_1d[j] = r * r + i * i;
        }
    }

    void _evolve_2d_staggered(double dt) {
        int64_t nx = grid_size_2d_x;
        int64_t nz = grid_size_2d_z;
        double dx = domain_size_2d.x / double(nx - 1);
        double dz = domain_size_2d.y / double(nz - 1);
        double inv_dx2 = 1.0 / (dx * dx);
        double inv_dz2 = 1.0 / (dz * dz);
        for (auto z : range(1, nz - 1)) {
            int64_t row = z * nx;
            for (auto x : range(1, nx - 1)) {
                int64_t idx = row + x;
                double lap =
                    ((psi_imag_2d[idx + 1] + psi_imag_2d[idx - 1] - 2.0 * psi_imag_2d[idx]) * inv_dx2 +
                     (psi_imag_2d[idx + nx] + psi_imag_2d[idx - nx] - 2.0 * psi_imag_2d[idx]) * inv_dz2);
                double h_psi_i = -0.5 * lap + potential_2d[idx] * psi_imag_2d[idx];
                psi_real_2d[idx] += dt * h_psi_i;
            }
        }
        for (auto z : range(1, nz - 1)) {
            int64_t row = z * nx;
            for (auto x : range(1, nx - 1)) {
                int64_t idx = row + x;
                double lap =
                    ((psi_real_2d[idx + 1] + psi_real_2d[idx - 1] - 2.0 * psi_real_2d[idx]) * inv_dx2 +
                     (psi_real_2d[idx + nx] + psi_real_2d[idx - nx] - 2.0 * psi_real_2d[idx]) * inv_dz2);
                double h_psi_r = -0.5 * lap + potential_2d[idx] * psi_real_2d[idx];
                psi_imag_2d[idx] -= dt * h_psi_r;
            }
        }
    }

    void _update_prob_density_2d() {
        int64_t total = grid_size_2d_x * grid_size_2d_z;
        for (auto i : range(total)) {
            double r = psi_real_2d[i];
            double im = psi_imag_2d[i];
            prob_density_2d[i] = r * r + im * im;
        }
    }

    double compute_norm() {
        if (active_dimension == 1) {
            int64_t n = grid_size_1d;
            if (n == 0 || prob_density_1d.size() != n) {
                return 0.0;
            }
            double dx = domain_length_1d / double(n - 1);
            double total_sum = 0.0;
            for (auto j : range(n)) {
                total_sum += prob_density_1d[j];
            }
            return total_sum * dx;
        } else {
            int64_t total = grid_size_2d_x * grid_size_2d_z;
            if (total == 0 || prob_density_2d.size() != total) {
                return 0.0;
            }
            double dx = domain_size_2d.x / double(grid_size_2d_x - 1);
            double dz = domain_size_2d.y / double(grid_size_2d_z - 1);
            double total_sum = 0.0;
            for (auto i : range(total)) {
                total_sum += prob_density_2d[i];
            }
            return total_sum * (dx * dz);
        }
    }

    double compute_mean_position() {
        if (active_dimension == 1) {
            int64_t n = grid_size_1d;
            double dx = domain_length_1d / double(n - 1);
            double x_start = -domain_length_1d * 0.5;
            double weighted_x = 0.0;
            double total_prob = 0.0;
            for (auto j : range(n)) {
                double x = x_start + double(j) * dx;
                double rho = prob_density_1d[j];
                weighted_x += x * rho;
                total_prob += rho;
            }
            return weighted_x / maxf(1e-12, total_prob);
        } else {
            int64_t nx = grid_size_2d_x;
            int64_t nz = grid_size_2d_z;
            double dx = domain_size_2d.x / double(nx - 1);
            double x_start = -domain_size_2d.x * 0.5;
            double weighted_x = 0.0;
            double total_prob = 0.0;
            for (auto z : range(nz)) {
                int64_t row = z * nx;
                for (auto x : range(nx)) {
                    double x_pos = x_start + double(x) * dx;
                    double rho = prob_density_2d[row + x];
                    weighted_x += x_pos * rho;
                    total_prob += rho;
                }
            }
            return weighted_x / maxf(1e-12, total_prob);
        }
    }

    double compute_expectation_energy() {
        if (active_dimension == 1) {
            int64_t n = grid_size_1d;
            if (n < 3) {
                return 0.0;
            }
            double dx = domain_length_1d / double(n - 1);
            double inv_two_dx = 1.0 / (2.0 * dx);
            double e_total = 0.0;
            for (auto j : range(1, n - 1)) {
                double d_real = (psi_real_1d[j + 1] - psi_real_1d[j - 1]) * inv_two_dx;
                double d_imag = (psi_imag_1d[j + 1] - psi_imag_1d[j - 1]) * inv_two_dx;
                double t_dens = 0.5 * (d_real * d_real + d_imag * d_imag);
                double v_dens = potential_1d[j] * prob_density_1d[j];
                e_total += (t_dens + v_dens) * dx;
            }
            return e_total;
        } else {
            return 0.0;
        }
    }

    double compute_transmission() {
        double x_right = barrier_center_x + barrier_width_d * 0.5;
        if (active_dimension == 1) {
            int64_t n = grid_size_1d;
            double dx = domain_length_1d / double(n - 1);
            double x_start = -domain_length_1d * 0.5;
            double sum_trans = 0.0;
            for (auto j : range(n)) {
                double x = x_start + double(j) * dx;
                if (x > x_right) {
                    sum_trans += prob_density_1d[j];
                }
            }
            double current_n = compute_norm();
            return (sum_trans * dx) / maxf(1e-12, current_n);
        } else {
            int64_t nx = grid_size_2d_x;
            int64_t nz = grid_size_2d_z;
            double dx = domain_size_2d.x / double(nx - 1);
            double dz = domain_size_2d.y / double(nz - 1);
            double x_start = -domain_size_2d.x * 0.5;
            double sum_trans = 0.0;
            for (auto z : range(nz)) {
                int64_t row = z * nx;
                for (auto x : range(nx)) {
                    double x_pos = x_start + double(x) * dx;
                    if (x_pos > x_right) {
                        sum_trans += prob_density_2d[row + x];
                    }
                }
            }
            double current_n = compute_norm();
            return (sum_trans * dx * dz) / maxf(1e-12, current_n);
        }
    }

    double compute_reflection() {
        double x_left = barrier_center_x - barrier_width_d * 0.5;
        if (active_dimension == 1) {
            int64_t n = grid_size_1d;
            double dx = domain_length_1d / double(n - 1);
            double x_start = -domain_length_1d * 0.5;
            double sum_ref = 0.0;
            for (auto j : range(n)) {
                double x = x_start + double(j) * dx;
                if (x < x_left) {
                    sum_ref += prob_density_1d[j];
                }
            }
            double current_n = compute_norm();
            return (sum_ref * dx) / maxf(1e-12, current_n);
        } else {
            return 1.0 - compute_transmission();
        }
    }
};
} // namespace unicore
