#pragma once

#include <map>
#include <mutex>
#include <vector>

#include <math/mat4.h>

#include <filament/Engine.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/Renderer.h>
#include <filament/RenderTarget.h>
#include <filament/RenderableManager.h>
#include <filament/Scene.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <filament/TransformManager.h>
#include <filament/View.h>
#include <utils/SingleInstanceComponentManager.h>

#include "c_api/APIBoundaryTypes.h"
#include "material/linear_depth.h"

namespace thermion
{

    /// @brief
    class OverlayComponentManager : public utils::SingleInstanceComponentManager<filament::MaterialInstance *>
    {
    public:
        OverlayComponentManager(
            filament::Engine *engine,
            filament::View *view,
            filament::Scene *scene,
            filament::RenderTarget *renderTarget,
            filament::Renderer *renderer) : mEngine(engine), mView(view), mScene(scene), mRenderTarget(renderTarget), mRenderer(renderer)
        {
            mDepthMaterial = filament::Material::Builder()
                                 .package(LINEAR_DEPTH_LINEAR_DEPTH_DATA, LINEAR_DEPTH_LINEAR_DEPTH_SIZE)
                                 .build(*engine);
            mDepthMaterialInstance = mDepthMaterial->createInstance();
        }

        ~OverlayComponentManager() {
            mEngine->destroy(mDepthMaterialInstance);
            mEngine->destroy(mDepthMaterial);
        }

        void setRenderTarget(filament::RenderTarget *renderTarget) {
            std::lock_guard lock(mMutex);
            mRenderTarget = renderTarget;
            auto *color = mRenderTarget->getTexture(filament::RenderTarget::AttachmentPoint::COLOR);
            for (auto it = begin(); it < end(); it++)
            {
                const auto &entity = getEntity(it);
                auto componentInstance = getInstance(entity);
                auto &materialInstance = elementAt<0>(componentInstance);    
                materialInstance->setParameter("depth", color, mDepthSampler);
            }

        }

        void addOverlayComponent(utils::Entity target, filament::MaterialInstance *materialInstance)
        {
            std::lock_guard lock(mMutex);
            
            auto &rm = mEngine->getRenderableManager();
            auto ri = rm.getInstance(target);

            if(!ri.isValid()) {
                return;
            }

            auto bb = rm.getAxisAlignedBoundingBox(ri);

            auto *color = mRenderTarget->getTexture(filament::RenderTarget::AttachmentPoint::COLOR);
            materialInstance->setParameter("depth", color, mDepthSampler);
            materialInstance->setParameter("bbCenter", bb.center);
            if (!hasComponent(target))
            {
                utils::EntityInstanceBase::Type componentInstance = addComponent(target);
                this->elementAt<0>(componentInstance) = materialInstance;
            }
            mScene->addEntity(target);
        }

        void removeOverlayComponent(utils::Entity target)
        {
            std::lock_guard lock(mMutex);

            if (hasComponent(target))
            {
                removeComponent(target);
            }
            mScene->remove(target);
        }

        void update()
        {
            if (!mView || !mScene || !mRenderTarget || getComponentCount() == 0)
            {
                return;
            }

            std::lock_guard lock(mMutex);
            auto &rm = mEngine->getRenderableManager();
            std::map<utils::Entity, std::vector<filament::MaterialInstance *>> materials;
            auto *scene = mView->getScene();
            auto *renderTarget = mView->getRenderTarget();
            mView->setRenderTarget(mRenderTarget);
            mView->setScene(mScene);

            for (auto it = begin(); it < end(); it++)
            {
                const auto &entity = getEntity(it);

                auto ri = rm.getInstance(entity);
                if (ri.isValid())
                {

                    for (int i = 0; i < rm.getPrimitiveCount(ri); i++)
                    {
                        auto *existing = rm.getMaterialInstanceAt(ri, i);
                        materials[entity].push_back(existing);
                        rm.setMaterialInstanceAt(ri, i, mDepthMaterialInstance);
                    }
                }
                else
                {
                    Log("WARNING: INVALID RENDERABLE");
                }
            }

            mRenderer->render(mView);

            mView->setRenderTarget(renderTarget);

            for (auto it = begin(); it < end(); it++)
            {
                const auto &entity = getEntity(it);
                auto componentInstance = getInstance(entity);
                auto &materialInstance = elementAt<0>(componentInstance);

                auto ri = rm.getInstance(entity);
                if (ri.isValid())
                {
                    for (int i = 0; i < rm.getPrimitiveCount(ri); i++)
                    {
                        rm.setMaterialInstanceAt(ri, i, materialInstance);
                    }
                }
                else
                {
                    Log("WARNING: INVALID RENDERABLE");
                }
            }

            mRenderer->render(mView);

            for (auto it = begin(); it < end(); it++)
            {
                const auto &entity = getEntity(it);
                auto ri = rm.getInstance(entity);
                for (int i = 0; i < rm.getPrimitiveCount(ri); i++)
                {
                    rm.setMaterialInstanceAt(ri, i, materials[entity][i]);
                }
            }
            mView->setScene(scene);
        }

    private:
        std::mutex mMutex;
        filament::Engine *mEngine = std::nullptr_t();
        filament::View *mView = std::nullptr_t();
        filament::Scene *mScene = std::nullptr_t();
        filament::RenderTarget *mRenderTarget = std::nullptr_t();
        filament::Renderer *mRenderer = std::nullptr_t();
        filament::Material *mDepthMaterial = std::nullptr_t();
        filament::MaterialInstance *mDepthMaterialInstance = std::nullptr_t();
        filament::TextureSampler mDepthSampler;
    };
}
