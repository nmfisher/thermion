#include "rendering/SilhouetteOverride.hpp"
#include "rendering/RenderManager.hpp"

#include <mutex>
#include <unordered_map>
#include <vector>

#include <filament/Engine.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/RenderableManager.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/View.h>
#include <utils/Entity.h>
#include <cstring>

namespace thermion {

namespace {

struct SilhouetteViewOverride {
    filament::Engine *engine = nullptr;
    filament::MaterialInstance *materialInstance = nullptr;
};

std::mutex sOverrideMutex;
std::unordered_map<const filament::View *, SilhouetteViewOverride> sOverrides;

void renderWithOverride(
    filament::Renderer *renderer,
    filament::View *view,
    bool standalone) {
    if (!renderer || !view) {
        return;
    }

    SilhouetteViewOverride entry;
    {
        std::lock_guard<std::mutex> lock(sOverrideMutex);
        auto it = sOverrides.find(view);
        if (it != sOverrides.end()) {
            entry = it->second;
        }
    }

    if (!entry.engine || !entry.materialInstance) {
        if (standalone) {
            renderer->renderStandaloneView(view);
        } else {
            renderer->render(view);
        }
        return;
    }

    filament::Scene *scene = view->getScene();
    if (!scene) {
        if (standalone) {
            renderer->renderStandaloneView(view);
        } else {
            renderer->render(view);
        }
        return;
    }

    struct SavedMaterial {
        filament::RenderableManager::Instance instance;
        size_t primitiveIndex;
        filament::MaterialInstance *original;
    };

    auto &rm = entry.engine->getRenderableManager();
    std::vector<SavedMaterial> saved;

    scene->forEach([&](utils::Entity entity) {
        if (!rm.hasComponent(entity)) {
            return;
        }
        auto ri = rm.getInstance(entity);
        if (!ri) {
            return;
        }
        const size_t primitiveCount = rm.getPrimitiveCount(ri);
        for (size_t p = 0; p < primitiveCount; ++p) {
            auto *original = rm.getMaterialInstanceAt(ri, p);
            if (original && std::strcmp(original->getMaterial()->getName(), "Skybox") == 0) {
                continue;
            }
            saved.push_back({ri, p, original});
            rm.setMaterialInstanceAt(ri, p, entry.materialInstance);
        }
    });

    if (standalone) {
        renderer->renderStandaloneView(view);
    } else {
        renderer->render(view);
    }

    // Restore original material instances immediately so subsequent views in
    // the same frame see each shared entity with its original material.
    for (const auto &s : saved) {
        if (s.original) {
            rm.setMaterialInstanceAt(s.instance, s.primitiveIndex, s.original);
        } else {
            rm.clearMaterialInstanceAt(s.instance, s.primitiveIndex);
        }
    }
}

} // namespace

void registerSilhouetteMaterialOverride(
    filament::View *view,
    filament::Engine *engine,
    filament::MaterialInstance *materialInstance) {
    if (!view) {
        return;
    }
    if (!engine || !materialInstance) {
        unregisterSilhouetteMaterialOverride(view);
        return;
    }
    RenderManager::setRenderViewHook(&renderViewWithSilhouetteOverride);
    std::lock_guard<std::mutex> lock(sOverrideMutex);
    sOverrides[view] = SilhouetteViewOverride{engine, materialInstance};
}

void unregisterSilhouetteMaterialOverride(const filament::View *view) {
    if (!view) {
        return;
    }
    std::lock_guard<std::mutex> lock(sOverrideMutex);
    sOverrides.erase(view);
}

void renderViewWithSilhouetteOverride(
    filament::Renderer *renderer,
    filament::View *view) {
    renderWithOverride(renderer, view, false);
}

void renderStandaloneViewWithSilhouetteOverride(
    filament::Renderer *renderer,
    filament::View *view) {
    renderWithOverride(renderer, view, true);
}

} // namespace thermion
