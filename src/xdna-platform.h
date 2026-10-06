#pragma once
#include <cstdint>
struct xdna_memory { uint64_t total = 0; uint64_t available = 0; };
xdna_memory xdna_system_memory();
