require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-rtl-sdk"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = "https://github.com/BOON-Rewards/rtl_rn_sdk"
  s.license      = { :type => "Proprietary" }
  s.authors      = { "BOON Rewards" => "support@getboon.com" }
  s.platforms    = { :ios => "15.1" }
  s.source       = { :git => "https://github.com/BOON-Rewards/rtl_rn_sdk.git", :tag => "#{s.version}" }
  s.source_files = "ios/**/*.{h,m,mm,swift}"
  s.swift_version = "5.7"

  s.dependency "React-Core"
  # The host Podfile supplies RTLSdk from its matching Git tag; it is not
  # published to CocoaPods trunk. See the official React Native setup guide.
  s.dependency "RTLSdk", "2.1.2"
end
