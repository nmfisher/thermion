/*
 * Copyright (C) 2019 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */



#include "FilamentViewer.hpp"
#include <filament/Camera.h>
#include <filament/ColorGrading.h>
#include <filament/Engine.h>
#include <filament/IndexBuffer.h>
#include <filament/RenderableManager.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/Skybox.h>
#include <filament/TransformManager.h>
#include <filament/VertexBuffer.h>
#include <filament/View.h>

#include <filament/IndirectLight.h>
#include <filament/LightManager.h>

#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>

#include <camutils/Manipulator.h>

#include <utils/NameComponentManager.h>

#include <math/vec3.h>
#include <math/vec4.h>
#include <math/mat3.h>
#include <math/norm.h>

#include <image/KtxUtility.h>

using namespace filament;
using namespace filament::math;
using namespace gltfio;
using namespace utils;

namespace filament {
    class IndirectLight;
    class LightManager;
}

namespace mimetic {
    
const double kNearPlane = 0.05;   // 5 cm
const double kFarPlane = 1000.0;  // 1 km
const float kScaleMultiplier = 100.0f;
const float kAperture = 16.0f;
const float kShutterSpeed = 1.0f / 125.0f;
const float kSensitivity = 100.0f;

MaterialProvider* createGPUShaderLoader(Engine* engine);

FilamentViewer::FilamentViewer(
        void* layer, 
        LoadResource loadResource, 
        FreeResource freeResource) : _layer(layer), 
                                                      _loadResource(loadResource),
                                                      _freeResource(freeResource) {
    _engine = Engine::create(Engine::Backend::OPENGL);

    _renderer = _engine->createRenderer();
    _scene = _engine->createScene();
    Entity camera = EntityManager::get().create();
    _mainCamera = _engine->createCamera(camera);
    _view = _engine->createView();
    _view->setScene(_scene);
    _view->setCamera(_mainCamera);

    _cameraFocalLength = 28.0f;
    _mainCamera->setExposure(kAperture, kShutterSpeed, kSensitivity);

    _swapChain = _engine->createSwapChain(_layer);

//    _materialProvider = createGPUShaderLoader(_engine);
    _materialProvider = createUbershaderLoader(_engine);
    EntityManager& em = EntityManager::get();
    _ncm = new NameComponentManager(em);
    _assetLoader = AssetLoader::create({_engine, _materialProvider, _ncm, &em});
    _resourceLoader = new ResourceLoader(
            {.engine = _engine, .normalizeSkinningWeights = true, .recomputeBoundingBoxes = false});
        
    _manipulator =
            Manipulator<float>::Builder().orbitHomePosition(0.0f, 0.0f, 0.0f).targetPosition(0.0f, 0.0f, 0).build(Mode::ORBIT);
            //Manipulator<float>::Builder().orbitHomePosition(0.0f, 0.0f, 0.0f).targetPosition(0.0f, 0.0f, 0).build(Mode::ORBIT);
    _asset = nullptr;
}

FilamentViewer::~FilamentViewer() {

}

void FilamentViewer::loadResources() {
    const char* const* const resourceUris = _asset->getResourceUris();
    const size_t resourceUriCount = _asset->getResourceUriCount();
    for (size_t i = 0; i < resourceUriCount; i++) {
        const char* const uri = resourceUris[i];
        ResourceBuffer buf = _loadResource(uri);
        ResourceLoader::BufferDescriptor b(
                buf.data, buf.size, (ResourceLoader::BufferDescriptor::Callback)&_freeResource, nullptr);
        _resourceLoader->addResourceData(uri, std::move(b));
    }

    _resourceLoader->loadResources(_asset);
    const Entity* entities = _asset->getEntities();
    RenderableManager& rm = _engine->getRenderableManager();
    for(int i =0; i< _asset->getEntityCount(); i++) {
        Entity e = entities[i];
        auto inst = rm.getInstance(e);
        rm.setCulling(inst, false);
    }

    _animator = _asset->getAnimator();
    _asset->releaseSourceData();

    _scene->addEntities(_asset->getEntities(), _asset->getEntityCount());    
};

void FilamentViewer::loadGltf(const char* const uri) {
    _resourceLoader->asyncCancelLoad();
    _resourceLoader->evictResourceData();
    if(_asset) {
        _assetLoader->destroyAsset(_asset);
    }

    ResourceBuffer rbuf = _loadResource(uri);
    
    // Parse the glTF file and create Filament entities.
    _asset = _assetLoader->createAssetFromJson((uint8_t*)rbuf.data, rbuf.size);
    
    if (!_asset) {
        std::cerr << "Unable to parse asset" << std::endl;
        exit(1);
    }

    loadResources();
}

    
void FilamentViewer::loadSkybox(const char* const skyboxPath, const char* const iblPath) {
    ResourceBuffer skyboxBuffer = _loadResource(skyboxPath);
    
    image::KtxBundle* skyboxBundle =
            new image::KtxBundle(static_cast<const uint8_t*>(skyboxBuffer.data),
                    static_cast<uint32_t>(skyboxBuffer.size));
    _skyboxTexture = image::ktx::createTexture(_engine, skyboxBundle, false);
    _skybox = filament::Skybox::Builder().environment(_skyboxTexture).build(*_engine);
    _scene->setSkybox(_skybox);

    // Load IBL.
    ResourceBuffer iblBuffer = _loadResource(iblPath);

    image::KtxBundle* iblBundle = new image::KtxBundle(
            static_cast<const uint8_t*>(iblBuffer.data), static_cast<uint32_t>(iblBuffer.size));
    math::float3 harmonics[9];
    iblBundle->getSphericalHarmonics(harmonics);
    _iblTexture = image::ktx::createTexture(_engine, iblBundle, false);
    _indirectLight = IndirectLight::Builder()
                             .reflections(_iblTexture)
                             .irradiance(3, harmonics)
                             .intensity(30000.0f)
                             .build(*_engine);
    _scene->setIndirectLight(_indirectLight);

    // Always add a direct light source since it is required for shadowing.
    _sun = EntityManager::get().create();
    LightManager::Builder(LightManager::Type::DIRECTIONAL)
            .color(Color::cct(6500.0f))
            .intensity(100000.0f)
            .direction(math::float3(0.0f, -1.0f, 0.0f))
            .castShadows(true)
            .build(*_engine, _sun);
    _scene->addEntity(_sun);
}

void FilamentViewer::cleanup() {
    _resourceLoader->asyncCancelLoad();
    _assetLoader->destroyAsset(_asset);
    _materialProvider->destroyMaterials();
    AssetLoader::destroy(&_assetLoader);
};


}
