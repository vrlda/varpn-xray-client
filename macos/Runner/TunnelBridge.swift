import CryptoKit
import Darwin
import FlutterMacOS
import Foundation

final class TunnelBridge: NSObject {
  private static let channelName = "easyxray/tunnel"
  private static let helperResourceDirectoryName = "UtunHelper"
  private static let helperBinaryName = "varpn-utun-helper"
  private static let helperPlistName = "cc.varpn.easyxray.utun-helper.plist"
  private static let installedHelperBinaryPath =
    "/Library/Application Support/VarPN/bin/varpn-utun-helper"
  private static let installedXrayDirectoryPath =
    "/Library/Application Support/VarPN/xray-core"
  private static let launchDaemonPlistPath =
    "/Library/LaunchDaemons/cc.varpn.easyxray.utun-helper.plist"
  private static let helperLabel = "cc.varpn.easyxray.utun-helper"
  private static let sharedRootPath = "/Users/Shared/VarPN"
  private static let helperSocketPath = "/Users/Shared/VarPN/state/helper.sock"
  private static let xrayResourceDirectoryName = "xray-core"
  private static let helperInstallTimeout: TimeInterval = 8
  private static let helperSocketTimeoutSeconds: Int = 2
  private static let startTunnelTimeoutSeconds: Int = 20

  private static let shared = TunnelBridge()

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler(Self.shared.handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "sharedContainerPath":
      result(Self.sharedRootPath)
    case "installHelper":
      do {
        try installHelper()
        result(nil)
      } catch {
        result(bridgeError(code: "install_helper", error: error))
      }
    case "helperStatus":
      do {
        result(try helperStatus())
      } catch {
        result(bridgeError(code: "helper_status", error: error))
      }
    case "startTunnel":
      guard let arguments = call.arguments as? [String: Any] else {
        result(
          FlutterError(
            code: "start_tunnel_args",
            message: "Missing helper tunnel arguments.",
            details: nil
          )
        )
        return
      }

      do {
        try ensureHelperReachable()
        _ = try sendHelperCommand(
          "startTunnel",
          arguments: arguments,
          timeoutSeconds: Self.startTunnelTimeoutSeconds
        )
        result(nil)
      } catch {
        result(bridgeError(code: "start_tunnel", error: error))
      }
    case "stopTunnel":
      do {
        if helperSocketExists {
          _ = try sendHelperCommand("stopTunnel")
        }
        result(nil)
      } catch {
        result(bridgeError(code: "stop_tunnel", error: error))
      }
    case "repairTunnel":
      do {
        try ensureHelperReachable()
        _ = try sendHelperCommand("repairTunnel")
        result(nil)
      } catch {
        result(bridgeError(code: "repair_tunnel", error: error))
      }
    case "tunnelStatus":
      do {
        let response = try sendHelperCommand("tunnelStatus")
        let map = response as? [String: Any]
        result(map?["status"] as? String ?? "disconnected")
      } catch {
        result("disconnected")
      }
    case "nativeLogEntries":
      do {
        let response = try sendHelperCommand("nativeLogEntries")
        result(response)
      } catch {
        result(bridgeError(code: "native_logs", error: error))
      }
    case "trafficStats":
      do {
        let response = try sendHelperCommand("trafficStats")
        result(response)
      } catch {
        result(bridgeError(code: "traffic_stats", error: error))
      }
    case "tunnelHealth":
      do {
        let response = try sendHelperCommand("tunnelHealth")
        result(response)
      } catch {
        result(bridgeError(code: "tunnel_health", error: error))
      }
    case "clearNativeLogs":
      do {
        if helperSocketExists {
          _ = try sendHelperCommand("clearNativeLogs")
        }
        result(nil)
      } catch {
        result(bridgeError(code: "clear_native_logs", error: error))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private var helperSocketExists: Bool {
    FileManager.default.fileExists(atPath: Self.helperSocketPath)
  }

  private func helperStatus() throws -> [String: Any] {
    let installed = isHelperInstalled
    let needsRefresh = installed ? helperNeedsRefresh : false
    let baseStatus: [String: Any] = [
      "installed": installed,
      "reachable": false,
      "nativeState": "disconnected",
      "helperInstalled": installed,
      "helperReachable": false,
      "needsRefresh": needsRefresh,
      "routesConfigured": false,
      "dnsConfigured": false,
      "utunInterfaceName": NSNull(),
    ]

    guard installed, !needsRefresh, helperSocketExists else {
      return baseStatus
    }

    do {
      let response = try sendHelperCommand("helperStatus")
      guard var status = response as? [String: Any] else {
        return baseStatus
      }
      status["installed"] = installed
      status["reachable"] = true
      status["helperInstalled"] = status["helperInstalled"] ?? installed
      status["helperReachable"] = true
      status["needsRefresh"] = false
      return status
    } catch {
      var status = baseStatus
      status["installed"] = installed
      status["error"] = error.localizedDescription
      return status
    }
  }

  private var isHelperInstalled: Bool {
    let manager = FileManager.default
    return manager.isExecutableFile(atPath: Self.installedHelperBinaryPath) &&
      manager.fileExists(atPath: Self.installedXrayDirectoryPath) &&
      manager.fileExists(atPath: Self.launchDaemonPlistPath)
  }

  private var helperNeedsRefresh: Bool {
    do {
      let resources = try helperResources()
      return try !fileHashMatches(
        installedPath: Self.installedHelperBinaryPath,
        bundledURL: resources.helperBinary
      )
    } catch {
      return false
    }
  }

  private func ensureHelperReachable() throws {
    let status = try helperStatus()
    let installed = status["installed"] as? Bool ?? false
    let reachable = status["reachable"] as? Bool ?? false

    guard installed else {
      throw BridgeError("VarPN helper is not installed yet.")
    }
    guard reachable else {
      throw BridgeError("VarPN helper is installed but not reachable.")
    }
  }

  private func fileHashMatches(installedPath: String, bundledURL: URL) throws -> Bool {
    let installedData = try Data(contentsOf: URL(fileURLWithPath: installedPath))
    let bundledData = try Data(contentsOf: bundledURL)
    return SHA256.hash(data: installedData) == SHA256.hash(data: bundledData)
  }

  private func installHelper() throws {
    let resources = try helperResources()
    let scriptURL = try createInstallScript(resources: resources)
    defer {
      try? FileManager.default.removeItem(at: scriptURL)
    }

    let shellCommand = "/bin/bash \(shellEscape(scriptURL.path))"
    let appleScript = "do shell script \"\(appleScriptEscaped(shellCommand))\" with administrator privileges"

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", appleScript]

    let stderr = Pipe()
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
    let stderrText = String(data: stderrData, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard process.terminationStatus == 0 else {
      throw BridgeError(stderrText.isEmpty ? "Failed to install the VarPN helper." : stderrText)
    }

    try waitForHelperSocket()
  }

  private func helperResources() throws -> (
    helperBinary: URL,
    helperPlist: URL,
    xrayDirectory: URL
  ) {
    guard let resourcesURL = Bundle.main.resourceURL else {
      throw BridgeError("App resources are unavailable.")
    }

    let helperDirectory = resourcesURL
      .appendingPathComponent(Self.helperResourceDirectoryName, isDirectory: true)
    let helperBinary = helperDirectory.appendingPathComponent(Self.helperBinaryName)
    let helperPlist = helperDirectory.appendingPathComponent(Self.helperPlistName)
    let xrayDirectory = resourcesURL.appendingPathComponent(Self.xrayResourceDirectoryName, isDirectory: true)

    guard FileManager.default.isExecutableFile(atPath: helperBinary.path) else {
      throw BridgeError("Bundled utun helper is missing from the app resources.")
    }
    guard FileManager.default.fileExists(atPath: helperPlist.path) else {
      throw BridgeError("Bundled helper plist is missing from the app resources.")
    }
    guard FileManager.default.fileExists(atPath: xrayDirectory.path) else {
      throw BridgeError("Bundled Xray runtime is missing from the app resources.")
    }

    return (helperBinary, helperPlist, xrayDirectory)
  }

  private func createInstallScript(
    resources: (
      helperBinary: URL,
      helperPlist: URL,
      xrayDirectory: URL
    )
  ) throws -> URL {
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("varpn-install-helper-\(UUID().uuidString).sh")

    let script = """
    #!/bin/bash
    set -euo pipefail

    INSTALL_ROOT='/Library/Application Support/VarPN'
    BIN_DIR="$INSTALL_ROOT/bin"
    XRAY_DIR="$INSTALL_ROOT/xray-core"
    PLIST_DST='/Library/LaunchDaemons/\(Self.helperPlistName)'
    SHARED_ROOT='\(Self.sharedRootPath)'
    STATE_DIR="$SHARED_ROOT/state"
    CONFIG_DIR="$SHARED_ROOT/configs"
    GEODATA_DIR="$SHARED_ROOT/geodata"

    /bin/mkdir -p "$BIN_DIR" "$STATE_DIR" "$CONFIG_DIR" "$GEODATA_DIR"
    /bin/cp \(shellEscape(resources.helperBinary.path)) "$BIN_DIR/\(Self.helperBinaryName)"
    /bin/chmod 755 "$BIN_DIR/\(Self.helperBinaryName)"

    /bin/rm -rf "$XRAY_DIR"
    /bin/cp -R \(shellEscape(resources.xrayDirectory.path)) "$XRAY_DIR"
    /bin/chmod 755 "$XRAY_DIR/xray"

    /bin/cp \(shellEscape(resources.helperPlist.path)) "$PLIST_DST"
    /usr/sbin/chown root:wheel "$PLIST_DST"
    /bin/chmod 644 "$PLIST_DST"
    /usr/sbin/chown -R root:wheel "$INSTALL_ROOT"

    /bin/chmod 755 "$SHARED_ROOT"
    /bin/chmod 777 "$STATE_DIR" "$CONFIG_DIR" "$GEODATA_DIR"
    /usr/bin/touch "$STATE_DIR/packet-tunnel.log"
    /bin/chmod 666 "$STATE_DIR/packet-tunnel.log" || true

    /bin/launchctl bootout system "$PLIST_DST" >/dev/null 2>&1 || /bin/launchctl bootout system/\(Self.helperLabel) >/dev/null 2>&1 || true
    /bin/launchctl bootstrap system "$PLIST_DST"
    /bin/launchctl enable system/\(Self.helperLabel) >/dev/null 2>&1 || true
    /bin/launchctl kickstart -k system/\(Self.helperLabel)
    """

    try script.write(to: tempURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700],
      ofItemAtPath: tempURL.path
    )
    return tempURL
  }

  private func waitForHelperSocket() throws {
    let deadline = Date().addingTimeInterval(Self.helperInstallTimeout)
    while Date() < deadline {
      if helperSocketExists {
        do {
          _ = try sendHelperCommand("helperStatus")
          return
        } catch {
          // Keep waiting while launchd starts the daemon.
        }
      }
      Thread.sleep(forTimeInterval: 0.35)
    }

    throw BridgeError("VarPN helper did not become ready in time.")
  }

  private func sendHelperCommand(
    _ command: String,
    arguments: [String: Any] = [:],
    timeoutSeconds: Int = TunnelBridge.helperSocketTimeoutSeconds
  ) throws -> Any {
    let socketFD = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    guard socketFD >= 0 else {
      throw BridgeError("Failed to create the helper control socket.")
    }
    defer {
      Darwin.close(socketFD)
    }

    var timeout = timeval(
      tv_sec: timeoutSeconds,
      tv_usec: 0
    )
    withUnsafePointer(to: &timeout) { pointer in
      _ = Darwin.setsockopt(
        socketFD,
        SOL_SOCKET,
        SO_RCVTIMEO,
        pointer,
        socklen_t(MemoryLayout<timeval>.stride)
      )
      _ = Darwin.setsockopt(
        socketFD,
        SOL_SOCKET,
        SO_SNDTIMEO,
        pointer,
        socklen_t(MemoryLayout<timeval>.stride)
      )
    }

    var (address, addressLength) = try unixSocketAddress(for: Self.helperSocketPath)

    let connectResult = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
        Darwin.connect(socketFD, sockaddrPointer, addressLength)
      }
    }

    guard connectResult == 0 else {
      throw BridgeError("Could not reach the VarPN helper daemon.")
    }

    let payload: [String: Any] = [
      "command": command,
      "arguments": arguments,
    ]
    let requestData = try JSONSerialization.data(withJSONObject: payload)
    let writeResult = requestData.withUnsafeBytes { rawBuffer in
      Darwin.write(socketFD, rawBuffer.baseAddress, requestData.count)
    }
    guard writeResult >= 0 else {
      throw BridgeError("Failed to send the helper request.")
    }
    Darwin.shutdown(socketFD, SHUT_WR)

    var response = Data()
    var buffer = [UInt8](repeating: 0, count: 8192)
    while true {
      let bytesRead = Darwin.read(socketFD, &buffer, buffer.count)
      if bytesRead < 0 {
        if errno == EAGAIN || errno == EWOULDBLOCK {
          throw BridgeError("VarPN helper did not respond in time.")
        }
        throw BridgeError("Failed to read the helper response.")
      }
      if bytesRead == 0 {
        break
      }
      response.append(buffer, count: bytesRead)
    }

    guard !response.isEmpty else {
      throw BridgeError("The helper returned an empty response.")
    }

    guard let object = try JSONSerialization.jsonObject(with: response) as? [String: Any] else {
      throw BridgeError("The helper response was not valid JSON.")
    }

    let ok = object["ok"] as? Bool ?? false
    if ok {
      return object["result"] as Any
    }

    let errorMessage = object["error"] as? String ?? "Unknown helper failure."
    throw BridgeError(errorMessage)
  }

  private func shellEscape(_ path: String) -> String {
    "'\(path.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
  }

  private func unixSocketAddress(for path: String) throws -> (sockaddr_un, socklen_t) {
    var address = sockaddr_un()
    let pathBytes = path.utf8CString
    let maxLength = MemoryLayout.size(ofValue: address.sun_path)
    guard pathBytes.count <= maxLength else {
      throw BridgeError("The helper socket path is too long.")
    }

    #if os(macOS)
      let sunPathOffset = MemoryLayout<sockaddr_un>.offset(of: \.sun_path) ?? 2
      let addressLength = socklen_t(sunPathOffset + pathBytes.count)
      address.sun_len = UInt8(addressLength)
    #else
      let addressLength = socklen_t(MemoryLayout<sockaddr_un>.stride)
    #endif
    address.sun_family = sa_family_t(AF_UNIX)

    withUnsafeMutableBytes(of: &address.sun_path) { buffer in
      buffer.initializeMemory(as: CChar.self, repeating: 0)
      buffer.copyBytes(from: pathBytes.map(UInt8.init(bitPattern:)))
    }

    return (address, addressLength)
  }

  private func appleScriptEscaped(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }

  private func bridgeError(code: String, error: Error) -> FlutterError {
    FlutterError(code: code, message: error.localizedDescription, details: nil)
  }
}

private struct BridgeError: LocalizedError {
  let description: String

  init(_ description: String) {
    self.description = description
  }

  var errorDescription: String? {
    description
  }
}
