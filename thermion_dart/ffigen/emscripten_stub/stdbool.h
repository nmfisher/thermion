// Parse-only stand-in for the C99 <stdbool.h> shipped in an Emscripten
// sysroot; see emscripten.h. APIExport.h copies LLVM's stdbool.h instead of
// including it, but newer Clang defaults can select a C standard whose
// <stdbool.h> leaves `bool` undefined; defining it here keeps the parsed
// parameter type a real _Bool (and the generated Dart type `bool`).
#pragma once

#define bool _Bool
#define true 1
#define false 0
#define __bool_true_false_are_defined 1
