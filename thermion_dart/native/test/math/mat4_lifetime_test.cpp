#include "c_api/TMat4.h"
#include <math/mat4.h>
#include <cassert>
#include <cstdlib>
#include <new>

// Test-only allocation instrumentation. TMat4.cpp is a separate translation
// unit and uses nothrow new; no production counter or allocator is introduced.
static void* active = nullptr;
static unsigned allocations = 0;
static unsigned frees = 0;
static bool failNext = false;

void* operator new(std::size_t size, const std::nothrow_t&) noexcept {
    assert(active == nullptr);
    assert(size == sizeof(filament::math::mat4));
    if (failNext) {
        failNext = false;
        return nullptr;
    }
    active = std::malloc(size);
    if (active) ++allocations;
    return active;
}

void operator delete(void* pointer) noexcept {
    if (pointer && pointer == active) {
        active = nullptr;
        ++frees;
    }
    std::free(pointer);
}

int main() {
    for (unsigned i = 0; i < 100000; ++i) {
        auto* matrix = Mat4_create();
        assert(matrix);
        auto* data = Mat4_getData(matrix);
        for (unsigned j = 0; j < 16; ++j) {
            assert(data[j] == (j % 5 == 0 ? 1.0 : 0.0));
            data[j] = i + j * 0.25;
        }
        auto* actual = reinterpret_cast<filament::math::mat4*>(matrix);
        assert((*actual)[3][3] == i + 15 * 0.25);
        Mat4_destroy(matrix);
        assert(allocations == frees);
        assert(active == nullptr);
    }
    failNext = true;
    assert(Mat4_create() == nullptr);
    Mat4_destroy(nullptr);
    assert(allocations == 100000 && frees == allocations && !failNext);
}
