# Keep the cache layout in sync with thermion_dart/hook/build.dart and
# lib/src/hooks/filament_artifacts.dart. These paths must be available before
# flutter_assemble runs the hook that downloads the headers.
include_guard(GLOBAL)

function(thermion_windows_filament_headers output package_root)
  set(_version_file "${package_root}/lib/filament_version.dart")
  if(NOT EXISTS "${_version_file}")
    message(FATAL_ERROR "thermion_flutter: missing Filament version: ${_version_file}")
  endif()
  file(READ "${_version_file}" _version_source)
  string(REGEX MATCH "filamentVersion[ \t\r\n]*=[ \t\r\n]*'([^']+)'" _match "${_version_source}")
  if(NOT _match)
    message(FATAL_ERROR "thermion_flutter: cannot read Filament version from ${_version_file}")
  endif()
  set(_version "${CMAKE_MATCH_1}")

  set(_pin_file "${package_root}/filament.libs.json")
  set(_pin "{}")
  if(EXISTS "${_pin_file}")
    file(READ "${_pin_file}" _contents)
    string(JSON _type ERROR_VARIABLE _error TYPE "${_contents}")
    if(NOT _error AND _type STREQUAL "OBJECT")
      set(_pin "${_contents}")
    else()
      message(WARNING "thermion_flutter: invalid ${_pin_file}; using legacy artifact paths")
    endif()
  endif()
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${_version_file}" "${_pin_file}")

  # The hook defaults to release even for a Flutter Debug build. Headers are
  # mode-independent, so include both resolved paths and let the hook populate
  # its selected mode. Do not require either directory to exist at configure.
  set(_headers "")
  foreach(_mode IN ITEMS release debug)
    set(_suffix "")
    string(JSON _type ERROR_VARIABLE _error TYPE "${_pin}" "windows/${_mode}")
    if(NOT _error)
      string(JSON _sha GET "${_pin}" "windows/${_mode}")
      string(LENGTH "${_sha}" _length)
      if(_type STREQUAL "STRING" AND _length EQUAL 64 AND _sha MATCHES "^[0-9a-fA-F]+$")
        string(TOLOWER "${_sha}" _sha)
        string(SUBSTRING "${_sha}" 0 16 _hash)
        set(_suffix "-${_hash}")
      else()
        message(WARNING "thermion_flutter: invalid windows/${_mode} pin; using legacy artifact path")
      endif()
    endif()
    list(APPEND _headers
      "${package_root}/.dart_tool/thermion_dart/lib/${_version}/windows/${_mode}${_suffix}/include")
  endforeach()
  set(${output} "${_headers}" PARENT_SCOPE)
endfunction()
