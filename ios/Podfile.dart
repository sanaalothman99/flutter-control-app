# Uncomment this line to define a global platform for your project
platform :ios, '13.0'

use_frameworks! :linkage => :static

target 'Runner' do
use_frameworks!
use_modular_headers!

flutter_application_path = '../'
eval(File.read(File.join(flutter_application_path, '.flutter-plugins-dependencies')))
end