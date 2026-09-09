cmake_minimum_required(VERSION 3.22)
project(thermion_scheduling_tests LANGUAGES CXX)

find_package(Threads REQUIRED)
add_library(upload_lifetime_fixture SHARED upload_lifetime_fixture.cpp)
target_compile_features(upload_lifetime_fixture PRIVATE cxx_std_17)
target_link_libraries(upload_lifetime_fixture PRIVATE Threads::Threads)
add_library(task_error_fixture SHARED task_error_fixture.cpp)
target_compile_features(task_error_fixture PRIVATE cxx_std_17)

add_executable(scheduling_test
    scheduling_test.cpp
    ../../src/rendering/RenderThread.cpp
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
