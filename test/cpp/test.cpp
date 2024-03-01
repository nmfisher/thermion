
#include <filament/Engine.h>
#include <iostream>
#include <math.h>
#include <fstream>
#include <cstring>
#include <vector>
#include <string> 
#include <map>
#include <unistd.h>

#include "SceneManager.hpp"

#include "ResourceBuffer.hpp"

using namespace filament;
using namespace flutter_filament;
using namespace std;

int _i = 0;

ResourceBuffer loadResource(const char* name) {

    std::cout << "LOADING RESOURCE" << std::endl;

    char cwd[PATH_MAX];
    if (getcwd(cwd, sizeof(cwd)) != NULL) {
       std::cout << "Current working dir: " << cwd  << std::endl;
    }

    string name_str(name);
    auto id = _i++;
    
    name_str = string(cwd) + string("/") + name_str;
    
    std::cout << "Loading resource at " << name_str.c_str() << std::endl;

    streampos length;
    ifstream is(name_str, ios::binary);
    ResourceBuffer rb { nullptr, -1, 0 };
    if(!is) {
      std::cout << "Failed to find resource at file path " << name_str.c_str() << std::endl;
      return rb;
    }
    is.seekg (0, ios::end);
    length = is.tellg();
    char * buffer;
    buffer = new char [length];
    is.seekg (0, ios::beg);
    is.read (buffer, length);
    is.close();      
    return ResourceBuffer { buffer, static_cast<int32_t>(length), id };
}

void freeResource(ResourceBuffer rb) {

}

int main(int argc, char** argv) {
    auto engine = Engine::create();
    auto scene = engine->createScene();
    auto loader = ResourceLoaderWrapper(loadResource, freeResource);

    auto sceneManager = SceneManager(&loader, engine, scene, nullptr);

    auto shapes = sceneManager.loadGlb("../example/assets/shapes/shapes.glb", 1);

    auto morphTargetNames = sceneManager.getMorphTargetNames(shapes, "Cylinder");
    assert(morphTargetNames->size() == 4);

    morphTargetNames = sceneManager.getMorphTargetNames(shapes, "Cube");
    assert(morphTargetNames->size() == 2);

    morphTargetNames = sceneManager.getMorphTargetNames(shapes, "Cone");
    assert(morphTargetNames->size() == 8);
    sceneManager.destroyAll();
}