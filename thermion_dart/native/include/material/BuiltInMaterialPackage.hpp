// Generated from materials/built_in_materials.json by make bindings.

#pragma once
#include "c_api/APIBoundaryTypes.h"
#include "c_api/TBuiltInMaterial.h"
#ifdef IMAGE_ENABLED
#include "material/image.h"
#endif
#ifdef GRID_ENABLED
#include "material/grid.h"
#endif
#ifdef GIZMO_ENABLED
#include "material/gizmo.h"
#endif
#ifdef TRANSLATION_AXIS_ENABLED
#include "material/translation_axis.h"
#endif
#ifdef BONE_OVERLAY_ENABLED
#include "material/bone_overlay.h"
#endif
#ifdef SILHOUETTE_ENABLED
#include "material/silhouette.h"
#endif
#ifdef EDGE_OUTLINE_ENABLED
#include "material/edge_outline.h"
#endif
#ifdef WIREFRAME_ENABLED
#include "material/wireframe.h"
#endif
#ifdef NORMAL_COLOR_ENABLED
#include "material/normal_color.h"
#endif
#ifdef SHARP_EDGE_ENABLED
#include "material/sharp_edge.h"
#endif
#ifdef CAPTURE_UV_ENABLED
#include "material/capture_uv.h"
#endif
#ifdef LINEAR_DEPTH_ENABLED
#include "material/linear_depth.h"
#endif
#ifdef UNLIT_FIXED_SIZE_ENABLED
#include "material/unlit_fixed_size.h"
#endif

namespace thermion {
struct BuiltInMaterialPackage {
    TBuiltInMaterial id;
    const uint8_t* data;
    size_t size;
};

inline BuiltInMaterialPackage builtInMaterialPackage(TBuiltInMaterial id) {
    switch (id) {
#ifdef IMAGE_ENABLED
        case BUILT_IN_IMAGE: return {id, IMAGE_IMAGE_DATA, IMAGE_IMAGE_SIZE};
#endif
#ifdef GRID_ENABLED
        case BUILT_IN_GRID: return {id, GRID_GRID_DATA, GRID_GRID_SIZE};
#endif
#ifdef GIZMO_ENABLED
        case BUILT_IN_GIZMO: return {id, GIZMO_GIZMO_DATA, GIZMO_GIZMO_SIZE};
#endif
#ifdef TRANSLATION_AXIS_ENABLED
        case BUILT_IN_TRANSLATION_AXIS: return {id, TRANSLATION_AXIS_TRANSLATION_AXIS_DATA, TRANSLATION_AXIS_TRANSLATION_AXIS_SIZE};
#endif
#ifdef BONE_OVERLAY_ENABLED
        case BUILT_IN_BONE_OVERLAY: return {id, BONE_OVERLAY_BONE_OVERLAY_DATA, BONE_OVERLAY_BONE_OVERLAY_SIZE};
#endif
#ifdef SILHOUETTE_ENABLED
        case BUILT_IN_SILHOUETTE: return {id, SILHOUETTE_SILHOUETTE_DATA, SILHOUETTE_SILHOUETTE_SIZE};
#endif
#ifdef EDGE_OUTLINE_ENABLED
        case BUILT_IN_EDGE_OUTLINE: return {id, EDGE_OUTLINE_EDGE_OUTLINE_DATA, EDGE_OUTLINE_EDGE_OUTLINE_SIZE};
#endif
#ifdef WIREFRAME_ENABLED
        case BUILT_IN_WIREFRAME: return {id, WIREFRAME_WIREFRAME_DATA, WIREFRAME_WIREFRAME_SIZE};
#endif
#ifdef NORMAL_COLOR_ENABLED
        case BUILT_IN_NORMAL_COLOR: return {id, NORMAL_COLOR_NORMAL_COLOR_DATA, NORMAL_COLOR_NORMAL_COLOR_SIZE};
#endif
#ifdef SHARP_EDGE_ENABLED
        case BUILT_IN_SHARP_EDGE: return {id, SHARP_EDGE_SHARP_EDGE_DATA, SHARP_EDGE_SHARP_EDGE_SIZE};
#endif
#ifdef CAPTURE_UV_ENABLED
        case BUILT_IN_CAPTURE_UV: return {id, CAPTURE_UV_CAPTURE_UV_DATA, CAPTURE_UV_CAPTURE_UV_SIZE};
#endif
#ifdef LINEAR_DEPTH_ENABLED
        case BUILT_IN_LINEAR_DEPTH: return {id, LINEAR_DEPTH_LINEAR_DEPTH_DATA, LINEAR_DEPTH_LINEAR_DEPTH_SIZE};
#endif
#ifdef UNLIT_FIXED_SIZE_ENABLED
        case BUILT_IN_UNLIT_FIXED_SIZE: return {id, UNLIT_FIXED_SIZE_UNLIT_FIXED_SIZE_DATA, UNLIT_FIXED_SIZE_UNLIT_FIXED_SIZE_SIZE};
#endif
        default: return {id, nullptr, 0};
    }
}

TMaterial* buildBuiltInMaterial(TEngine* engine, BuiltInMaterialPackage package);
} // namespace thermion
