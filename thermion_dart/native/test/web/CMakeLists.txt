cmake_minimum_required(VERSION 3.22)
project(thermion_web_tests LANGUAGES CXX)

if(NOT EMSCRIPTEN OR NOT FILAMENT_TEST_LIB_DIR)
  message(FATAL_ERROR "Use emcmake and provide FILAMENT_TEST_LIB_DIR with matching web libraries and include/")
endif()

add_executable(web_upload_drain_test
  web_upload_drain_test.cpp
  ../../src/rendering/RenderManager.cpp)
target_compile_features(web_upload_drain_test PRIVATE cxx_std_17)
target_include_directories(web_upload_drain_test PRIVATE
  ../../include "${FILAMENT_TEST_LIB_DIR}/include")
target_compile_options(web_upload_drain_test PRIVATE -pthread -fno-exceptions)
file(GLOB FILAMENT_TEST_LIBRARIES "${FILAMENT_TEST_LIB_DIR}/*.a")
# The SDK also ships Google Benchmark / Google Test entry points.
list(FILTER FILAMENT_TEST_LIBRARIES EXCLUDE REGEX "(benchmark|gtest|gmock|main).*\\.a$")
target_link_libraries(web_upload_drain_test PRIVATE
  -Wl,--start-group ${FILAMENT_TEST_LIBRARIES} -Wl,--end-group)
target_link_options(web_upload_drain_test PRIVATE
  -pthread -sPTHREAD_POOL_SIZE=1 -sALLOW_BLOCKING_ON_MAIN_THREAD=1
  -sINITIAL_MEMORY=134217728 -sSTACK_SIZE=10485760
  -sFULL_ES3=1 -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2
  -sENVIRONMENT=node -sEXIT_RUNTIME=1)

add_executable(web_canvas_thread_test
  web_canvas_thread_test.cpp
  ../../src/rendering/RenderThread.cpp
  ../../src/rendering/RenderManager.cpp)
target_compile_features(web_canvas_thread_test PRIVATE cxx_std_17)
target_compile_definitions(web_canvas_thread_test PRIVATE THERMION_WEB_SINGLE_THREADED=1)
target_include_directories(web_canvas_thread_test PRIVATE
  ../../include ../../web/include "${FILAMENT_TEST_LIB_DIR}/include")
target_compile_options(web_canvas_thread_test PRIVATE -pthread -fno-exceptions)
target_link_libraries(web_canvas_thread_test PRIVATE
  -Wl,--start-group ${FILAMENT_TEST_LIBRARIES} -Wl,--end-group)
target_link_options(web_canvas_thread_test PRIVATE
  -pthread -sPTHREAD_POOL_SIZE=1 -sALLOW_BLOCKING_ON_MAIN_THREAD=1
  -sINITIAL_MEMORY=134217728 -sSTACK_SIZE=10485760
  -sFULL_ES3=1 -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2
  -sENVIRONMENT=node -sEXIT_RUNTIME=1)
