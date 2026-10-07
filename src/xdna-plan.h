#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <stdexcept>

namespace xdna_plan {
enum phase : uint32_t { automatic = 0, prefill = 1, decode = 2, mixed = 3, verify = 4 };

inline bool eligible(uint32_t p, int64_t rows, int64_t threshold) {
    return (p == automatic || p == prefill) && rows >= threshold;
}

inline double copy_budget(double available, double total, double requested) {
    if (!std::isfinite(requested) || requested < 0) {
        throw std::invalid_argument("NPU copy budget must be finite and nonnegative");
    }
    const double reserve = std::max(4.0 * 1024 * 1024 * 1024, total / 10.0);
    return std::min(requested, std::max(0.0, available - reserve));
}
}
