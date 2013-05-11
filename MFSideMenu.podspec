Pod::Spec.new do |s|
  s.name     = 'MFSideMenu'
  s.version  = '1.0.11'
  s.license  = 'BSD'
  s.summary  = 'Facebook-like side menu for iOS.'
  s.homepage = 'https://github.com/doPanic/MFSideMenu'
  s.author   = { 'Michael Frederick' => 'mike@viamike.com', 'Andreas Zeitler' => 'azeitler@dopanic.com' }
  s.source   = { :git => 'https://github.com/doPanic/MFSideMenu.git', :tag => s.version.to_s }
  s.platform = :ios
  s.source_files = 'MFSideMenuDemo/MFSideMenu/*.{h,m}'
  s.subspec 'Assets' do |sp|
    sp.resources = 'MFSideMenuDemo/MFSideMenu/*.png'
  end
  s.frameworks   = 'QuartzCore'
end
