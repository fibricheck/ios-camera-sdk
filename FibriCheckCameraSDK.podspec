Pod::Spec.new do |s|
    s.name                      = 'FibriCheckCameraSDK'
    s.version                   = '0.0.1'
    s.summary                   = 'FibriCheck Camera SDK'
    s.homepage                  = 'https://github.com/fibricheck/ios-native-camera-sdk'
    s.source                    = { :git => s.homepage + '.git', :branch => 'dev'}
    s.license                   = 'Proprietary'
    s.authors                   = { 'FibriCheck' => 'development@fibricheck.com' }
    s.source_files              = 'Sources/**/*.{h,c,swift}'
    s.public_header_files       = 'Sources/**/*.h'
    s.swift_versions            = ['5.4', '5.5', '5.6', '5.7']
    s.ios.deployment_target     = '11.0'
  end