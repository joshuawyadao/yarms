#!/usr/bin/env ruby
# Run with the xcodeproj gem to add new Swift source files to the checked-in Xcode project.
require 'xcodeproj'

root = File.expand_path('..', __dir__)
path = File.join(root, 'Yarms.xcodeproj')
if File.exist?(File.join(path, 'project.pbxproj'))
  project = Xcodeproj::Project.open(path)
  {
    'YarmsApp' => %w[Yarms],
    'YarmsShare' => %w[YarmsShare],
    'YarmsTests' => %w[YarmsTests],
    'YarmsCore' => %w[Yarms YarmsShare]
  }.each do |folder, target_names|
    group = project.main_group.find_subpath(folder, false)
    Dir.glob(File.join(root, folder, '*.swift')).sort.each do |file|
      reference = group.files.find { |item| item.path == File.basename(file) } ||
                  group.new_file(File.basename(file))
      target_names.each do |name|
        phase = project.targets.find { |target| target.name == name }.source_build_phase
        phase.add_file_reference(reference) unless phase.files_references.include?(reference)
      end
    end
  end
  project.save
  puts "Updated #{path} without replacing existing target identifiers"
  exit
end

project = Xcodeproj::Project.new(path)
project.root_object.attributes['LastUpgradeCheck'] = '2700'
project.root_object.attributes['TargetAttributes'] = {}

app = project.new_target(:application, 'Yarms', :ios, '18.0')
share = project.new_target(:app_extension, 'YarmsShare', :ios, '18.0')
tests = project.new_target(:unit_test_bundle, 'YarmsTests', :ios, '18.0')

def sources(project, target, root, folder)
  group = project.main_group.new_group(folder, folder)
  Dir.glob(File.join(root, folder, '*.swift')).sort.each do |file|
    target.source_build_phase.add_file_reference(group.new_file(File.basename(file)))
  end
end

sources(project, app, root, 'YarmsApp')
sources(project, share, root, 'YarmsShare')
sources(project, tests, root, 'YarmsTests')
core_group = project.main_group.new_group('YarmsCore', 'YarmsCore')
Dir.glob(File.join(root, 'YarmsCore', '*.swift')).sort.each do |file|
  reference = core_group.new_file(File.basename(file))
  [app, share].each { |target| target.source_build_phase.add_file_reference(reference) }
end

assets = project.main_group.new_group('Assets', 'Assets')
app.resources_build_phase.add_file_reference(assets.new_file('Assets.xcassets'))
share_group = project.main_group.find_subpath('YarmsShare', false)
share_group.new_file('Info.plist')
[app, share].each do |target|
  entitlements = project.main_group.find_subpath(target == app ? 'YarmsApp' : 'YarmsShare', false)
  entitlements.new_file('Yarms.entitlements')
end

embed = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
embed.name = 'Embed App Extensions'
embed.dst_subfolder_spec = '13'
embed.add_file_reference(share.product_reference)
app.build_phases << embed
app.add_dependency(share)
tests.add_dependency(app)

project.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
end

[[app, 'com.joshuawyadao.yarms', 'YarmsApp/Yarms.entitlements'],
 [share, 'com.joshuawyadao.yarms.share', 'YarmsShare/Yarms.entitlements'],
 [tests, 'com.joshuawyadao.yarms.tests', nil]].each do |target, bundle_id, entitlements|
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings['SWIFT_VERSION'] = '5.0'
    settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
    settings['TARGETED_DEVICE_FAMILY'] = '1'
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
    settings['MARKETING_VERSION'] = '1.0'
    settings['CURRENT_PROJECT_VERSION'] = '1'
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    settings['CODE_SIGN_ENTITLEMENTS'] = entitlements if entitlements
    settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
    if target == app
      settings['GENERATE_INFOPLIST_FILE'] = 'YES'
      settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'Yarms'
      settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
      settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
    elsif target == share
      settings['GENERATE_INFOPLIST_FILE'] = 'NO'
      settings['INFOPLIST_FILE'] = 'YarmsShare/Info.plist'
      settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'Save to Yarms'
      settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
      settings['SKIP_INSTALL'] = 'YES'
    else
      settings['GENERATE_INFOPLIST_FILE'] = 'YES'
      settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/Yarms.app/Yarms'
      settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
    end
  end
end

project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(tests)
scheme.save_as(path, 'Yarms', true)
puts "Generated #{path}"
