#ifndef UNLIT_MATERIAL_PROVIDER
#define UNLIT_MATERIAL_PROVIDER
namespace polyvox {
  class UnlitMaterialProvider : public MaterialProvider {

      const Material* _m;
      const Material* _ms[1];

      public:
        UnlitMaterialProvider(Engine* engine) {
          _m = Material::Builder()
            .package(	UNLITOPAQUE_UNLIT_OPAQUE_DATA, UNLITOPAQUE_UNLIT_OPAQUE_SIZE)
            .build(*engine);
          _ms[0] = _m;
        }

        filament::MaterialInstance* createMaterialInstance(MaterialKey* config, UvMap* uvmap,
                const char* label = "material", const char* extras = nullptr) {
                  MaterialInstance* d = (MaterialInstance*)_m->getDefaultInstance();
          return d;
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