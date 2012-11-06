Pod::Spec.new do |s|
  s.name         = 'uploadcare-ios'
  s.version      = '0.0.1'
  s.summary      = 'iOS client library for Uploadcare.'
  s.homepage     = 'https://uploadcare.com'
  s.license      = 'MIT'
  s.authors      = { 'Artyom Loenko' => 'artyom.loenko@mac.com', 'Zoreslav Khimich' => 'zoreslav.khimich@gmail.com' }
  s.source       = { :git => 'https://github.com/uploadcare/uploadcare-ios.git' }
  s.source_files = 'UploadcareKit', 'UploadcareWidget'
  s.resources    = 'UploadcareWidget/resources/*.png'
  s.requires_arc = true
  s.platform = :ios, '5.0'
  s.dependency 'AFNetworking', '1.0'
  s.dependency 'libPusher', '1.4'
  s.dependency 'grabKit', '0.0.1'
end
