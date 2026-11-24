// Parse-only stand-in for the freestanding <stddef.h> shipped in an
// Emscripten sysroot; see emscripten.h. Declaring size_t here (instead of
// letting Clang's builtin header define it) makes ffigen_js emit the
// `typedef size_t = int;` alias the checked-in bindings use.
#pragma once

typedef __SIZE_TYPE__ size_t;
typedef __PTRDIFF_TYPE__ ptrdiff_t;
typedef __WCHAR_TYPE__ wchar_t;
typedef struct {
  long long __max_align_ll;
  long double __max_align_ld;
} max_align_t;
#define offsetof(t, m) __builtin_offsetof(t, m)
