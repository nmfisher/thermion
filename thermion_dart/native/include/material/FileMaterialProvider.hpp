#ifndef FILE_MATERIAL_PROVIDER
#define FILE_MATERIAL_PROVIDER

#include <filament/gltfio/MaterialProvider.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <math/mat4.h>
#include <math/vec3.h>
#include <math/vec4.h>
#include <math/mat3.h>
#include <math/norm.h>
#include "Log.hpp"

namespace thermion_flutter {


  class FileMaterialProvider : public filament::gltfio::MaterialProvider {

      filament::Material* _m;
      const filament::Material* _ms[1];
      filament::Texture* mDummyTexture = nullptr;

      public:
        FileMaterialProvider(filament::Engine* engine, const void* const  data, const size_t size) {
          _m = filament::Material::Builder()
            .package(data, size)
            .build(*engine);
          _ms[0] = _m;
          unsigned char texels[4] = {};
          mDummyTexture = filament::Texture::Builder()
            .width(1).height(1)
            .format(filament::Texture::InternalFormat::RGBA8)
            .build(*engine);
          filament::Texture::PixelBufferDescriptor pbd(texels, sizeof(texels), filament::Texture::Format::RGBA,
            filament::Texture::Type::UBYTE);
            mDummyTexture->setImage(*engine, 0, std::move(pbd));
        }

        filament::MaterialInstance* createMaterialInstance(filament::gltfio::MaterialKey* config, filament::gltfio::UvMap* uvmap,
                const char* label = "material", const char* extras = nullptr) {

            auto getUvIndex = [uvmap](uint8_t srcIndex, bool hasTexture) -> int {
              return hasTexture ? int(uvmap->at(srcIndex)) - 1 : -1;
            };

            auto instance = _m->createInstance();
            filament::math::mat3f identity;
            instance->setParameter("baseColorUvMatrix", identity);
            instance->setParameter("normalUvMatrix", identity);

            instance->setParameter("baseColorIndex", getUvIndex(config->baseColorUV, config->hasBaseColorTexture));
            instance->setParameter("normalIndex", getUvIndex(config->normalUV, config->hasNormalTexture));
            if(config->hasNormalTexture) {
              filament::TextureSampler sampler;
              instance->setParameter("normalMap", mDummyTexture, sampler);
              instance->setParameter("baseColorMap", mDummyTexture, sampler);
            } else {
              Log("No normal texture for specified material.");
            }
            
            return instance;
        }

        /**
        * Creates or fetches a compiled Filament material corresponding to the given config.
        */
        virtual filament::Material* getMaterial(filament::gltfio::MaterialKey* config, filament::gltfio::UvMap* uvmap, const char* label = "material") { 
          return _m;
        }

        /**
        * Gets a weak reference to the array of cached materials.
        */
        const filament::Material* const* getMaterials() const noexcept {
          return _ms;
        }

        /**
        * Gets the number of cached materials.
        */
        size_t getMaterialsCount() const noexcept {
          return (size_t)1;
        }

        void destroyMaterials() {

        }

        bool needsDummyData(filament::VertexAttribute attrib) const noexcept {
          return true;
        }
  };
}

#endif