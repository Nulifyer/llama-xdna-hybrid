#include "xdna-plan.h"
#include <iostream>
#include <limits>
#include <stdexcept>

int main() {
    using namespace xdna_plan;
    auto check = [](bool ok) { if (!ok) throw std::runtime_error("planner contract failed"); };
    check(eligible(prefill, 2048, 1024));
    check(!eligible(prefill, 13, 1024));
    check(!eligible(decode, 2048, 1024));
    check(!eligible(mixed, 2048, 1024));
    check(!eligible(verify, 2048, 1024));
    check(eligible(automatic, 2048, 1024));
    constexpr double gib = 1024.0 * 1024 * 1024;
    check(copy_budget(10*gib, 24*gib, 100*gib) == 6*gib);
    check(copy_budget(3*gib, 24*gib, 100*gib) == 0);
    check(copy_budget(10*gib, 24*gib, 2*gib) == 2*gib);
    for (double bad : {-1.0, std::numeric_limits<double>::infinity(), std::numeric_limits<double>::quiet_NaN()}) {
        bool rejected = false;
        try { copy_budget(10*gib, 24*gib, bad); } catch (const std::invalid_argument &) { rejected = true; }
        check(rejected);
    }
    std::cout << "PASS: phase gates, short tails, decode batches, mixed/verify and hard memory budget\n";
}
