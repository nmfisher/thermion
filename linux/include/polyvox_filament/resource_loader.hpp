#ifndef POLYVOX_FILAMENT_LINUX_RESOURCE_LOADER_H
#define POLYVOX_FILAMENT_LINUX_RESOURCE_LOADER_H

#include <math.h>
#include <iostream>
#include <fstream>
#include <cstring>
#include <vector>
#include <string> 
#include <map>
#include <unistd.h>

#include "ResourceBuffer.hpp"

using namespace std;

static map<uint32_t, void*> _file_assets;
static uint32_t _i = 0;

ResourceBuffer loadResource(const char* name) {

    char cwd[PATH_MAX];
    if (getcwd(cwd, sizeof(cwd)) != NULL) {
       std::cout << "Current working dir: " << cwd  << std::endl;
    }

    string name_str(name);
    auto id = _i++;
    
    // this functions accepts URIs, so  
    // - file:// points to a file on the filesystem
    // - asset:// points to an asset, usually resolved relative to the current working directory
    // - no prefix is presumed to be an absolute file path
    if (name_str.rfind("file://", 0) == 0) {
      name_str = name_str.substr(7);
    } else if(name_str.rfind("asset://", 0) == 0) {
      name_str = name_str.substr(7);
      name_str = string(cwd) + string("/") + name_str;
    } else {
      
    }

    std::cout << "Loading resource at " << name_str.c_str() << std::endl;

    streampos length;
    ifstream is(name_str, ios::binary);
    if(!is) {
      std::cout << "Failed to find resource at file path " << name_str.c_str() << std::endl;
      return ResourceBuffer(nullptr, 0, -1);
    }
    is.seekg (0, ios::end);
    length = is.tellg();
    char * buffer;
    buffer = new char [length];
    is.seekg (0, ios::beg);
    is.read (buffer, length);
    is.close();      
    _file_assets[id] = buffer;
    return ResourceBuffer(buffer, length, id);
}

void freeResource(uint32_t id) {
  std::cout << "Freeing resource " << id << std::endl;
  auto it = _file_assets.find(id);
  if (it != _file_assets.end()) {
    free(it->second);
  }
}

#endif