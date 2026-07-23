#!/usr/bin/env ruby
require 'xcodeproj'
require 'pathname'

here = Pathname.new(__dir__)          # .../Example
repo = here.parent                    # .../Pala
proj_path = here + 'Example.xcodeproj'

project = Xcodeproj::Project.new(proj_path.to_s)

app    = project.new_target(:application,     'Example',         :ios, '17.0')
uitest = project.new_target(:ui_test_bundle,  'ExampleUITests',  :ios, '17.0')

lib_files    = Dir.glob((repo + 'Sources/Pala/**/*.swift').to_s).sort
app_files    = Dir.glob((here + 'App/*.swift').to_s).sort
uitest_files = Dir.glob((here + 'UITests/*.swift').to_s).sort

app_group  = project.main_group.new_group('App')
lib_group  = project.main_group.new_group('Pala')
test_group = project.main_group.new_group('UITests')

(app_files).each  { |f| app.add_file_references([app_group.new_file(f)]) }
app.add_resources([app_group.new_file((here + 'App/Assets.xcassets').to_s)])
(lib_files).each  { |f| app.add_file_references([lib_group.new_file(f)]) }
(uitest_files).each { |f| uitest.add_file_references([test_group.new_file(f)]) }

common = {
  'SWIFT_VERSION' => '5.0',
  'CODE_SIGNING_ALLOWED' => 'NO',
  'CODE_SIGN_IDENTITY' => '',
  'IPHONEOS_DEPLOYMENT_TARGET' => '17.0',
}

app.build_configurations.each do |c|
  c.build_settings.merge!(common)
  c.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.PalaExample'
  c.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  c.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  c.build_settings['ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS'] = 'NO'
  c.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
end

uitest.build_configurations.each do |c|
  c.build_settings.merge!(common)
  c.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.PalaExampleUITests'
  c.build_settings['TEST_TARGET_NAME'] = 'Example'
end

uitest.add_dependency(app)

project.save

# Paylaşılan şema — xcodebuild test için gerekli.
scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(app, uitest)
scheme.save_as(proj_path.to_s, 'Example', true)

puts "Generated #{proj_path}"
