require 'xcodeproj'

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |target| target.name == 'Runner' }
raise 'Runner target missing' unless runner

extension = project.targets.find { |target| target.name == 'LiveActivityExtension' }
unless extension
  extension = project.new_target(:app_extension, 'LiveActivityExtension', :ios, '16.1')
  runner.add_dependency(extension)
  embed = runner.build_phases.find do |phase|
    phase.isa == 'PBXCopyFilesBuildPhase' && phase.name == 'Embed App Extensions'
  end
  raise 'Embed App Extensions phase missing' unless embed
  embedded = embed.add_file_reference(extension.product_reference)
  embedded.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

shared = project.main_group.find_subpath('Shared', true)
shared.set_source_tree('<group>')
shared.set_path('Shared')
attributes = shared.files.find { |file| file.path == 'ThinkingActivityAttributes.swift' } ||
  shared.new_file('ThinkingActivityAttributes.swift')

runner_group = project.main_group.find_subpath('Runner', false)
raise 'Runner group missing' unless runner_group
controller = runner_group.files.find { |file| file.path == 'ThinkingLiveActivity.swift' } ||
  runner_group.new_file('ThinkingLiveActivity.swift')

widget_group = project.main_group.find_subpath('LiveActivityExtension', true)
widget_group.set_source_tree('<group>')
widget_group.set_path('LiveActivityExtension')
widget = widget_group.files.find { |file| file.path == 'ThinkingTimerWidget.swift' } ||
  widget_group.new_file('ThinkingTimerWidget.swift')
widget_group.new_file('Info.plist') unless widget_group.files.any? { |file| file.path == 'Info.plist' }

[[runner, attributes], [runner, controller], [extension, attributes], [extension, widget]].each do |target, file|
  target.source_build_phase.add_file_reference(file) unless target.source_build_phase.files_references.include?(file)
end

extension.build_configurations.each do |config|
  config.build_settings.merge!(
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'CODE_SIGN_STYLE' => 'Automatic',
    'CURRENT_PROJECT_VERSION' => '1',
    'DEVELOPMENT_TEAM' => '8QXX3Q6FMG',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'INFOPLIST_FILE' => 'LiveActivityExtension/Info.plist',
    'IPHONEOS_DEPLOYMENT_TARGET' => '16.1',
    'MARKETING_VERSION' => '1.0',
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.example.muzikYok.LiveActivityExtension',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'SDKROOT' => 'iphoneos',
    'SKIP_INSTALL' => 'YES',
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'VALIDATE_PRODUCT' => 'YES'
  )
end

project.save
