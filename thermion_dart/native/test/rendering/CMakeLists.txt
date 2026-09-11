cmake_minimum_required(VERSION 3.22)
project(thermion_scheduling_tests LANGUAGES CXX)

if(MSVC)
  add_compile_options(/EHs-c-)
  add_compile_definitions(_HAS_EXCEPTIONS=0)
else()
  add_compile_options("$<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions>")
endif()

find_package(Threads REQUIRED)
add_library(upload_lifetime_fixture SHARED upload_lifetime_fixture.cpp)
target_compile_features(upload_lifetime_fixture PRIVATE cxx_std_17)
target_link_libraries(upload_lifetime_fixture PRIVATE Threads::Threads)
add_executable(scheduling_test
    scheduling_test.cpp
    ../../src/rendering/FrameScheduler.cpp)
target_compile_features(scheduling_test PRIVATE cxx_std_17)
target_include_directories(scheduling_test PRIVATE ../../include)
target_link_libraries(scheduling_test PRIVATE Threads::Threads)
if(APPLE)
    target_link_libraries(scheduling_test PRIVATE "-framework CoreVideo")
endif()
if(WIN32)
    target_link_libraries(scheduling_test PRIVATE dxgi)
endif()
enable_testing()
add_test(NAME scheduling COMMAND scheduling_test)
set_tests_properties(scheduling PROPERTIES TIMEOUT 30)

add_executable(worker_queue_test
    worker_queue_test.cpp
    ../../src/rendering/RenderThread.cpp)
target_compile_features(worker_queue_test PRIVATE cxx_std_17)
target_include_directories(worker_queue_test PRIVATE ../../include)
target_link_libraries(worker_queue_test PRIVATE Threads::Threads)
add_test(NAME worker_queue COMMAND worker_queue_test)
set_tests_properties(worker_queue PROPERTIES TIMEOUT 30)

# Optional: the render-control regression uses Filament headers and symbols
# from an existing native Thermion build, but does not create a GPU context.
if(THERMION_TEST_LIBRARY AND FILAMENT_TEST_INCLUDE_DIR)
    add_executable(render_control_test
        render_control_test.cpp
        ../../src/rendering/RenderManager.cpp
        ../../src/PluginRegistry.cpp)
    target_compile_features(render_control_test PRIVATE cxx_std_17)
    target_include_directories(render_control_test PRIVATE
        ../../include "${FILAMENT_TEST_INCLUDE_DIR}")
    target_link_libraries(render_control_test PRIVATE
        Threads::Threads "${THERMION_TEST_LIBRARY}")
    add_test(NAME render_request_nonblocking COMMAND render_control_test request)
    add_test(NAME render_pause_nonblocking COMMAND render_control_test pause)
    set_tests_properties(render_request_nonblocking render_pause_nonblocking
        PROPERTIES TIMEOUT 10)
endif()
