import Flutter
import Foundation
import LibXray
import NetworkExtension

final class TunnelBridge: NSObject {
  private static let channelName = "easyxray/tunnel"
  private static let tunnelDirectoryName = "PacketTunnel"
  private static let nativeLogFileName = "packet-tunnel.log"
  private static let trafficStatsFileName = "traffic-stats.json"
  private static let tunnelHealthFileName = "tunnel-health.json"
  private static let localizedDescription = "VarPN"

  private static let shared = TunnelBridge()

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler(Self.shared.handle)
  }

  private var providerBundleIdentifier: String {
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "cc.varpn.easyxray"
    return "\(bundleIdentifier).PacketTunnelProvider"
  }

  private var appGroupIdentifier: String {
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "cc.varpn.easyxray"
    return "group.\(bundleIdentifier)"
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "sharedContainerPath":
      do {
        result(try sharedContainerURL().path)
      } catch {
        result(
          FlutterError(
            code: "shared_container",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    case "startTunnel":
      guard let arguments = call.arguments as? [String: Any] else {
        result(
          FlutterError(
            code: "start_tunnel_args",
            message: "Missing tunnel arguments.",
            details: nil
          )
        )
        return
      }
      startTunnel(arguments: arguments, result: result)
    case "stopTunnel":
      stopTunnel(result: result)
    case "tunnelStatus":
      currentStatus(result: result)
    case "nativeLogEntries":
      do {
        result(try nativeLogEntries())
      } catch {
        result(
          FlutterError(
            code: "native_logs",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    case "trafficStats":
      do {
        result(try jsonSnapshot(fileName: Self.trafficStatsFileName))
      } catch {
        result(
          FlutterError(
            code: "traffic_stats",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    case "tunnelHealth":
      do {
        result(try jsonSnapshot(fileName: Self.tunnelHealthFileName))
      } catch {
        result(
          FlutterError(
            code: "tunnel_health",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    case "clearNativeLogs":
      do {
        try clearNativeLogs()
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "clear_native_logs",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    case "measureLatency":
      guard let arguments = call.arguments as? [String: Any] else {
        result(
          FlutterError(
            code: "measure_latency_args",
            message: "Missing latency measurement arguments.",
            details: nil
          )
        )
        return
      }

      do {
        result(try measureLatency(arguments: arguments))
      } catch {
        result(
          FlutterError(
            code: "measure_latency",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startTunnel(arguments: [String: Any], result: @escaping FlutterResult) {
    guard let configPath = arguments["configPath"] as? String, !configPath.isEmpty else {
      result(
        FlutterError(
          code: "config_path",
          message: "Missing Xray config path.",
          details: nil
        )
      )
      return
    }

    guard let assetDirectory = arguments["assetDirectory"] as? String, !assetDirectory.isEmpty else {
      result(
        FlutterError(
          code: "asset_directory",
          message: "Missing asset directory.",
          details: nil
        )
      )
      return
    }

    let dnsServers = arguments["dnsServers"] as? [String] ?? ["1.1.1.1", "8.8.8.8"]
    let mtu = readInt(arguments["mtu"]) ?? 1500
    let enableIpv6 = readBool(arguments["enableIpv6"]) ?? true
    let bypassLocalNetworks = readBool(arguments["bypassLocalNetworks"]) ?? true
    let strictRouting = readBool(arguments["strictRouting"]) ?? true
    let reconnectReason = arguments["reconnectReason"] as? String
    let activeTransport = arguments["activeTransport"] as? String

    prepareManager(
      configPath: configPath,
      assetDirectory: assetDirectory,
      dnsServers: dnsServers,
      mtu: mtu,
      enableIpv6: enableIpv6,
      bypassLocalNetworks: bypassLocalNetworks,
      strictRouting: strictRouting,
      activeTransport: activeTransport
    ) { preparation in
      switch preparation {
      case let .failure(error):
        result(
          FlutterError(
            code: "prepare_manager",
            message: error.localizedDescription,
            details: nil
          )
        )
      case let .success(manager):
        self.stopIfNeeded(manager: manager) { stopResult in
          switch stopResult {
          case let .failure(error):
            result(
              FlutterError(
                code: "stop_existing_tunnel",
                message: error.localizedDescription,
                details: nil
              )
            )
          case .success:
            guard let session = manager.connection as? NETunnelProviderSession else {
              result(
                FlutterError(
                  code: "tunnel_session",
                  message: "Tunnel provider session is unavailable.",
                  details: nil
                )
              )
              return
            }

            do {
              var options: [String: NSObject] = [
                "configPath": configPath as NSString,
                "assetDirectory": assetDirectory as NSString,
                "dnsServers": dnsServers as NSArray,
                "mtu": NSNumber(value: mtu),
                "enableIpv6": NSNumber(value: enableIpv6),
                "bypassLocalNetworks": NSNumber(value: bypassLocalNetworks),
                "strictRouting": NSNumber(value: strictRouting),
              ]
              if let reconnectReason, !reconnectReason.isEmpty {
                options["reconnectReason"] = reconnectReason as NSString
              }
              if let activeTransport, !activeTransport.isEmpty {
                options["activeTransport"] = activeTransport as NSString
              }
              try session.startVPNTunnel(options: options)
            } catch {
              result(
                FlutterError(
                  code: "start_vpn_tunnel",
                  message: error.localizedDescription,
                  details: nil
                )
              )
              return
            }

            self.waitForStatus(manager: manager, expected: .connected, timeout: 20) { waitResult in
              switch waitResult {
              case let .failure(error):
                result(
                  FlutterError(
                    code: "wait_connected",
                    message: error.localizedDescription,
                    details: self.statusName(for: manager.connection.status)
                  )
                )
              case .success:
                result(nil)
              }
            }
          }
        }
      }
    }
  }

  private func stopTunnel(result: @escaping FlutterResult) {
    loadManager { loadResult in
      switch loadResult {
      case let .failure(error):
        result(
          FlutterError(
            code: "load_manager",
            message: error.localizedDescription,
            details: nil
          )
        )
      case let .success(manager):
        self.stopIfNeeded(manager: manager) { stopResult in
          switch stopResult {
          case let .failure(error):
            result(
              FlutterError(
                code: "stop_tunnel",
                message: error.localizedDescription,
                details: nil
              )
            )
          case .success:
            result(nil)
          }
        }
      }
    }
  }

  private func currentStatus(result: @escaping FlutterResult) {
    loadManager { loadResult in
      switch loadResult {
      case let .failure(error):
        result(
          FlutterError(
            code: "status_manager",
            message: error.localizedDescription,
            details: nil
          )
        )
      case let .success(manager):
        result(self.statusName(for: manager.connection.status))
      }
    }
  }

  private func prepareManager(
    configPath: String,
    assetDirectory: String,
    dnsServers: [String],
    mtu: Int,
    enableIpv6: Bool,
    bypassLocalNetworks: Bool,
    strictRouting: Bool,
    activeTransport: String?,
    completion: @escaping (Result<NETunnelProviderManager, Error>) -> Void
  ) {
    loadManager { loadResult in
      switch loadResult {
      case let .failure(error):
        completion(.failure(error))
      case let .success(manager):
        let providerProtocol = NETunnelProviderProtocol()
        providerProtocol.providerBundleIdentifier = self.providerBundleIdentifier
        providerProtocol.serverAddress = Self.localizedDescription
        providerProtocol.disconnectOnSleep = false

        var providerConfiguration: [String: Any] = [
          "appGroupIdentifier": self.appGroupIdentifier,
          "nativeLogFileName": Self.nativeLogFileName,
          "configPath": configPath,
          "assetDirectory": assetDirectory,
          "dnsServers": dnsServers,
          "mtu": mtu,
          "enableIpv6": enableIpv6,
          "bypassLocalNetworks": bypassLocalNetworks,
          "strictRouting": strictRouting,
        ]
        if let activeTransport, !activeTransport.isEmpty {
          providerConfiguration["activeTransport"] = activeTransport
        }
        providerProtocol.providerConfiguration = providerConfiguration

        manager.protocolConfiguration = providerProtocol
        manager.localizedDescription = Self.localizedDescription
        manager.isEnabled = true

        manager.saveToPreferences { error in
          if let error {
            completion(.failure(error))
            return
          }

          manager.loadFromPreferences { loadError in
            if let loadError {
              completion(.failure(loadError))
              return
            }
            completion(.success(manager))
          }
        }
      }
    }
  }

  private func loadManager(
    completion: @escaping (Result<NETunnelProviderManager, Error>) -> Void
  ) {
    NETunnelProviderManager.loadAllFromPreferences { managers, error in
      if let error {
        completion(.failure(error))
        return
      }

      let existingManager = managers?.first {
        guard let providerProtocol = $0.protocolConfiguration as? NETunnelProviderProtocol else {
          return false
        }
        return providerProtocol.providerBundleIdentifier == self.providerBundleIdentifier
      }

      completion(.success(existingManager ?? NETunnelProviderManager()))
    }
  }

  private func stopIfNeeded(
    manager: NETunnelProviderManager,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let status = manager.connection.status
    if status == .disconnected || status == .invalid {
      completion(.success(()))
      return
    }

    manager.connection.stopVPNTunnel()
    waitForStatus(manager: manager, expected: .disconnected, timeout: 12, completion: completion)
  }

  private func waitForStatus(
    manager: NETunnelProviderManager,
    expected: NEVPNStatus,
    timeout: TimeInterval,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let deadline = Date().addingTimeInterval(timeout)

    func poll() {
      let current = manager.connection.status
      if current == expected {
        completion(.success(()))
        return
      }

      if Date() >= deadline {
        completion(
          .failure(
            TunnelBridgeError(
              description: "Timed out waiting for tunnel status \(statusName(for: expected)). Current status: \(statusName(for: current))."
            )
          )
        )
        return
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
        poll()
      }
    }

    poll()
  }

  private func measureLatency(arguments: [String: Any]) throws -> Int {
    guard let configPath = arguments["configPath"] as? String, !configPath.isEmpty else {
      throw TunnelBridgeError(description: "Missing latency config path.")
    }
    guard let assetDirectory = arguments["assetDirectory"] as? String, !assetDirectory.isEmpty else {
      throw TunnelBridgeError(description: "Missing latency asset directory.")
    }
    guard let url = arguments["url"] as? String, !url.isEmpty else {
      throw TunnelBridgeError(description: "Missing latency URL.")
    }

    let timeoutSeconds = readInt(arguments["timeoutSeconds"]) ?? 5
    let localPort = readInt(arguments["localPort"]) ?? 10808
    let request: [String: Any] = [
      "datDir": assetDirectory,
      "configPath": configPath,
      "timeout": timeoutSeconds,
      "url": url,
      "proxy": "socks5://127.0.0.1:\(localPort)",
    ]

    let encodedRequest = try encodeBase64JSON(request)
    let response = try decodeLibXrayResponse(LibXrayPing(encodedRequest))
    return readInt(response["data"]) ?? 9999
  }

  private func nativeLogEntries() throws -> [[String: Any]] {
    let logFileURL = try nativeLogFileURL()
    guard FileManager.default.fileExists(atPath: logFileURL.path) else {
      return []
    }

    let content = try String(contentsOf: logFileURL, encoding: .utf8)
    var entries: [[String: Any]] = []
    for rawLine in content.split(separator: "\n") {
      guard let data = rawLine.data(using: .utf8) else {
        continue
      }
      guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        continue
      }
      entries.append(json)
    }
    return entries
  }

  private func clearNativeLogs() throws {
    let logFileURL = try nativeLogFileURL()
    if FileManager.default.fileExists(atPath: logFileURL.path) {
      try FileManager.default.removeItem(at: logFileURL)
    }
  }

  private func jsonSnapshot(fileName: String) throws -> [String: Any] {
    let snapshotURL = try tunnelDirectoryURL().appendingPathComponent(fileName)
    guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
      return [:]
    }

    let data = try Data(contentsOf: snapshotURL)
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return [:]
    }

    return json
  }

  private func sharedContainerURL() throws -> URL {
    guard let url = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    ) else {
      throw TunnelBridgeError(
        description: "App Group container is unavailable for \(appGroupIdentifier)."
      )
    }
    return url
  }

  private func tunnelDirectoryURL() throws -> URL {
    let directory = try sharedContainerURL()
      .appendingPathComponent(Self.tunnelDirectoryName, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func nativeLogFileURL() throws -> URL {
    try tunnelDirectoryURL().appendingPathComponent(Self.nativeLogFileName)
  }

  private func statusName(for status: NEVPNStatus) -> String {
    switch status {
    case .invalid:
      return "invalid"
    case .disconnected:
      return "disconnected"
    case .connecting:
      return "connecting"
    case .connected:
      return "connected"
    case .reasserting:
      return "reasserting"
    case .disconnecting:
      return "disconnecting"
    @unknown default:
      return "unknown"
    }
  }

  private func encodeBase64JSON(_ object: [String: Any]) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: object)
    return data.base64EncodedString()
  }

  private func decodeLibXrayResponse(_ encoded: String) throws -> [String: Any] {
    guard let data = Data(base64Encoded: encoded) else {
      throw TunnelBridgeError(description: "libXray returned invalid base64 data.")
    }

    guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw TunnelBridgeError(description: "libXray returned invalid JSON data.")
    }

    if (response["success"] as? Bool) == false {
      throw TunnelBridgeError(
        description: response["error"] as? String ?? "Unknown libXray error."
      )
    }

    return response
  }

  private func readInt(_ value: Any?) -> Int? {
    switch value {
    case let number as NSNumber:
      return number.intValue
    case let string as String:
      return Int(string)
    default:
      return nil
    }
  }

  private func readBool(_ value: Any?) -> Bool? {
    switch value {
    case let value as Bool:
      return value
    case let number as NSNumber:
      return number.boolValue
    case let string as String:
      switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
      case "true", "1":
        return true
      case "false", "0":
        return false
      default:
        return nil
      }
    default:
      return nil
    }
  }
}

private struct TunnelBridgeError: LocalizedError {
  let description: String

  var errorDescription: String? {
    description
  }
}
