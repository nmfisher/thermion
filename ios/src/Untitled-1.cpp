// we know there's been a collision, but we want to adjust the direction vector to continue movement in the non-colliding direction
                        
                        // first, we need to find the AABB plane that we have collided with 

                        auto vertices = targetBox.getCorners().vertices;

                        // each entry here is a plane from the target bounding box
                        // (we drop the fourth vertex because it's mathematically not necessary to define the plane) 
                        std::vector<std::vector<filament::math::float3>> planes = {
                            {
                                vertices[0],vertices[2],vertices[4] // bottom
                            },
                            {
                                vertices[1],vertices[3],vertices[5] // top
                            },
                            {
                                vertices[0],vertices[1],vertices[4] // back
                            },
                            {
                                vertices[0],vertices[1],vertices[2] // left
                            },
                            {
                                vertices[4],vertices[5],vertices[6] // right
                            },
                            {
                                vertices[2],vertices[3],vertices[6] //front
                            },
                        };

                        // now, iterate over each plane and project the intersecting source vertex onto it 
                        // the smallest value will be the closest plane 
                        auto sourceVertex = sourceCorners.vertices[i];
                        int planeIndex = -1;
                        int minDist = 999999.0f;
                        filament::math::float3 projection;
                        for(int j = 0; j < 6; j++) {
                            // translate the plane so the intersecting source vertex is at the origin
                            auto plane = std::vector<filament::math::float3>{ planes[j][0] - sourceVertex, planes[j][1] - sourceVertex, planes[j][2] - sourceVertex };
                            
                            // cross product of the two known co-planar vectors to find the normal 
                            auto normal = normalize(cross(plane[1] - plane[0], plane[2] - plane[1]));

                            // project the normal onto the original (untranslated) plane vector 
                            auto dist = dot(planes[j][0], normal) / norm(planes[j][0]);
                            Log("Dist : %f", dist);
                            if(dist < minDist) {    
                                minDist = dist;
                                planeIndex = j;
                            }
                        }
                        Log("Collision with plane index %d", planeIndex);
                        auto sourceNormal = normalize(cross(planes[planeIndex][1] - planes[planeIndex][0], planes[planeIndex][2] - planes[planeIndex][1]));

                        projection = direction - (sourceNormal * dot(sourceNormal, direction));