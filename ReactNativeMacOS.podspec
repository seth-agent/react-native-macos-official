require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name         = "ReactNativeMacOS"
  s.version      = package['version']
  s.summary      = package['description']
  s.homepage     = package['repository']['url']
  s.license      = package['license']
  s.authors      = "react-native-macos-official contributors"
  s.source       = { :git => package['repository']['url'], :tag => s.version }

  s.osx.deployment_target = '14.0'

  s.subspec 'RCTAppKit' do |ss|
    ss.source_files = 'macos/RCTAppKit/**/*.{h,m,mm}'
    ss.public_header_files = 'macos/RCTAppKit/**/*.h'
    ss.dependency 'React-Core'
  end

  s.subspec 'Views' do |ss|
    ss.source_files = 'macos/Views/**/*.{h,m,mm}'
    ss.public_header_files = 'macos/Views/**/*.h'
    ss.dependency 'ReactNativeMacOS/RCTAppKit'
    ss.dependency 'React-Core'
  end

  s.subspec 'TextInput' do |ss|
    ss.source_files = 'macos/TextInput/**/*.{h,m,mm}'
    ss.public_header_files = 'macos/TextInput/**/*.h'
    ss.dependency 'ReactNativeMacOS/RCTAppKit'
    ss.dependency 'React-Core'
  end

  s.subspec 'Linking' do |ss|
    ss.source_files = 'macos/Linking/**/*.{h,m,mm}'
    ss.dependency 'React-Core'
  end

  s.subspec 'Fabric' do |ss|
    ss.source_files = [
      'macos/Fabric/**/*.{h,m,mm,cpp}',
      'cpp/**/*.{h,cpp}',
    ]
    ss.public_header_files = [
      'macos/Fabric/**/*.h',
      'cpp/**/*.h',
    ]
    ss.dependency 'React-Core'
    ss.dependency 'React-Fabric'
    ss.dependency 'ReactNativeMacOS/RCTAppKit'
  end
end
