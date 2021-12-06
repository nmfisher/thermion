#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint polyvox_filament.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'polyvox_filament'
  s.version          = '0.0.1'
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*', 'src/*.*', 'src/morph/*.*', 'src/morph/UbershaderLoader.cpp' #, "include/**/*"
  #s.header_dir = "include"
  #s.header_mappings_dir = "include"
  s.dependency 'Flutter' 
  s.platform = :ios, '12.1'
  s.static_framework = true
  s.vendored_libraries = "lib/*.a"

  # Flutter.framework does not contain a i386 slice.
  s.user_target_xcconfig = {
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'ALWAYS_SEARCH_USER_PATHS' => 'YES',
    'USER_HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/polyvox_filament/ios/include" "${PODS_ROOT}/../.symlinks/plugins/polyvox_filament/ios/src", "${PODS_ROOT}/../.symlinks/plugins/polyvox_filament/ios/morph" "$(inherited)"',
    'OTHER_CXXFLAGS' => '"--std=c++17" "-fmodules" "-fcxx-modules" "$(inherited)"',
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
    #'LIBRARY_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/polyvox_filament/ios/lib" "$(inherited)"',
    #"CLANG_CXX_LIBRARY" => "libc++"
  }
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386', 
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
    #'OTHER_CXXFLAGS' => '--std=c++17 -fmodules -fcxx-modules -x c++',
    'OTHER_CXXFLAGS' => '"--std=c++17" "-fmodules" "-fcxx-modules" "$(inherited)"',
    "OTHER_LDFLAGS" =>  '-lfilament -lbackend -lmathio -lfilameshio -lviewer -lfilamat -lgeometry -lutils -lfilabridge -lgltfio_resources_lite -lgltfio_core -lfilament-iblprefilter -limage -lcamutils -lgltfio_resources -lmath -lfilaflat -ldracodec -libl',
    'USER_HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/polyvox_filament/ios/include" "${PODS_ROOT}/../.symlinks/plugins/polyvox_filament/ios/src", "${PODS_ROOT}/../.symlinks/plugins/polyvox_filament/ios/morph" "$(inherited)"',
    'ALWAYS_SEARCH_USER_PATHS' => 'YES',
    'LIBRARY_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/polyvox_filament/ios/lib" "$(inherited)"',
  }
      
  s.swift_version = '5.0'
end
