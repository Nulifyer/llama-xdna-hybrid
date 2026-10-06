#include "xdna-platform.h"
#include <algorithm>
#include <fstream>
#include <limits>
#include <string>
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#else
#include <sys/sysinfo.h>
#endif

xdna_memory xdna_system_memory() {
#ifdef _WIN32
    MEMORYSTATUSEX m = {};
    m.dwLength = sizeof(m);
    if (!GlobalMemoryStatusEx(&m)) return {};
    return {m.ullTotalPhys, m.ullAvailPhys};
#else
    struct sysinfo m = {};
    if (sysinfo(&m) != 0) return {};
    xdna_memory result{uint64_t(m.totalram) * m.mem_unit, uint64_t(m.freeram) * m.mem_unit};
    std::ifstream meminfo("/proc/meminfo");
    std::string key, line;
    uint64_t kb;
    while (meminfo >> key >> kb) {
        std::getline(meminfo, line);
        if (key == "MemAvailable:") { result.available = kb * 1024; break; }
    }
    // Bound the default budget by the container's remaining cgroup-v2 RAM.
    std::ifstream limit_file("/sys/fs/cgroup/memory.max"), used_file("/sys/fs/cgroup/memory.current");
    uint64_t limit, used;
    if (limit_file >> limit && used_file >> used) {
        result.total = std::min(result.total, limit);
        result.available = std::min(result.available, used < limit ? limit - used : uint64_t(0));
    }
    return result;
#endif
}
