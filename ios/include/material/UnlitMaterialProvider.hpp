#ifndef UNLIT_MATERIAL_PROVIDER
#define UNLIT_MATERIAL_PROVIDER
namespace polyvox {
  class UnlitMaterialProvider : public MaterialProvider {

      const Material* _m;
      const Material* _ms[1];

      public:
        UnlitMaterialProvider(Engine* engine) {
          _m = Material::Builder()
            .package(	UNLIT_OPAQUE_UNLIT_DATA, UNLIT_OPAQUE_UNLIT_SIZE)
            .build(*engine);
          if(_m) {
            Log("YES");
          } else {
            Log("NO!");
          }
          _ms[0] = _m;
        }

        filament::MaterialInstance* createMaterialInstance(MaterialKey* config, UvMap* uvmap,
                const char* label = "material", const char* extras = nullptr) {
          MaterialInstance* d = (MaterialInstance*)_m->getDefaultInstance();
          if(d) {
            Log("YES");
          } else {
            Log("NO INSTANCE!");
          }
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