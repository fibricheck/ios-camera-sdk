Pod::Spec.new do |s|
    s.name                      = 'FibriCheckCameraSDK'
    s.version                   = '1.0.0' # x-release-please-version
    s.summary                   = 'FibriCheck Camera SDK'
    s.homepage                  = 'https://github.com/fibricheck/'
    s.source                    = { :git => s.homepage + 'ios-camera-sdk.git', :tag => 'v1.0.0'} # x-release-please-version
    s.license                   = 'Proprietary'
    s.authors                   = { 'FibriCheck' => 'development@fibricheck.com' }
    s.source_files              = 'Sources/**/*.{m,h,swift}'
    s.public_header_files       = 'Sources/include/*.h'
    s.exclude_files             = 'examples/**'
    s.swift_versions            = ['5.4', '5.5', '5.6', '5.7']
    s.ios.deployment_target     = '11.0'
  end