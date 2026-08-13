#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint thermion_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'thermion_flutter'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  # Sources live under the Swift Package Manager layout so the same files back
  # both the SPM package (thermion_flutter/Package.swift) and this podspec.
  s.source_files = 'thermion_flutter/Sources/**/*.{swift,h,c}'
  # The Dart Native API C sources #include their headers as "dart_api_dl.h" and
  # "internal/dart_api_dl_impl.h"; put that include dir on the search path so
  # both quoted forms resolve (SPM adds it automatically for the C target).
  dart_api_headers = '"$(PODS_TARGET_SRCROOT)/thermion_flutter/Sources/thermion_flutter_dart_api/include"'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '13.0'

  s.ios.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => dart_api_headers
  }
  s.osx.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => dart_api_headers
  }
  s.swift_version = '5.0'

end
