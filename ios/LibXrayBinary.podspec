Pod::Spec.new do |s|
  s.name = 'LibXrayBinary'
  s.version = '1.0.0'
  s.summary = 'Bundled LibXray xcframework for VarPN.'
  s.homepage = 'https://github.com/XTLS/libXray'
  s.license = { :type => 'MIT', :text => 'MIT' }
  s.author = { 'VarPN' => 'team@varpn.cc' }
  s.source = { :path => '.' }
  s.platform = :ios, '15.0'
  s.requires_arc = false
  s.vendored_frameworks = 'Frameworks/LibXray.xcframework'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
end
