#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint mimetic_filament.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'mimetic_filament'
  s.version          = '0.0.1'
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*', 'src/*.*'
  s.dependency 'Filament', '~> 1.12.3'
  s.dependency 'Flutter' 
  s.platform = :ios, '12.1'
  s.static_framework = true

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386', 
    'ALWAYS_SEARCH_USER_PATHS' => 'YES',
    'USER_HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/mimetic_filament/ios/include"',
    'OTHER_CFLAGS' => '-fmodules -fcxx-modules' }
  s.swift_version = '5.0'
end
