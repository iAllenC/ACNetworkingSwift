#
#  Be sure to run `pod spec lint TestKit.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|
    s.name         = 'ACNetworkingSwift'
    s.version      = '0.0.3'
    s.platform     = :ios, '9.0'
    s.ios.deployment_target = '9.0'
    s.summary      = 'A networking tool with memory and disk cache in swift' #简介
    s.homepage     = 'https://github.com/iAllenC/ACNetworkingSwift.git'
    s.license      = { :type => 'MIT', :file => 'LICENSE' }
    s.author       = { 'AllenChen' => 'iallenchen@foxmail.com' }
    s.source       = { :git => 'https://github.com/iAllenC/ACNetworkingSwift.git', :tag => '#{s.version}' }
    s.source_files  = 'ACNetworking/*.swift'
    s.requires_arc = true
    s.swift_version = '4.0'
    s.frameworks = 'CFNetwork'
    s.dependency 'Alamofire', '~> 4.0'

    # s.framework  = 'SomeFramework'
    # s.frameworks = 'SomeFramework', 'AnotherFramework'
    # s.dependency 'JSONKit', '~> 1.4'
end
