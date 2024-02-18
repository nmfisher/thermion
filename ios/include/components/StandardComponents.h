#ifndef _STANDARD_COMPONENTS_H
#define _STANDARD_COMPONENTS_H

#include "utils/Entity.h"
#include "utils/EntityInstance.h"
#include "utils/SingleInstanceComponentManager.h"
#include "filament/TransformManager.h"
#include "gltfio/FilamentAsset.h"
#include "gltfio/FilamentInstance.h"
#include "Log.hpp"

namespace polyvox
{

typedef void(*CollisionCallback)(int32_t entityId1, int32_t entityId2) ;
class CollisionComponentManager : public utils::SingleInstanceComponentManager<filament::Aabb, CollisionCallback, bool> {

    const filament::TransformManager& _transformManager;
    public:
        CollisionComponentManager(const filament::TransformManager& transformManager) : _transformManager(transformManager) {}
    
        std::vector<filament::math::float3> collides(EntityId transformingEntityId, filament::Aabb sourceBox) { 
            auto sourceCorners = sourceBox.getCorners();
            std::vector<filament::math::float3> collisionAxes;
            for(auto it = begin(); it < end(); it++) {
                auto entity = getEntity(it);
                auto targetXformInstance = _transformManager.getInstance(entity);
                auto targetXform = _transformManager.getWorldTransform(targetXformInstance);
                auto targetBox = elementAt<0>(it).transform(targetXform);
                auto targetCorners = targetBox.getCorners();

                // Log("Checking collision for entity %d with aabb extent %f %f %f against source entity %d with aabb extent %f %f %f", entity, targetBox.extent().x, targetBox.extent().y, targetBox.extent().z, transformingEntityId, sourceBox.extent().x, sourceBox.extent().y, sourceBox.extent().z);

                bool collided = false;

                // iterate over every vertex in the source/target AABB
                for(int i = 0; i < 8; i++) {
                    auto intersecting = sourceCorners.vertices[i];
                    auto min = targetBox.min;
                    auto max = targetBox.max;
                    
                    // if the vertex has insersected with the target/source AABB
                    if(targetBox.contains(sourceCorners.vertices[i]) < 0) {
                        collided = true;
                        // Log("targetBox %f %f %f contains source vertex %f %f %f", targetBox.extent().x, targetBox.extent().y, targetBox.extent().z, sourceCorners.vertices[i].x, sourceCorners.vertices[i].y, sourceCorners.vertices[i].z);
                    } else if(sourceBox.contains(targetCorners.vertices[i]) < 0) {
                        // Log("sourceBox %f %f %f contains target vertex %f %f %f", sourceBox.extent().x, sourceBox.extent().y, sourceBox.extent().z, targetCorners.vertices[i].x, targetCorners.vertices[i].y, targetCorners.vertices[i].z);
                        collided = true;
                        intersecting = targetCorners.vertices[i];
                        min = sourceBox.min;
                        max = sourceBox.max;
                    } else { 
                        continue;
                    }
                    auto affectsTransform = elementAt<2>(it);
                    if(affectsTransform) {
                        float xmin = min.x - intersecting.x;
                        float ymin = min.y - intersecting.y;
                        float zmin = min.z - intersecting.z;
                        float xmax = intersecting.x - max.x;
                        float ymax = intersecting.y - max.y;
                        float zmax = intersecting.z - max.z;

                        auto maxD = std::max(xmin,std::max(ymin,std::max(zmin,std::max(xmax,std::max(ymax,zmax)))));
                        filament::math::float3 axis;
                        if(maxD == xmin) {
                            axis = {-1.0f,0.0f, 0.0f};
                        } else if(maxD == ymin) {
                            axis = {0.0f,-1.0f, 0.0f};
                        } else if(maxD == zmin) {
                            axis = {0.0f,0.0f, -1.0f};
                        } else if(maxD == xmax) {
                            axis = {1.0f,0.0f, 0.0f};
                        } else if(maxD == ymax) {
                        axis = {0.0f,1.0f, 0.0f};  
                        } else { 
                        axis = { 0.0f, 0.0f, 1.0f};
                        }
                        collisionAxes.push_back(axis);                      
                    }
                    break;
                }
                if(collided) {
                    auto callback = elementAt<1>(it);
                    if(callback) {
                        callback(utils::Entity::smuggle(entity), transformingEntityId);
                    }
                }
            }
            
            return collisionAxes;
        }
};


}

#endif