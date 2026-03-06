# Helper for integrating react-native-macos-official into a CocoaPods project.
#
# Usage in your macOS target's Podfile:
#
#   require_relative '../node_modules/react-native-macos-official/scripts/react_native_macos_pods'
#
#   target 'MyApp-macOS' do
#     platform :macos, '14.0'
#     use_react_native_macos!
#   end

def use_react_native_macos!(options = {})
  macos_package_path = options[:path] || File.join(
    __dir__, '..', '..'
  )

  # Add the main ReactNativeMacOS pod
  pod 'ReactNativeMacOS', :path => macos_package_path

  # Add subspecs
  pod 'ReactNativeMacOS/RCTAppKit', :path => macos_package_path
  pod 'ReactNativeMacOS/Views', :path => macos_package_path
  pod 'ReactNativeMacOS/TextInput', :path => macos_package_path
  pod 'ReactNativeMacOS/Linking', :path => macos_package_path
  pod 'ReactNativeMacOS/Fabric', :path => macos_package_path
end

# Returns the minimum macOS version supported.
def min_macos_version_supported
  '14.0'
end
