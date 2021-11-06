

//VertexBuffer* vBuf = VertexBuffer::Builder()
//        .vertexCount(numVertices)
//        .bufferCount(numPrimitives)
//        .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT4, 0)
//        .build(*engine);

//numIndices = maxIndex+1; */
//numIndices = prim.indices->count;

/*indicesBuffer = (uint32_t*)malloc(sizeof(unsigned int) * prim.indices->count);

//materialInstance->setParameter("vertexIndices", indicesBuffer, numIndices);

//.require(VertexAttribute::UV0)
//.require(MaterialBuilder.VertexAttribute.CUSTOM0)
//MaterialBuilder::init();
//MaterialBuilder builder = MaterialBuilder()
//        .name("DefaultMaterial")
//        .platform(MaterialBuilder::Platform::MOBILE)
//        .targetApi(MaterialBuilder::TargetApi::ALL)
//        .optimization(MaterialBuilderBase::Optimization::NONE)
//        .shading(MaterialBuilder::Shading::LIT)
//        .parameter(MaterialBuilder::UniformType::FLOAT3, "baseColor")
//        .parameter(MaterialBuilder::UniformType::INT3, "dimensions")
//        .parameter(MaterialBuilder::UniformType::FLOAT, numTargets, MaterialBuilder::ParameterPrecision::DEFAULT, "morphTargetWeights")
//        .parameter(MaterialBuilder::SamplerType::SAMPLER_2D_ARRAY, MaterialBuilder::SamplerFormat::FLOAT, MaterialBuilder::ParameterPrecision::DEFAULT, "morphTargets")
//        .vertexDomain(VertexDomain::WORLD)
//        .material(R"SHADER(void material(inout MaterialInputs material) {
//                              prepareMaterial(material);
//                              material.baseColor.rgb = materialParams.baseColor;
//                          })SHADER")
//        .materialVertex(R"SHADER(
//                    vec3 getMorphTarget(int vertexIndex, int morphTargetIndex) {
//                        // our texture is laid out as (x,y,z) where y is 1, z is the number of morph targets, and x is the number of vertices * 2 (multiplication accounts for position + normal)
//                        // UV coordinates are normalized to (-1,1), so we divide the current vertex index by the total number of vertices to find the correct coordinate for this vertex
//                        vec3 uv = vec3(
//                            (float(vertexIndex) + 0.5) / float(materialParams.dimensions.x),
//                            0.0f,
//                            //(float(morphTargetIndex) + 0.5f) / float(materialParams.dimensions.z));
//                            float(morphTargetIndex));
//                        return texture(materialParams_morphTargets, uv).xyz;
//                    }
//
//                    void materialVertex(inout MaterialVertexInputs material) {
//                        return;
//                        // for every morph target
//                        for(int morphTargetIndex = 0; morphTargetIndex < materialParams.dimensions.z; morphTargetIndex++) {
//
//                            // get the weight to apply
//                            float weight = materialParams.morphTargetWeights[morphTargetIndex];
//
//                            // get the ID of this vertex, which will be the x-offset of the position attribute in the texture sampler
//                            int vertexId = getVertexIndex();
//
//                            // get the position of the target for this vertex
//                            vec3 morphTargetPosition = getMorphTarget(vertexId, morphTargetIndex);
//                            // update the world position of this vertex
//                            material.worldPosition.xyz += (weight * morphTargetPosition);
//
//                            // increment the vertexID by half the size of the texture to get the x-offset of the normal (all positions stored in the first half, all normals stored in the second half)
//
//                            vertexId += (materialParams.dimensions.x / 2);
//
//                            // get the normal of this target for this vertex
//                            vec3 morphTargetNormal = getMorphTarget(vertexId, morphTargetIndex);
//                            material.worldNormal += (weight * morphTargetNormal);
//                        }
//                        mat4 transform = getWorldFromModelMatrix();
//                        material.worldPosition = mulMat4x4Float3(transform, material.worldPosition.xyz);
//                    })SHADER");
//
//Package pkg = builder.build(mAsset->mEngine->getJobSystem());
//Material* material = Material::Builder().package(pkg.getData(), pkg.getSize())
//        .build(*mAsset->mEngine);

//size_t normal_size = sizeof(short4);
//assert(textureWidth * (position_size + normal_size) == textureSize);
//assert(textureWidth * position_size == textureSize);
/*__android_log_print(ANDROID_LOG_INFO, "MyTag", "Expected size  %d width at level 0 %d height", Texture::PixelBufferDescriptor::computeDataSize(Texture::Format::RGB,
                                                                                                                     Texture::Type::FLOAT, 24, 1, 4), texture->getWidth(0),texture->getHeight(0)); */

/*        Texture::PixelBufferDescriptor descriptor(
                textureBuffer,
                textureSize,
                Texture::Format::RGB,
                Texture::Type::FLOAT,
                4, 0,0, 24,
                FREE_CALLBACK,
                nullptr); */

/*for(int i = 0; i < int(textureSize / sizeof(float)); i++) {
    __android_log_print(ANDROID_LOG_INFO, "MyTag", "offset %d %f", i, *(textureBuffer+i));
//}*/
//std::cout << "Checking for " << materialInstanceName << std::endl;
//if(materialInstanceName) {
//  for(int i = 0; i < asset->getMaterialInstanceCount(); i++) {
//      const char* name = instances[i]->getName();
//      std::cout << name << std::endl;
//      if(strcmp(name, materialInstanceName) == 0) {
//          materialInstance = instances[i];
//          break;
//      }
//  }
//} else {
//  materialInstance = instances[0];
//}
//
//if(!materialInstance) {
//    exit(-1);
//}

//              std::cout << std::endl;
              /*        for (int i = 0; i < 4; i++) {
                          morphHelperPrim.positions[i] = gltfioPrim.morphPositions[i];
                          morphHelperPrim.tangents[i] = gltfioPrim.morphTangents[i];
                      } */

//        applyTextures(materialInstance);
        
/*        const Entity* entities = mAsset->getEntities();
        for(int i=0; i < mAsset->getEntityCount();i++) {
          std::cout << mAsset->getName(entities[i]);
        } */

//        Entity entity = mAsset->getFirstEntityByName(entityName);
//        RenderableManager::Instance rInst = mAsset->mEngine->getRenderableManager().getInstance(entity);
//        for(int i = 0; i<num_primitives;i++) {
//          mAsset->mEngine->getRenderableManager().setMaterialInstanceAt(rInst, i, materialInstance);
//        }
