#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint polyvox_filament.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'polyvox_filament'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/*', 'src/*', 'include/filament/*', 'include/*', 'include/material/*.c'
  s.public_header_files = 'include/SwiftPolyvoxFilamentPlugin-Bridging-Header.h',  'include/PolyvoxFilamentApi.h', 'include/ResourceBuffer.hpp' #, 'include/filament/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '13'
  # s.user_target_xcconfig = { 
  #   'DEFINES_MODULE' => 'YES', 
  #   'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386', 
  #   "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
  #   'OTHER_CFLAGS' => '"-fvisibility=default" "$(inherited)"',
  #   'USER_HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/polyvox_filament/macos/zzzinclude" "${PODS_ROOT}/../.symlinks/plugins/polyvox_filament/macos/src" "${PODS_ROOT}/../.symlinks/plugins/polyvox_filament/macos/src/image" "${PODS_ROOT}/../.symlinks/plugins/polyvox_filament/macos/src/shaders"  "$(inherited)"',
  #   'ALWAYS_SEARCH_USER_PATHS' => 'YES',
  #   "OTHER_LDFLAGS" =>  '-lfilament -lbackend -lfilameshio -lviewer -lfilamat -lgeometry -lutils -lfilabridge -lgltfio_core -lfilament-iblprefilter -limage -limageio -ltinyexr -lcamutils -lgltfio_core -lfilaflat -ldracodec -libl -lktxreader -lpng -lpng16  -lz -lstb -luberzlib -lsmol-v -luberarchive -lzstd',
  #   'LIBRARY_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/polyvox_filament/macos/lib" "$(inherited)"',
  # }

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386', 
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
    'OTHER_CXXFLAGS' => '"--std=c++17" "-fmodules" "-fcxx-modules" "-fvisibility=default" "$(inherited)"',
    'OTHER_CFLAGS' => '"-fvisibility=default" "$(inherited)"',
    'USER_HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/include" "$(inherited)"',
    'ALWAYS_SEARCH_USER_PATHS' => 'YES',
    "OTHER_LDFLAGS" =>  '-lfilament -lbackend -lfilameshio -lviewer -lfilamat -lgeometry -lutils -lfilabridge -lgltfio_core -lfilament-iblprefilter -limage -limageio -ltinyexr -lcamutils -lgltfio_core -lfilaflat -ldracodec -libl -lktxreader -lpng -lz -lstb -luberzlib -lsmol-v -luberarchive -lzstd -lvkshaders -lbluegl -lbluevk -lbasis_transcoder -lmeshoptimizer',
    'LIBRARY_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/lib" "$(inherited)"',
  }
  s.swift_version = '5.0'
  
end
