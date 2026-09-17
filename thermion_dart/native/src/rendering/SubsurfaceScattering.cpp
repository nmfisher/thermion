#include "rendering/SubsurfaceScattering.hpp"
#include "c_api/TView.h"
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/RenderableManager.h>
#include <filament/Scene.h>
#include <utils/Entity.h>
#include <unordered_map>
#include <vector>

namespace thermion {
namespace {
struct Selection {
    utils::Entity entity;
    size_t primitive;
    filament::MaterialInstance const* original;
    filament::MaterialInstance* selected;
};
// Accessed only on the render thread. Clones retain the original material,
// vertex code, texture bindings, bone/morph state and primitive geometry.
std::unordered_map<filament::View*, std::vector<Selection>> selections;
std::unordered_map<filament::Engine*, filament::View*> activeViews;

void release(filament::Engine* engine, Selection const& s) {
    auto& rm = engine->getRenderableManager();
    auto i = rm.getInstance(s.entity);
    if (i && s.primitive < rm.getPrimitiveCount(i) &&
            rm.getMaterialInstanceAt(i, s.primitive) == s.selected) {
        rm.setMaterialInstanceAt(i, s.primitive, s.original);
    }
    engine->destroy(s.selected);
}
}

void releaseSubsurfaceSelections(filament::Engine* engine, filament::View* view) {
    if (auto a = activeViews.find(engine); a != activeViews.end() && a->second == view) activeViews.erase(a);
    auto it = selections.find(view);
    if (it == selections.end()) return;
    for (auto const& s : it->second) release(engine, s);
    selections.erase(it);
}

extern "C" {
EMSCRIPTEN_KEEPALIVE bool View_configureSss(TEngine* tEngine, TView* tView, bool enabled,
        float distanceR, float distanceG, float distanceB, float strength, int debugOutput) {
#if defined(FILAMENT_HAS_DIFFUSE_SSS) && FILAMENT_HAS_DIFFUSE_SSS >= 2
    auto* view = reinterpret_cast<filament::View*>(tView);
    auto* engine = reinterpret_cast<filament::Engine*>(tEngine);
    auto a = activeViews.find(engine);
    if (enabled && a != activeViews.end() && a->second != view) return false;
    if (enabled && (view->getMultiSampleAntiAliasingOptions().enabled ||
            view->getFogOptions().enabled || view->getScreenSpaceReflectionsOptions().enabled)) return false;
    // Reject unsupported existing scene composition before the render-thread
    // preconditions are reached. Later scene changes must honor the same contract.
    if (enabled && view->getScene()) {
        bool opaque = true;
        auto& rm = engine->getRenderableManager();
        view->getScene()->forEach([&](utils::Entity e) {
            auto i = rm.getInstance(e);
            if (!i) return;
            for (size_t p = 0; p < rm.getPrimitiveCount(i); ++p) {
                auto* material = rm.getMaterialInstanceAt(i, p)->getMaterial();
                auto blend = material->getBlendingMode();
                opaque &= (blend == filament::BlendingMode::OPAQUE ||
                        blend == filament::BlendingMode::MASKED) &&
                        material->getRefractionMode() == filament::RefractionMode::NONE;
            }
        });
        if (!opaque) return false;
    }
    filament::SubsurfaceScatteringOptions options;
    options.enabled = enabled;
    options.diffusionDistance = {distanceR, distanceG, distanceB};
    options.strength = strength;
    options.debugOutput = uint8_t(debugOutput);
    view->setSubsurfaceScatteringOptions(options);
    if (enabled) activeViews[engine] = view;
    else if (a != activeViews.end() && a->second == view) activeViews.erase(a);
    return true;
#else
    return !enabled;
#endif
}

EMSCRIPTEN_KEEPALIVE bool View_setSssPrimitive(TEngine* tEngine, TView* tView,
        EntityId entity, int primitive, bool enabled, int group) {
    auto* engine = reinterpret_cast<filament::Engine*>(tEngine);
    auto* view = reinterpret_cast<filament::View*>(tView);
    auto& entries = selections[view];
    auto e = utils::Entity::import(entity);
    for (auto it = entries.begin(); it != entries.end(); ++it) {
        if (it->entity == e && it->primitive == size_t(primitive)) {
            if (enabled) return true;
            release(engine, *it);
            entries.erase(it);
#if defined(FILAMENT_HAS_DIFFUSE_SSS) && FILAMENT_HAS_DIFFUSE_SSS >= 2
            view->setSubsurfaceScatteringOptions(view->getSubsurfaceScatteringOptions());
#endif
            return true;
        }
    }
    if (!enabled) return true;
#if defined(FILAMENT_HAS_DIFFUSE_SSS) && FILAMENT_HAS_DIFFUSE_SSS >= 2
    auto& rm = engine->getRenderableManager();
    auto instance = rm.getInstance(e);
    if (!instance || primitive < 0 || size_t(primitive) >= rm.getPrimitiveCount(instance)) return false;
    auto* original = rm.getMaterialInstanceAt(instance, size_t(primitive));
    auto* material = original->getMaterial();
    if (material->getShading() != filament::Shading::LIT ||
            material->getBlendingMode() != filament::BlendingMode::OPAQUE ||
            !material->supportsSubsurfaceScattering()) return false;
    // The initial API supports one view selecting a given primitive.
    for (auto const& pair : selections) {
        if (pair.first == view) continue;
        for (auto const& s : pair.second) if (s.entity == e && s.primitive == size_t(primitive)) return false;
    }
    auto* selected = filament::MaterialInstance::duplicate(original, "SSS selected material");
    selected->setParameter("_sssInfo", filament::math::float2{1.0f, float(group)});
    rm.setMaterialInstanceAt(instance, size_t(primitive), selected);
    entries.push_back({e, size_t(primitive), original, selected});
    view->setSubsurfaceScatteringOptions(view->getSubsurfaceScatteringOptions());
    return true;
#else
    return false;
#endif
}
}
}
