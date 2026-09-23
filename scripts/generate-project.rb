#!/usr/bin/env ruby
# Run with the xcodeproj gem to add new Swift source files to the checked-in Xcode project.
require 'xcodeproj'

root = File.expand_path('..', __dir__)
path = File.join(root, 'Yarms.xcodeproj')

def set_scheme_executable(scheme, app)
  runnable = Xcodeproj::XCScheme::BuildableProductRunnable.new(app)
  scheme.launch_action.buildable_product_runnable = runnable
  scheme.profile_action.buildable_product_runnable = Xcodeproj::XCScheme::BuildableProductRunnable.new(app)
end

if File.exist?(File.join(path, 'project.pbxproj'))
  project = Xcodeproj::Project.open(path)
  app = project.targets.find { |target| target.name == 'Yarms' }
  share = project.targets.find { |target| target.name == 'YarmsShare' }
  if share
    app.dependencies.select { |dependency| dependency.target == share }.each do |dependency|
      dependency.target_proxy&.remove_from_project
      dependency.remove_from_project
    end
    app.copy_files_build_phases.select { |phase| phase.name == 'Embed App Extensions' }.each do |phase|
      phase.clear
      phase.remove_from_project
    end
    share.build_phases.each do |phase|
      phase.clear
      phase.remove_from_project
    end
    share.build_configuration_list.build_configurations.each(&:remove_from_project)
    share.build_configuration_list.remove_from_project
    share.product_reference.remove_from_project
    share.remove_from_project
    share_group = project.main_group.find_subpath('YarmsShare', false)
    share_group&.clear
    share_group&.remove_from_project
  end
  app_group = project.main_group.find_subpath('YarmsApp', false)
  app_group.files.select { |file| file.path == 'Yarms.entitlements' }.each(&:remove_from_project)
  app.build_configurations.each do |config|
    config.build_settings.delete('CODE_SIGN_ENTITLEMENTS')
  end
  {
    'YarmsApp' => %w[Yarms],
    'YarmsTests' => %w[YarmsTests],
    'YarmsCore' => %w[Yarms]
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
  scheme_path = File.join(path, 'xcshareddata', 'xcschemes', 'Yarms.xcscheme')
  scheme = Xcodeproj::XCScheme.new(scheme_path)
  set_scheme_executable(scheme, project.targets.find { |target| target.name == 'Yarms' })
  scheme.save_as(path, 'Yarms', true)
  puts "Updated #{path} without replacing existing target identifiers"
  exit
end

project = Xcodeproj::Project.new(path)
project.root_object.attributes['LastUpgradeCheck'] = '2700'
project.root_object.attributes['TargetAttributes'] = {}

app = project.new_target(:application, 'Yarms', :ios, '18.0')
tests = project.new_target(:unit_test_bundle, 'YarmsTests', :ios, '18.0')

def sources(project, target, root, folder)
  group = project.main_group.new_group(folder, folder)
  Dir.glob(File.join(root, folder, '*.swift')).sort.each do |file|
    target.source_build_phase.add_file_reference(group.new_file(File.basename(file)))
  end
end

sources(project, app, root, 'YarmsApp')
sources(project, tests, root, 'YarmsTests')
core_group = project.main_group.new_group('YarmsCore', 'YarmsCore')
Dir.glob(File.join(root, 'YarmsCore', '*.swift')).sort.each do |file|
  reference = core_group.new_file(File.basename(file))
  app.source_build_phase.add_file_reference(reference)
end

assets = project.main_group.new_group('Assets', 'Assets')
app.resources_build_phase.add_file_reference(assets.new_file('Assets.xcassets'))
tests.add_dependency(app)

project.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
end

[[app, 'com.joshuawyadao.yarms'],
 [tests, 'com.joshuawyadao.yarms.tests']].each do |target, bundle_id|
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings['SWIFT_VERSION'] = '5.0'
    settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
    settings['TARGETED_DEVICE_FAMILY'] = '1'
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
    settings['MARKETING_VERSION'] = '1.0'
    settings['CURRENT_PROJECT_VERSION'] = '1'
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
    if target == app
      settings['GENERATE_INFOPLIST_FILE'] = 'YES'
      settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'Yarms'
      settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
      settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
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
set_scheme_executable(scheme, app)
scheme.save_as(path, 'Yarms', true)
puts "Generated #{path}"
