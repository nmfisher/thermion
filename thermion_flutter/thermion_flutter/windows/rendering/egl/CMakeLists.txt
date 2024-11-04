cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "thermion_egl")
project(${PROJECT_NAME} LANGUAGES C CXX)

cmake_policy(VERSION 3.14...3.25)

add_compile_definitions(THERMION_EGL)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
set(BUILD_SHARED_LIBS TRUE)
set(CMAKE_ENABLE_EXPORTS TRUE)

add_library(${PROJECT_NAME} SHARED
  "egl_context.cpp"
  "egl_texture.cpp"
)

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_20)
include_directories(${PROJECT_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/../../include"
)

add_library(EGL SHARED IMPORTED)
set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_DEBUG "E:\\angle\\libEGL.dll.lib")
set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_PROFILE "E:\\angle\\libEGL.dll.lib")
set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_RELEASE "E:\\angle\\libEGL.dll.lib")
set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_MINSIZEREL "E:\\angle\\libEGL.dll.lib")
set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_RELWITHDEBINFO "E:\\angle\\libEGL.dll.lib")
add_library(GLESv2 SHARED IMPORTED)
set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_DEBUG "E:\\angle\\libGLESv2.dll.lib")
set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_PROFILE "E:\\angle\\libGLESv2.dll.lib")
set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_RELEASE "E:\\angle\\libGLESv2.dll")
set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_MINSIZEREL "E:\\angle\\libGLESv2.dll")
set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_RELWITHDEBINFO "E:\\angle\\libGLESv2.dll")

target_link_libraries(${PROJECT_NAME} PRIVATE 
 Shlwapi
 EGL 
 GLESv2
 dxgi
  d3d11
)

# Test executable
add_executable(${PROJECT_NAME}_test
  "main.cpp"
)

# Make sure the test depends on the library
add_dependencies(${PROJECT_NAME}_test ${PROJECT_NAME})

target_link_libraries(${PROJECT_NAME}_test PRIVATE
  ${PROJECT_NAME}
)

# Copy ANGLE DLLs to the output directory
add_custom_command(TARGET ${PROJECT_NAME}_test POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "E:/angle/libEGL.dll"
        "E:/angle/libGLESv2.dll"
        "$<TARGET_FILE_DIR:${PROJECT_NAME}_test>"
)