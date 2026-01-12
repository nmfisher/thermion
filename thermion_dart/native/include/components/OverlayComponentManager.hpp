#pragma once

#include <mutex>
#include <unordered_set>

#include <filament/Camera.h>
#include <filament/Engine.h>
#include <filament/IndexBuffer.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/RenderableManager.h>
#include <filament/RenderTarget.h>
#include <filament/Scene.h>
#include <filament/Skybox.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <filament/TransformManager.h>
#include <filament/VertexBuffer.h>
#include <filament/View.h>
#include <filament/Viewport.h>
#include <utils/EntityManager.h>

#include "material/silhouette.h"
#include "material/edge_outline.h"
#include "Log.hpp"

namespace thermion
{

    /// Component data for highlighted entities
    struct SilhouetteComponent {
        filament::MaterialInstance *silhouetteMaterialInstance;
        utils::Entity silhouetteEntity;  // Clone entity for silhouette scene
    };

    ///
    /// Screen-space post-process outline manager using two-pass rendering.
    ///
    /// Pass 1 (Silhouette): Renders highlighted entities to a texture as white silhouettes
    /// Pass 2 (Edge Detection): Fullscreen quad samples silhouette texture, detects edges
    ///
    /// This creates clean outlines without corner gaps, similar to Blender's approach.
    ///
    class OverlayComponentManager
    {
    public:
        OverlayComponentManager(filament::Engine *engine) : mEngine(engine)
        {
            // Create silhouette material
            mSilhouetteMaterial = filament::Material::Builder()
                                    .package(SILHOUETTE_SILHOUETTE_DATA, SILHOUETTE_SILHOUETTE_SIZE)
                                    .build(*engine);

            // Create edge detection material
            mEdgeMaterial = filament::Material::Builder()
                              .package(EDGE_OUTLINE_EDGE_OUTLINE_DATA, EDGE_OUTLINE_EDGE_OUTLINE_SIZE)
                              .build(*engine);
        }

        ~OverlayComponentManager() {
            cleanup();
            mEngine->destroy(mSilhouetteMaterial);
            mEngine->destroy(mEdgeMaterial);
        }

        /// Initialize the overlay system with the given viewport size.
        /// Must be called before adding highlights.
        /// @param hardwareTextureId Optional platform-specific texture handle for the overlay color texture.
        ///        If 0, creates a new texture. If non-zero, imports the existing hardware texture.
        void initialize(uint32_t width, uint32_t height, intptr_t hardwareTextureId = 0) {
            std::lock_guard lock(mMutex);

            if (mInitialized) {
                return;
            }

            mViewportWidth = width;
            mViewportHeight = height;
            mExternalOverlayTextureId = hardwareTextureId;

            createRenderTargets(width, height);
            createOverlayRenderTargets(width, height, hardwareTextureId);
            createSilhouetteView();
            createOverlayView();
            createFullscreenQuad();

            mInitialized = true;
            TRACE("OverlayComponentManager initialized %dx%d (external texture: %s)",
                  width, height, hardwareTextureId != 0 ? "yes" : "no");
        }

        void setViewport(uint32_t width, uint32_t height) {
            std::lock_guard lock(mMutex);

            if (width == mViewportWidth && height == mViewportHeight) {
                return;
            }

            mViewportWidth = width;
            mViewportHeight = height;

            if (!mInitialized) {
                return;
            }

            // Recreate silhouette render targets at new size
            destroyRenderTargets();
            createRenderTargets(width, height);

            // Only recreate overlay targets if we own them (not external texture)
            if (mExternalOverlayTextureId == 0) {
                destroyOverlayRenderTargets();
                createOverlayRenderTargets(width, height, 0);
                mOverlayView->setRenderTarget(mOverlayTarget);
            }
            // If external texture, Flutter is responsible for recreating it at new size

            // Update views
            mSilhouetteView->setViewport({0, 0, width, height});
            mSilhouetteView->setRenderTarget(mSilhouetteTarget);

            mOverlayView->setViewport({0, 0, width, height});

            // Update edge material texel size
            updateEdgeMaterialParams();

            TRACE("OverlayComponentManager viewport updated to %dx%d", width, height);
        }

        /// Set the main camera for the silhouette view.
        /// The silhouette view will share this camera directly.
        void setCamera(filament::Camera *mainCamera) {
            std::lock_guard lock(mMutex);

            if (!mInitialized || !mainCamera) {
                return;
            }

            mSilhouetteView->setCamera(mainCamera);
            TRACE("OverlayComponentManager camera set");
        }

        /// Add a highlight for the given entity.
        /// Creates a silhouette clone in the silhouette scene.
        void addHighlight(
            utils::Entity target,
            filament::VertexBuffer *vertexBuffer,
            filament::IndexBuffer *indexBuffer,
            uint32_t indexCount,
            float outlineWidth,
            float r, float g, float b)
        {
            std::lock_guard lock(mMutex);

            if (!mInitialized) {
                Log("WARNING: OverlayComponentManager not initialized");
                return;
            }

            // Check if already highlighted
            if (mHighlightedEntities.find(target.getId()) != mHighlightedEntities.end()) {
                return;
            }

            auto &rm = mEngine->getRenderableManager();
            auto ri = rm.getInstance(target);

            if (!ri.isValid()) {
                Log("WARNING: Entity %d is not renderable", target.getId());
                return;
            }

            // Update outline settings (global)
            mOutlineWidth = outlineWidth;
            mOutlineColor[0] = r;
            mOutlineColor[1] = g;
            mOutlineColor[2] = b;
            updateEdgeMaterialParams();

            // Create silhouette material instance
            auto *silhouetteMi = mSilhouetteMaterial->createInstance();

            // Create silhouette entity (clone for silhouette scene)
            auto &em = utils::EntityManager::get();
            utils::Entity silhouetteEntity = em.create();

            // Get original bounding box
            auto boundingBox = rm.getAxisAlignedBoundingBox(ri);

            // Build silhouette renderable
            filament::RenderableManager::Builder(1)
                .boundingBox(boundingBox)
                .geometry(0, filament::RenderableManager::PrimitiveType::TRIANGLES,
                         vertexBuffer, indexBuffer, 0, indexCount)
                .material(0, silhouetteMi)
                .culling(true)
                .receiveShadows(false)
                .castShadows(false)
                .build(*mEngine, silhouetteEntity);

            // Parent silhouette entity to target so it follows transforms
            auto &tm = mEngine->getTransformManager();
            auto targetTransform = tm.getInstance(target);
            if (targetTransform.isValid()) {
                tm.create(silhouetteEntity, targetTransform);
            }

            // Add to silhouette scene
            mSilhouetteScene->addEntity(silhouetteEntity);

            // Store component
            SilhouetteComponent component;
            component.silhouetteMaterialInstance = silhouetteMi;
            component.silhouetteEntity = silhouetteEntity;
            mComponents[target.getId()] = component;
            mHighlightedEntities.insert(target.getId());

            TRACE("Added highlight for entity %d", target.getId());
        }

        void removeHighlight(utils::Entity target)
        {
            std::lock_guard lock(mMutex);

            auto it = mComponents.find(target.getId());
            if (it == mComponents.end()) {
                return;
            }

            auto &component = it->second;

            // Remove from silhouette scene
            mSilhouetteScene->remove(component.silhouetteEntity);

            // Destroy silhouette renderable
            auto &rm = mEngine->getRenderableManager();
            rm.destroy(component.silhouetteEntity);

            // Destroy transform
            auto &tm = mEngine->getTransformManager();
            tm.destroy(component.silhouetteEntity);

            // Destroy entity
            auto &em = utils::EntityManager::get();
            em.destroy(component.silhouetteEntity);

            // Destroy material instance
            mEngine->destroy(component.silhouetteMaterialInstance);

            // Remove from tracking
            mComponents.erase(it);
            mHighlightedEntities.erase(target.getId());

            TRACE("Removed highlight for entity %d", target.getId());
        }

        /// Get the silhouette view (renders highlighted entities to texture).
        /// Add this view to the render list BEFORE the main view.
        filament::View* getSilhouetteView() {
            return mSilhouetteView;
        }

        /// Get the overlay view (renders edge detection fullscreen quad).
        /// Add this view to the render list AFTER the main view.
        filament::View* getOverlayView() {
            return mOverlayView;
        }

        /// Get the overlay texture for compositing in Flutter.
        /// Returns the RGBA texture containing the rendered edge outlines.
        filament::Texture* getOverlayTexture() {
            return mOverlayTexture;
        }

        /// Check if there are any highlighted entities.
        bool hasHighlights() const {
            return !mHighlightedEntities.empty();
        }

        /// Check if initialized
        bool isInitialized() const {
            return mInitialized;
        }

    private:
        void createRenderTargets(uint32_t width, uint32_t height) {
            // Create silhouette color texture (R8 - single channel)
            mSilhouetteTexture = filament::Texture::Builder()
                .width(width)
                .height(height)
                .levels(1)
                .sampler(filament::Texture::Sampler::SAMPLER_2D)
                .format(filament::Texture::InternalFormat::R8)
                .usage(filament::Texture::Usage::COLOR_ATTACHMENT |
                       filament::Texture::Usage::SAMPLEABLE)
                .build(*mEngine);

            // Create silhouette depth texture
            mSilhouetteDepth = filament::Texture::Builder()
                .width(width)
                .height(height)
                .levels(1)
                .sampler(filament::Texture::Sampler::SAMPLER_2D)
                .format(filament::Texture::InternalFormat::DEPTH32F)
                .usage(filament::Texture::Usage::DEPTH_ATTACHMENT)
                .build(*mEngine);

            // Create render target
            mSilhouetteTarget = filament::RenderTarget::Builder()
                .texture(filament::RenderTarget::AttachmentPoint::COLOR, mSilhouetteTexture)
                .texture(filament::RenderTarget::AttachmentPoint::DEPTH, mSilhouetteDepth)
                .build(*mEngine);
        }

        void destroyRenderTargets() {
            if (mSilhouetteTarget) {
                mEngine->destroy(mSilhouetteTarget);
                mSilhouetteTarget = nullptr;
            }
            if (mSilhouetteTexture) {
                mEngine->destroy(mSilhouetteTexture);
                mSilhouetteTexture = nullptr;
            }
            if (mSilhouetteDepth) {
                mEngine->destroy(mSilhouetteDepth);
                mSilhouetteDepth = nullptr;
            }
        }

        void createOverlayRenderTargets(uint32_t width, uint32_t height, intptr_t hardwareTextureId = 0) {
            if (hardwareTextureId != 0) {
                // Import external hardware texture
                mOverlayTexture = filament::Texture::Builder()
                    .width(width)
                    .height(height)
                    .levels(1)
                    .sampler(filament::Texture::Sampler::SAMPLER_2D)
                    .format(filament::Texture::InternalFormat::RGBA8)
                    .usage(filament::Texture::Usage::COLOR_ATTACHMENT |
                           filament::Texture::Usage::SAMPLEABLE)
                    .import(hardwareTextureId)
                    .build(*mEngine);
                mOwnsOverlayTexture = false;
                TRACE("Imported external overlay texture with ID %ld", (long)hardwareTextureId);
            } else {
                // Create new overlay color texture (RGBA8 for color + alpha)
                mOverlayTexture = filament::Texture::Builder()
                    .width(width)
                    .height(height)
                    .levels(1)
                    .sampler(filament::Texture::Sampler::SAMPLER_2D)
                    .format(filament::Texture::InternalFormat::RGBA8)
                    .usage(filament::Texture::Usage::COLOR_ATTACHMENT |
                           filament::Texture::Usage::SAMPLEABLE)
                    .build(*mEngine);
                mOwnsOverlayTexture = true;
            }

            // Create overlay depth texture (always owned)
            mOverlayDepth = filament::Texture::Builder()
                .width(width)
                .height(height)
                .levels(1)
                .sampler(filament::Texture::Sampler::SAMPLER_2D)
                .format(filament::Texture::InternalFormat::DEPTH32F)
                .usage(filament::Texture::Usage::DEPTH_ATTACHMENT)
                .build(*mEngine);

            // Create render target
            mOverlayTarget = filament::RenderTarget::Builder()
                .texture(filament::RenderTarget::AttachmentPoint::COLOR, mOverlayTexture)
                .texture(filament::RenderTarget::AttachmentPoint::DEPTH, mOverlayDepth)
                .build(*mEngine);
        }

        void destroyOverlayRenderTargets() {
            if (mOverlayTarget) {
                mEngine->destroy(mOverlayTarget);
                mOverlayTarget = nullptr;
            }
            if (mOverlayTexture && mOwnsOverlayTexture) {
                mEngine->destroy(mOverlayTexture);
            }
            mOverlayTexture = nullptr;
            if (mOverlayDepth) {
                mEngine->destroy(mOverlayDepth);
                mOverlayDepth = nullptr;
            }
        }

        void createSilhouetteView() {
            // Create silhouette scene
            mSilhouetteScene = mEngine->createScene();

            // Create black skybox to clear render target
            // (Renderer::ClearOptions only work on SwapChain, not custom render targets)
            mSilhouetteSkybox = filament::Skybox::Builder()
                .color({0.0f, 0.0f, 0.0f, 1.0f})
                .build(*mEngine);
            mSilhouetteScene->setSkybox(mSilhouetteSkybox);

            // Create view (camera will be set later via setCamera())
            mSilhouetteView = mEngine->createView();
            mSilhouetteView->setScene(mSilhouetteScene);
            mSilhouetteView->setViewport({0, 0, mViewportWidth, mViewportHeight});
            mSilhouetteView->setRenderTarget(mSilhouetteTarget);
            mSilhouetteView->setPostProcessingEnabled(false);
            mSilhouetteView->setShadowingEnabled(false);
        }

        void createOverlayView() {
            // Create overlay scene
            mOverlayScene = mEngine->createScene();

            // Create transparent skybox to clear overlay render target
            // Without this, the overlay texture retains stale/undefined values
            mOverlaySkybox = filament::Skybox::Builder()
                .color({0.0f, 0.0f, 0.0f, 0.0f})  // fully transparent
                .build(*mEngine);
            mOverlayScene->setSkybox(mOverlaySkybox);

            // Create camera entity for overlay (ortho projection)
            auto &em = utils::EntityManager::get();
            mOverlayCameraEntity = em.create();

            // Create transform for camera
            auto &tm = mEngine->getTransformManager();
            tm.create(mOverlayCameraEntity);

            // Create camera
            mOverlayCamera = mEngine->createCamera(mOverlayCameraEntity);
            // Set orthographic projection for fullscreen quad
            mOverlayCamera->setProjection(
                filament::Camera::Projection::ORTHO,
                -1.0, 1.0,  // left, right
                -1.0, 1.0,  // bottom, top
                0.0, 1.0    // near, far
            );

            // Create view
            mOverlayView = mEngine->createView();
            mOverlayView->setScene(mOverlayScene);
            mOverlayView->setCamera(mOverlayCamera);
            mOverlayView->setViewport({0, 0, mViewportWidth, mViewportHeight});
            mOverlayView->setRenderTarget(mOverlayTarget);
            mOverlayView->setPostProcessingEnabled(false);
            mOverlayView->setShadowingEnabled(false);
            mOverlayView->setFrustumCullingEnabled(false);  // Fullscreen quad shouldn't be culled

            // No longer need blend mode - rendering to own texture
        }

        void createFullscreenQuad() {
            // Create fullscreen triangle (more efficient than quad)
            // Covers [-1,1] x [-1,1] using a single oversized triangle
            // z=0.5 to place in middle of ortho frustum (near=0, far=1)
            static const float positions[] = {
                -1.0f, -1.0f, 0.5f,
                 3.0f, -1.0f, 0.5f,
                -1.0f,  3.0f, 0.5f
            };

            mQuadVB = filament::VertexBuffer::Builder()
                .vertexCount(3)
                .bufferCount(1)
                .attribute(filament::VertexAttribute::POSITION, 0,
                          filament::VertexBuffer::AttributeType::FLOAT3, 0, 12)
                .build(*mEngine);

            mQuadVB->setBufferAt(*mEngine, 0,
                filament::VertexBuffer::BufferDescriptor(positions, sizeof(positions)));

            static const uint16_t indices[] = {0, 1, 2};

            mQuadIB = filament::IndexBuffer::Builder()
                .indexCount(3)
                .bufferType(filament::IndexBuffer::IndexType::USHORT)
                .build(*mEngine);

            mQuadIB->setBuffer(*mEngine,
                filament::IndexBuffer::BufferDescriptor(indices, sizeof(indices)));

            // Create edge material instance
            mEdgeMaterialInstance = mEdgeMaterial->createInstance();
            updateEdgeMaterialParams();

            // Create fullscreen quad entity
            auto &em = utils::EntityManager::get();
            mFullscreenQuadEntity = em.create();

            filament::RenderableManager::Builder(1)
                .boundingBox({{-2, -2, 0}, {4, 4, 1}})  // Large box to ensure no culling
                .geometry(0, filament::RenderableManager::PrimitiveType::TRIANGLES,
                         mQuadVB, mQuadIB, 0, 3)
                .material(0, mEdgeMaterialInstance)
                .culling(false)
                .receiveShadows(false)
                .castShadows(false)
                .build(*mEngine, mFullscreenQuadEntity);

            // Add to overlay scene
            mOverlayScene->addEntity(mFullscreenQuadEntity);
        }

        void updateEdgeMaterialParams() {
            if (!mEdgeMaterialInstance || !mSilhouetteTexture) {
                return;
            }

            // Set silhouette texture
            filament::TextureSampler sampler(
                filament::TextureSampler::MinFilter::NEAREST,
                filament::TextureSampler::MagFilter::NEAREST,
                filament::TextureSampler::WrapMode::CLAMP_TO_EDGE
            );
            mEdgeMaterialInstance->setParameter("silhouette", mSilhouetteTexture, sampler);

            // Set texel size (1/width, 1/height)
            mEdgeMaterialInstance->setParameter("texelSize",
                filament::math::float2{
                    1.0f / static_cast<float>(mViewportWidth),
                    1.0f / static_cast<float>(mViewportHeight)
                });

            // Set outline color and width
            mEdgeMaterialInstance->setParameter("outlineColor",
                filament::math::float3{mOutlineColor[0], mOutlineColor[1], mOutlineColor[2]});
            mEdgeMaterialInstance->setParameter("outlineWidth", mOutlineWidth);
        }

        void cleanup() {
            std::lock_guard lock(mMutex);

            // Destroy all silhouette components
            for (auto &pair : mComponents) {
                auto &component = pair.second;
                mSilhouetteScene->remove(component.silhouetteEntity);
                mEngine->getRenderableManager().destroy(component.silhouetteEntity);
                mEngine->getTransformManager().destroy(component.silhouetteEntity);
                utils::EntityManager::get().destroy(component.silhouetteEntity);
                mEngine->destroy(component.silhouetteMaterialInstance);
            }
            mComponents.clear();
            mHighlightedEntities.clear();

            // Destroy fullscreen quad
            if (mFullscreenQuadEntity.getId() != 0) {
                mOverlayScene->remove(mFullscreenQuadEntity);
                mEngine->getRenderableManager().destroy(mFullscreenQuadEntity);
                utils::EntityManager::get().destroy(mFullscreenQuadEntity);
            }

            if (mEdgeMaterialInstance) {
                mEngine->destroy(mEdgeMaterialInstance);
                mEdgeMaterialInstance = nullptr;
            }

            if (mQuadVB) {
                mEngine->destroy(mQuadVB);
                mQuadVB = nullptr;
            }

            if (mQuadIB) {
                mEngine->destroy(mQuadIB);
                mQuadIB = nullptr;
            }

            // Destroy overlay view/scene/camera
            if (mOverlayView) {
                mEngine->destroy(mOverlayView);
                mOverlayView = nullptr;
            }

            if (mOverlaySkybox) {
                mEngine->destroy(mOverlaySkybox);
                mOverlaySkybox = nullptr;
            }

            if (mOverlayScene) {
                mEngine->destroy(mOverlayScene);
                mOverlayScene = nullptr;
            }

            if (mOverlayCamera) {
                mEngine->destroyCameraComponent(mOverlayCameraEntity);
                mOverlayCamera = nullptr;
            }

            if (mOverlayCameraEntity.getId() != 0) {
                mEngine->getTransformManager().destroy(mOverlayCameraEntity);
                utils::EntityManager::get().destroy(mOverlayCameraEntity);
            }

            // Destroy silhouette view/scene/skybox (camera is shared, not owned)
            if (mSilhouetteView) {
                mEngine->destroy(mSilhouetteView);
                mSilhouetteView = nullptr;
            }

            if (mSilhouetteSkybox) {
                mEngine->destroy(mSilhouetteSkybox);
                mSilhouetteSkybox = nullptr;
            }

            if (mSilhouetteScene) {
                mEngine->destroy(mSilhouetteScene);
                mSilhouetteScene = nullptr;
            }

            // Destroy render targets
            destroyRenderTargets();
            destroyOverlayRenderTargets();

            mInitialized = false;
        }

    private:
        std::mutex mMutex;
        filament::Engine *mEngine = nullptr;
        bool mInitialized = false;

        // Viewport
        uint32_t mViewportWidth = 1920;
        uint32_t mViewportHeight = 1080;

        // Outline settings (global)
        float mOutlineWidth = 2.0f;
        float mOutlineColor[3] = {1.0f, 0.5f, 0.0f};

        // Materials
        filament::Material *mSilhouetteMaterial = nullptr;
        filament::Material *mEdgeMaterial = nullptr;

        // Silhouette pass resources (camera is shared via setCamera(), not owned)
        filament::Scene *mSilhouetteScene = nullptr;
        filament::View *mSilhouetteView = nullptr;
        filament::RenderTarget *mSilhouetteTarget = nullptr;
        filament::Texture *mSilhouetteTexture = nullptr;
        filament::Texture *mSilhouetteDepth = nullptr;
        filament::Skybox *mSilhouetteSkybox = nullptr;

        // Overlay (edge detection) pass resources
        filament::Scene *mOverlayScene = nullptr;
        filament::View *mOverlayView = nullptr;
        filament::Skybox *mOverlaySkybox = nullptr;
        filament::Camera *mOverlayCamera = nullptr;
        utils::Entity mOverlayCameraEntity;
        filament::MaterialInstance *mEdgeMaterialInstance = nullptr;
        filament::VertexBuffer *mQuadVB = nullptr;
        filament::IndexBuffer *mQuadIB = nullptr;
        utils::Entity mFullscreenQuadEntity;
        filament::RenderTarget *mOverlayTarget = nullptr;
        filament::Texture *mOverlayTexture = nullptr;
        filament::Texture *mOverlayDepth = nullptr;
        bool mOwnsOverlayTexture = true;
        intptr_t mExternalOverlayTextureId = 0;

        // Highlighted entities tracking
        std::unordered_map<uint32_t, SilhouetteComponent> mComponents;
        std::unordered_set<uint32_t> mHighlightedEntities;
    };
}
