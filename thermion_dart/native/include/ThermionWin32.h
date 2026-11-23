#pragma once

// Feature switches (gltf / ktx / image_decoding user defines) shared with the
// sources that include this header on Windows.
//
// Windows link inputs are NOT declared here any more: they live in the single
// link list in hook/build.dart (`libs`), which the build hook passes to
// CBuilder's `libraries` for Windows. That keeps the feature conditions and
// the platform library set in one place instead of a second hand-maintained
// copy of the list in #pragma comment(lib) directives.
#include "ThermionFeatures.h"
