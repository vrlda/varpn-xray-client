#!/usr/bin/env ruby

require 'rubygems'
gem 'xcodeproj'
require 'xcodeproj'

PROJECT_PATH = File.expand_path('../ios/Runner.xcodeproj', __dir__)
PACKET_TUNNEL_TARGET = 'PacketTunnel'
PACKET_TUNNEL_BUNDLE_ID = 'cc.varpn.easyxray.PacketTunnelProvider'

project = Xcodeproj::Project.open(PROJECT_PATH)
runner_target = project.targets.find { |target| target.name == 'Runner' }
abort('Runner target not found.') unless runner_target

def ensure_group(parent, name, path = nil)
  parent.children.find { |child| child.isa == 'PBXGroup' && child.path == (path || name) } ||
    parent.new_group(name, path)
end

def ensure_file(group, path)
  group.files.find { |file| file.path == path } || group.new_file(path)
end

def ensure_source_build(target, file_ref)
  existing = target.source_build_phase.files.find { |build_file| build_file.file_ref == file_ref }
  return existing if existing

  target.source_build_phase.add_file_reference(file_ref, true)
end

def ensure_framework(project, target, framework_path)
  file_ref = project.frameworks_group.files.find do |file|
    file.path == framework_path && file.source_tree == 'SDKROOT'
  end
  file_ref ||= project.frameworks_group.new_file(framework_path, 'SDKROOT')

  existing = target.frameworks_build_phase.files.find do |build_file|
    build_file.file_ref == file_ref
  end
  return existing if existing

  target.frameworks_build_phase.add_file_reference(file_ref, true)
end

def ensure_copy_phase(target, name, dst_subfolder_spec)
  existing = target.copy_files_build_phases.find { |phase| phase.name == name }
  return existing if existing

  phase = target.new_copy_files_build_phase(name)
  phase.dst_subfolder_spec = dst_subfolder_spec
  phase
end

def ensure_embedded_product(project, phase, product_ref)
  existing = phase.files.find { |build_file| build_file.file_ref == product_ref }
  return existing if existing

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.file_ref = product_ref
  build_file.settings = { 'ATTRIBUTES' => %w(CodeSignOnCopy RemoveHeadersOnCopy) }
  phase.files << build_file
  build_file
end

main_group = project.main_group
runner_group = ensure_group(main_group, 'Runner', 'Runner')
packet_tunnel_group = ensure_group(main_group, 'PacketTunnel', 'PacketTunnel')

tunnel_bridge_ref = ensure_file(runner_group, 'TunnelBridge.swift')
ensure_source_build(runner_target, tunnel_bridge_ref)
ensure_file(runner_group, 'Runner.entitlements')

packet_tunnel_provider_ref = ensure_file(packet_tunnel_group, 'PacketTunnelProvider.swift')
ensure_file(packet_tunnel_group, 'Info.plist')
ensure_file(packet_tunnel_group, 'PacketTunnel.entitlements')

packet_tunnel_target = project.targets.find { |target| target.name == PACKET_TUNNEL_TARGET }
unless packet_tunnel_target
  packet_tunnel_target = project.new_target(
    :app_extension,
    PACKET_TUNNEL_TARGET,
    :ios,
    '15.0',
    project.products_group,
    :swift
  )
end

ensure_source_build(packet_tunnel_target, packet_tunnel_provider_ref)

runner_target.add_dependency(packet_tunnel_target) unless runner_target.dependencies.any? do |dependency|
  dependency.target == packet_tunnel_target
end

embed_phase = ensure_copy_phase(runner_target, 'Embed App Extensions', '13')
ensure_embedded_product(project, embed_phase, packet_tunnel_target.product_reference)

ensure_framework(project, runner_target, 'System/Library/Frameworks/NetworkExtension.framework')
ensure_framework(project, packet_tunnel_target, 'System/Library/Frameworks/NetworkExtension.framework')

runner_target.build_configurations.each do |configuration|
  settings = configuration.build_settings
  settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

packet_tunnel_target.build_configurations.each do |configuration|
  settings = configuration.build_settings
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['INFOPLIST_FILE'] = 'PacketTunnel/Info.plist'
  settings['CODE_SIGN_ENTITLEMENTS'] = 'PacketTunnel/PacketTunnel.entitlements'
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = PACKET_TUNNEL_BUNDLE_ID
  settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  settings['SWIFT_VERSION'] = '5.0'
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  settings['SKIP_INSTALL'] = 'YES'
  settings['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)',
    '@executable_path/Frameworks',
    '@executable_path/../../Frameworks',
  ]
end

project.sort
project.save
