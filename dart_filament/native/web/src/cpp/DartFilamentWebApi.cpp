#include "FlutterFilamentWebApi.h"
#include "ResourceBuffer.hpp"

#include <thread>
#include <mutex>
#include <future>
#include <iostream>

#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>
#include <emscripten/emscripten.h>
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#include <emscripten/val.h>
#include <emscripten/fetch.h>

class PendingCall
{
public:
  PendingCall()
  {
  }
  ~PendingCall() {}

  void Wait()
  {
    std::future<int32_t> accumulate_future = prom.get_future();
    std::cout << "Loaded asset from Flutter of length " << accumulate_future.get() << std::endl;
  }

  void HandleResponse(void* data, int32_t length)
  {
    this->data = data;
    this->length = length;
    prom.set_value(length);
  }
void* data = nullptr;
int32_t length = 0;

private:
  std::mutex mutex_;
  std::condition_variable cv_;
  bool notified_ = false;
  std::promise<int32_t> prom;

};

using emscripten::val;

extern "C"
{
  
  // 
  // Since are using -sMAIN_MODULE with -sPTHREAD_POOL_SIZE=1, main will be called when the first worker is spawned
  //
  EMSCRIPTEN_KEEPALIVE int main() {
    return 0;
  }

  EMSCRIPTEN_KEEPALIVE void flutter_filament_web_load_resource_callback(void* data, int32_t length, void* context) {
    ((PendingCall*)context)->HandleResponse(data, length);
  }

  EMSCRIPTEN_KEEPALIVE void flutter_filament_web_set(char* ptr, int32_t offset, int32_t val) {
    memset(ptr+offset, val, 1);
  }

  EMSCRIPTEN_KEEPALIVE void flutter_filament_web_set_float(float* ptr, int32_t offset, float val) {
    ptr[offset] = val;
  }

  EMSCRIPTEN_KEEPALIVE float flutter_filament_web_get_float(float* ptr, int32_t offset) {
    return ptr[offset];
  }

  EMSCRIPTEN_KEEPALIVE double flutter_filament_web_get_double(double* ptr, int32_t offset) {
    return ptr[offset];
  }

  EMSCRIPTEN_KEEPALIVE void flutter_filament_web_set_double(double* ptr, int32_t offset, double value) {
    ptr[offset] = value;
  }

  EMSCRIPTEN_KEEPALIVE int32_t flutter_filament_web_get_int32(int32_t* ptr, int32_t offset) {
    return ptr[offset];
  }

  EMSCRIPTEN_KEEPALIVE void flutter_filament_web_set_int32(int32_t* ptr, int32_t offset, int32_t value) {
    ptr[offset] = value;
  }

  EMSCRIPTEN_KEEPALIVE void flutter_filament_web_set_pointer(void** ptr, int32_t offset, void* val) { 
    ptr[offset] = val;
  }

  EMSCRIPTEN_KEEPALIVE void* flutter_filament_web_get_pointer(void** ptr, int32_t offset) { 
    return ptr[offset];
  }

  EMSCRIPTEN_KEEPALIVE char flutter_filament_web_get(char* ptr, int32_t offset) {
    return ptr[offset];
  }

  EMSCRIPTEN_KEEPALIVE void* flutter_filament_web_allocate(int32_t size) {
    void* allocated = (void*)calloc(size, 1);
    return allocated;
  }

  EMSCRIPTEN_KEEPALIVE long flutter_filament_web_get_address(void** out) {
    return (long)*out;
  }

  EMSCRIPTEN_KEEPALIVE EMSCRIPTEN_WEBGL_CONTEXT_HANDLE flutter_filament_web_create_gl_context() {

    std::cout << "Creating WebGL context." << std::endl;

    EmscriptenWebGLContextAttributes attr;
    
    emscripten_webgl_init_context_attributes(&attr);
    attr.alpha = EM_TRUE;
    attr.depth = EM_TRUE;
    attr.stencil = EM_FALSE;
    attr.antialias = EM_FALSE;
    attr.explicitSwapControl = EM_TRUE;
    attr.preserveDrawingBuffer = EM_FALSE;
    attr.proxyContextToMainThread = EMSCRIPTEN_WEBGL_CONTEXT_PROXY_ALWAYS;
    attr.enableExtensionsByDefault = EM_TRUE;
    attr.renderViaOffscreenBackBuffer = EM_FALSE;
    attr.majorVersion = 2;
    
    auto context = emscripten_webgl_create_context("#canvas", &attr);
    std::cout << "Created WebGL context " << attr.majorVersion << "." << attr.minorVersion << std::endl;

    auto success = emscripten_webgl_make_context_current((EMSCRIPTEN_WEBGL_CONTEXT_HANDLE)context);
    if(success != EMSCRIPTEN_RESULT_SUCCESS) {
      std::cout << "Failed to make WebGL context current"<< std::endl;
    } else { 
      std::cout << "Made WebGL context current"<< std::endl;
      // glClearColor(1.0, 0.0, 0.0, 1.0);
      // glClear(GL_COLOR_BUFFER_BIT);
      // emscripten_webgl_commit_frame();
    }
    emscripten_webgl_make_context_current((EMSCRIPTEN_WEBGL_CONTEXT_HANDLE)NULL);
    return context;
  }

  int _lastResourceId = 0;

  ResourceBuffer flutter_filament_web_load_resource(const char* path)
  {
    // ideally we should bounce the call to Flutter then wait for callback
    // this isn't working for large assets though - seems like it's deadlocked
    // will leave this here commented out so we can revisit later if needed
    // auto pendingCall = new PendingCall();
    // loadFlutterAsset(path, (void*)pendingCall);
    // pendingCall->Wait();
    // auto rb = ResourceBuffer { pendingCall->data, (int32_t) pendingCall->length, _lastResourceId  } ;
    _lastResourceId++;
    // delete pendingCall;
    // std::cout << "Deleted pending call" << std::endl;

    // emscripten_fetch_attr_t attr;
    // emscripten_fetch_attr_init(&attr);
    // attr.onsuccess = [](emscripten_fetch_t* fetch) {
      
    // };
    // attr.onerror = [](emscripten_fetch_t* fetch) {
      
    // };
    // attr.onprogress = [](emscripten_fetch_t* fetch) {
      
    // };
    // attr.onreadystatechange = [](emscripten_fetch_t* fetch) {
      
    // };
    // attr.attributes = EMSCRIPTEN_FETCH_LOAD_TO_MEMORY | EMSCRIPTEN_FETCH_SYNCHRONOUS | EMSCRIPTEN_FETCH_PERSIST_FILE;

    auto pathString = std::string(path);
    // if(pathString.rfind("https://",0) != 0) {
    //   pathString = std::string("../../") + pathString;
    // }
    
    // std::cout << "Fetching from path " << pathString.c_str() << std::endl;

    // auto request = emscripten_fetch(&attr, pathString.c_str());
    // if(!request) {
    //   std::cout << "Request failed?" << std::endl;  
    // }
    // auto data = malloc(request->numBytes);
    // memcpy(data, request->data, request->numBytes);
    // emscripten_fetch_close(request);
    // return ResourceBuffer { data, (int32_t) request->numBytes, _lastResourceId  } ;
    void* data = nullptr;
    int32_t numBytes = 0;
    
    void** pBuffer = (void**)malloc(sizeof(void*));
    int* pNum = (int*) malloc(sizeof(int*));
    int* pError = (int*)malloc(sizeof(int*));
    emscripten_wget_data(pathString.c_str(), pBuffer, pNum, pError);
    data = *pBuffer;
    numBytes = *pNum;
    free(pBuffer);
    free(pNum);
    free(pError);
    return ResourceBuffer { data, numBytes, _lastResourceId  } ;   
  }

  void flutter_filament_web_free_resource(ResourceBuffer rb) {
    free((void*)rb.data);
  }
  
  EMSCRIPTEN_KEEPALIVE void flutter_filament_web_free(void* ptr) {
    free(ptr);
  }

  EMSCRIPTEN_KEEPALIVE void* flutter_filament_web_get_resource_loader_wrapper() {
    ResourceLoaderWrapper *rlw = (ResourceLoaderWrapper *)malloc(sizeof(ResourceLoaderWrapper));
    rlw->loadResource = flutter_filament_web_load_resource;
    rlw->loadFromOwner = nullptr;
    rlw->freeResource = flutter_filament_web_free_resource;
    rlw->freeFromOwner = nullptr;
    rlw->loadToOut = nullptr;
    rlw->owner = nullptr;
    return rlw;
  }
}