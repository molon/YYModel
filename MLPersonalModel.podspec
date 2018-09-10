Pod::Spec.new do |s|
  s.name         = 'MLPersonalModel'
  s.summary      = 'Personal Pod, Improved Fork of YYModel, Please dont use it.'
  s.version      = '12.2.1'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.authors      = { 'ibireme' => 'ibireme@gmail.com' }
  s.social_media_url = 'http://blog.ibireme.com'
  s.homepage     = 'https://github.com/molon/YYModel'

  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.7'
  s.watchos.deployment_target = '2.0'
  s.tvos.deployment_target = '9.0'

  s.source       = { :git => 'https://github.com/molon/YYModel.git', :tag => s.version.to_s }
  
  s.requires_arc = true
  s.source_files = 'XXModel/*.{h,m}'
  s.public_header_files = 'XXModel/*.{h}'
  
  s.frameworks = 'Foundation', 'CoreFoundation'

end
