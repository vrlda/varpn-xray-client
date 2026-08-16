#!/usr/bin/env ruby

require 'rubygems'
gem 'xcodeproj'
require 'xcodeproj'

PROJECT_PATH = File.expand_path('../macos/Runner.xcodeproj', __dir__)
TUN_PACKAGE_URL = 'https://github.com/EbrahimTahernejad/Tun2SocksKit.git'
TUN_PACKAGE_VERSION = '5.14.4'
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
  phase = target.source_build_phase
  existing = phase.files.find { |build_file| build_file.file_ref == file_ref }
  return existing if existing

  phase.add_file_reference(file_ref, true)
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

def ensure_remote_package(project, url, version)
  existing = project.root_object.package_references.find do |reference|
    reference.isa == 'XCRemoteSwiftPackageReference' &&
      reference.repositoryURL == url
  end
  return existing if existing

  reference = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  reference.repositoryURL = url
  reference.requirement = {
    'kind' => 'upToNextMajorVersion',
    'minimumVersion' => version,
  }
  project.root_object.package_references << reference
  reference
end

def ensure_package_product(project, target, package_reference, product_name)
  existing = target.package_product_dependencies.find do |dependency|
    dependency.product_name == product_name
  end
  return existing if existing

  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.package = package_reference
  dependency.product_name = product_name
  target.package_product_dependencies << dependency
  dependency
end

def ensure_package_framework_link(project, target, product_dependency)
  existing = target.frameworks_build_phase.files.find do |build_file|
    build_file.product_ref == product_dependency
  end
  return existing if existing

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product_dependency
  target.frameworks_build_phase.files << build_file
  build_file
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

def ensure_shell_script_phase(target, name, script)
  existing = target.shell_script_build_phases.find { |phase| phase.name == name }
  return existing if existing

  phase = target.new_shell_script_build_phase(name)
  phase.shell_script = script
  phase
end

main_group = project.main_group
runner_group = ensure_group(main_group, 'Runner', 'Runner')
packet_tunnel_group = ensure_group(main_group, 'PacketTunnel', 'PacketTunnel')

tunnel_bridge_ref = ensure_file(runner_group, 'TunnelBridge.swift')
ensure_source_build(runner_target, tunnel_bridge_ref)

packet_tunnel_provider_ref = ensure_file(packet_tunnel_group, 'PacketTunnelProvider.swift')
ensure_file(packet_tunnel_group, 'Info.plist')
ensure_file(packet_tunnel_group, 'PacketTunnel.entitlements')

packet_tunnel_target = project.targets.find { |target| target.name == PACKET_TUNNEL_TARGET }
unless packet_tunnel_target
  packet_tunnel_target = project.new_target(
    :app_extension,
    PACKET_TUNNEL_TARGET,
    :osx,
    '14.0',
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
ensure_framework(project, packet_tunnel_target, 'System/Library/Frameworks/Network.framework')

package_ref = ensure_remote_package(project, TUN_PACKAGE_URL, TUN_PACKAGE_VERSION)
product_dependency = ensure_package_product(project, packet_tunnel_target, package_ref, 'Tun2SocksKit')
ensure_package_framework_link(project, packet_tunnel_target, product_dependency)

xray_copy_script = <<~SCRIPT
  set -e
  SOURCE_DIR="${PROJECT_DIR}/../xray-core"
  TARGET_DIR="${TARGET_BUILD_DIR}/${WRAPPER_NAME}/Contents/Resources/xray-core"
  rm -rf "${TARGET_DIR}"
  mkdir -p "${TARGET_DIR}"
  rsync -a --delete "${SOURCE_DIR}/" "${TARGET_DIR}/"
  chmod +x "${TARGET_DIR}/xray"
SCRIPT

ensure_shell_script_phase(packet_tunnel_target, 'Bundle Xray Core', xray_copy_script)

packet_tunnel_target.build_configurations.each do |configuration|
  settings = configuration.build_settings
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['INFOPLIST_FILE'] = 'PacketTunnel/Info.plist'
  settings['CODE_SIGN_ENTITLEMENTS'] = 'PacketTunnel/PacketTunnel.entitlements'
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = PACKET_TUNNEL_BUNDLE_ID
  settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  settings['SWIFT_VERSION'] = '5.0'
  settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  settings['SKIP_INSTALL'] = 'YES'
  settings['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)',
    '@executable_path/../Frameworks',
    '@executable_path/../../Frameworks',
  ]
  settings['FRAMEWORK_SEARCH_PATHS'] = ''
  settings['HEADER_SEARCH_PATHS'] = ''
  settings['LIBRARY_SEARCH_PATHS'] = ''
  settings['OTHER_LDFLAGS'] = ''
  settings['OTHER_SWIFT_FLAGS'] = ''
  settings['GCC_PREPROCESSOR_DEFINITIONS'] = ''
end

project.sort
project.save
