#ifndef UNLIT_MATERIAL_PROVIDER_HPP
#define UNLIT_MATERIAL_PROVIDER_HPP

#include <filament/gltfio/MaterialProvider.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <math/mat3.h>
#include <math/vec3.h>
#include <math/vec4.h>

namespace thermion {

class UnlitMaterialProvider : public filament::gltfio::MaterialProvider {
private:
    filament::Material* mUnlitMaterial;
    const filament::Material* mMaterials[1];
    filament::Engine* mEngine;

public:
    UnlitMaterialProvider(filament::Engine* engine, const void* const data, const size_t size) : mEngine(engine) {
        mUnlitMaterial = filament::Material::Builder()
            .package(data, size)
            .build(*engine);
        mMaterials[0] = mUnlitMaterial;
    }

    ~UnlitMaterialProvider() {
        mEngine->destroy(mUnlitMaterial);
    }

    filament::MaterialInstance* createMaterialInstance(filament::gltfio::MaterialKey* config, 
                                                       filament::gltfio::UvMap* uvmap,
                                                       const char* label = "unlit", 
                                                       const char* extras = nullptr) override {
        auto instance = mUnlitMaterial->createInstance();
        instance->setParameter("baseColorIndex", -1);
        return instance;
    }

    filament::Material* getMaterial(filament::gltfio::MaterialKey* config, 
                                    filament::gltfio::UvMap* uvmap, 
                                    const char* label = "unlit") override {
        return mUnlitMaterial;
    }

    const filament::Material* const* getMaterials() const noexcept override {
        return mMaterials;
    }

    size_t getMaterialsCount() const noexcept override {
        return 1;
    }

    void destroyMaterials() override {
        // Materials are destroyed in the destructor
    }

    bool needsDummyData(filament::VertexAttribute attrib) const noexcept override {
        // For unlit material, we don't need dummy data for any attribute
        return false;
    }
};

} // namespace thermion

#endif // UNLIT_MATERIAL_PROVIDER_HPP