#include <filament/ToneMapper.h>
#include "ColorSpaceUtils.h"
extern "C" void display_transform(float* rgba, int count) {
    filament::ACESToneMapper mapper;
    for (int i = 0; i < count; ++i) {
        using namespace filament;
        float3 color{rgba[4*i], rgba[4*i+1], rgba[4*i+2]};
        color = sRGB_to_Rec2020 * color;
        color = mapper(color);
        color = OETF_sRGB(saturate(Rec2020_to_sRGB * color));
        rgba[4*i] = color.r; rgba[4*i+1] = color.g; rgba[4*i+2] = color.b;
    }
}
