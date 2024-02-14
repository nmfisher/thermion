#ifndef _STANDARD_COMPONENTS_H
#define _STANDARD_COMPONENTS_H

#include "utils/Entity.h"
#include "utils/EntityInstance.h"
#include "utils/SingleInstanceComponentManager.h"
#include "filament/TransformManager.h"
#include "gltfio/FilamentAsset.h"
#include "gltfio/FilamentInstance.h"

namespace polyvox
{

class FloatComponentManager : public utils::SingleInstanceComponentManager<float, float, float, float> {

    static constexpr size_t DIRECTION = 0;
    static constexpr size_t POSITION = 1;
    static constexpr size_t MAX = 2;
    static constexpr size_t SPEED = 2;
    
    // void update() { 
    //     const auto* entities = getEntities();
    //     for(int i = 0; i < getComponentCount(); i++) {
    //         // const auto instance = getInstance();
    //         // elementAt<POSITION> 
    //         // const auto component = get
    //         // const auto entity = entities[i];
            
    //     }
    // }
};

class CollisionComponentManager : public utils::SingleInstanceComponentManager<filament::gltfio::FilamentInstance*> {

    static constexpr size_t INSTANCE = 0;

    const filament::TransformManager& _transformManager;
    public:
        CollisionComponentManager(const filament::TransformManager& transformManager) : _transformManager(transformManager) {}
    
        bool collides(filament::Aabb sourceBox) { 
            auto sourceCorners = sourceBox.getCorners();
            const auto& entities = getEntities();
            for(auto it = begin(); it < end(); it++) {
                auto entity = entities[it];
                
                auto targetInstance = elementAt<INSTANCE>(it);    
                auto targetXformInstance = _transformManager.getInstance(entity);
                auto targetXform = _transformManager.getWorldTransform(targetXformInstance);
                auto targetBox = targetInstance->getBoundingBox().transform(targetXform);
                for(int i = 0; i < 8; i++) {
                    if(targetBox.contains(sourceCorners.vertices[i]) < 0) {
                        return true;
                    }
                }
            }
            return false;
        }
};


}

#endif