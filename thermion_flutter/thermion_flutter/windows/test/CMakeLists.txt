# Compile the unmodified implementation into a test DLL. Its namespace-scope
# worker must undergo DLL_PROCESS_DETACH, just as it does in the shipping DLL.
set(_fixture_sources ${PLUGIN_SOURCES})
list(REMOVE_ITEM _fixture_sources "thermion_flutter_plugin.cpp")
list(TRANSFORM _fixture_sources PREPEND "${CMAKE_CURRENT_SOURCE_DIR}/../")
add_library(thermion_blit_worker_shutdown_fixture SHARED
  "blit_worker_shutdown_fixture.cpp"
  ${_fixture_sources})
target_compile_features(thermion_blit_worker_shutdown_fixture PRIVATE cxx_std_20)
target_include_directories(thermion_blit_worker_shutdown_fixture PRIVATE
  $<TARGET_PROPERTY:${PLUGIN_NAME},INCLUDE_DIRECTORIES>)
target_compile_definitions(thermion_blit_worker_shutdown_fixture PRIVATE
  $<TARGET_PROPERTY:${PLUGIN_NAME},COMPILE_DEFINITIONS>)
target_link_directories(thermion_blit_worker_shutdown_fixture PRIVATE
  $<TARGET_PROPERTY:${PLUGIN_NAME},LINK_DIRECTORIES>)
target_link_libraries(thermion_blit_worker_shutdown_fixture PRIVATE
  $<TARGET_PROPERTY:${PLUGIN_NAME},LINK_LIBRARIES>)

add_executable(thermion_blit_worker_shutdown_test "blit_worker_shutdown_test.cpp")
target_compile_features(thermion_blit_worker_shutdown_test PRIVATE cxx_std_17)
add_dependencies(thermion_blit_worker_shutdown_test
  thermion_blit_worker_shutdown_fixture)
set_target_properties(
  thermion_blit_worker_shutdown_fixture thermion_blit_worker_shutdown_test
  PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${runner_BINARY_DIR}/$<CONFIG>")
