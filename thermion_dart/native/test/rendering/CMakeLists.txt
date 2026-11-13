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
    ../../src/rendering/NativeJobThread.cpp)
target_compile_features(worker_queue_test PRIVATE cxx_std_17)
target_include_directories(worker_queue_test PRIVATE ../../include)
target_link_libraries(worker_queue_test PRIVATE Threads::Threads)
add_test(NAME worker_queue COMMAND worker_queue_test)
set_tests_properties(worker_queue PROPERTIES TIMEOUT 30)

# Production stays exception-free. Also exercise stack unwinding for consumers
# that compile NativeJobThread with exceptions enabled.
if(NOT MSVC)
    add_executable(worker_queue_exceptions_test
        worker_queue_test.cpp
        ../../src/rendering/NativeJobThread.cpp)
    target_compile_features(worker_queue_exceptions_test PRIVATE cxx_std_17)
    target_compile_options(worker_queue_exceptions_test PRIVATE -fexceptions)
    target_include_directories(worker_queue_exceptions_test PRIVATE ../../include)
    target_link_libraries(worker_queue_exceptions_test PRIVATE Threads::Threads)
    add_test(NAME worker_queue_exceptions COMMAND worker_queue_exceptions_test)
    set_tests_properties(worker_queue_exceptions PROPERTIES TIMEOUT 30)
endif()

# Engine API lock regression: loads a built thermion_dart library at runtime
# (path passed as the first argument), so it needs no Filament headers.
add_executable(engine_api_lock_test engine_api_lock_test.cpp)
target_compile_features(engine_api_lock_test PRIVATE cxx_std_17)
target_include_directories(engine_api_lock_test PRIVATE ../../include)
target_link_libraries(engine_api_lock_test PRIVATE Threads::Threads ${CMAKE_DL_LIBS})
if(THERMION_TEST_LIBRARY)
    add_test(NAME engine_api_lock
        COMMAND engine_api_lock_test "${THERMION_TEST_LIBRARY}" 20)
    set_tests_properties(engine_api_lock PROPERTIES TIMEOUT 90)
endif()

# Optional: the render-control regression uses Filament headers and symbols
# from an existing native Thermion build, but does not create a GPU context.
if(THERMION_TEST_LIBRARY AND FILAMENT_TEST_INCLUDE_DIR)
    add_executable(job_thread_handle_test job_thread_handle_test.cpp)
    target_compile_features(job_thread_handle_test PRIVATE cxx_std_17)
    target_include_directories(job_thread_handle_test PRIVATE
        ../../include "${FILAMENT_TEST_INCLUDE_DIR}")
    target_link_libraries(job_thread_handle_test PRIVATE
        Threads::Threads "${THERMION_TEST_LIBRARY}")
    add_test(NAME job_thread_handles COMMAND job_thread_handle_test)
    set_tests_properties(job_thread_handles PROPERTIES TIMEOUT 20)

    add_executable(render_control_test
        render_control_test.cpp
        ../../src/rendering/RenderManager.cpp
        ../../src/PluginRegistry.cpp)
    target_compile_features(render_control_test PRIVATE cxx_std_17)
    target_include_directories(render_control_test PRIVATE
        ../../include "${FILAMENT_TEST_INCLUDE_DIR}")
    target_link_libraries(render_control_test PRIVATE
        Threads::Threads "${THERMION_TEST_LIBRARY}")
    add_test(NAME render_pause_nonblocking COMMAND render_control_test)
    set_tests_properties(render_pause_nonblocking
        PROPERTIES TIMEOUT 10)
endif()
