cmake_minimum_required(VERSION 3.22)
project(thermion_scheduling_tests LANGUAGES CXX)

set(FILAMENT_INCLUDE_DIR "" CACHE PATH "Directory containing filament/Renderer.h")
if(NOT EXISTS "${FILAMENT_INCLUDE_DIR}/filament/Renderer.h")
    message(FATAL_ERROR "Set FILAMENT_INCLUDE_DIR to the Filament include directory")
endif()

find_package(Threads REQUIRED)
add_executable(scheduling_test
    scheduling_test.cpp
    ../../src/rendering/FrameScheduler.cpp)
target_compile_features(scheduling_test PRIVATE cxx_std_17)
target_include_directories(scheduling_test PRIVATE ../../include "${FILAMENT_INCLUDE_DIR}")
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
