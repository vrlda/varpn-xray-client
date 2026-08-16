import Darwin
import Foundation
import LibXray
import Network
import NetworkExtension
import Tun2SocksKit

final class PacketTunnelProvider: NEPacketTunnelProvider {
  private let localSocksHost = "127.0.0.1"
  private let localSocksPort: UInt16 = 10808
  private let tunnelAddressV4 = "198.18.0.1"
  private let tunnelMaskV4 = "255.255.0.0"
  private let tunnelAddressV6 = "fd7a:115c:a1e0::1"
  private let tunnelPrefixV6 = 64
  private let tunnelDirectoryName = "PacketTunnel"
  private let nativeLogFileName = "packet-tunnel.log"
  private let trafficStatsFileName = "traffic-stats.json"
  private let tunnelHealthFileName = "tunnel-health.json"
  private let activeSessionFileName = "active-session.json"
  private let reconnectCooldown: TimeInterval = 12
  private let monitorQueue = DispatchQueue(label: "cc.varpn.easyxray.ios.packet-tunnel.monitor")

  private var logFileURL: URL?
  private var trafficStatsFileURL: URL?
  private var tunnelHealthFileURL: URL?
  private var activeSessionFileURL: URL?
  private var trafficStatsTimer: DispatchSourceTimer?
  private var pathMonitor: Network.NWPathMonitor?
  private var currentRuntime: RuntimeConfiguration?
  private var currentPathStatus: Network.NWPath.Status = .requiresConnection

  private var lifetimeUplinkBytes: Int64 = 0
  private var lifetimeDownlinkBytes: Int64 = 0
  private var currentSessionUplinkBytes: Int64 = 0
  private var currentSessionDownlinkBytes: Int64 = 0
  private var lastSessionUplinkBytes: Int64 = 0
  private var lastSessionDownlinkBytes: Int64 = 0
  private var currentSessionStartedAt: Date?

  private var isStopping = false
  private var isRestarting = false
  private var nativeState = "stopped"
  private var lastReconnectReason: String?
  private var lastCrashReason: String?
  private var lastXrayExitCode: Int32?
  private var peakResidentMemoryBytes: UInt64 = 0
  private var lastWatchdogAction: String?
  private var lastReconnectAt: Date?

  override func startTunnel(
    options: [String: NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    isStopping = false
    isRestarting = false
    nativeState = "starting"
    lastCrashReason = nil
    lastXrayExitCode = nil
    peakResidentMemoryBytes = 0
    lastWatchdogAction = nil

    do {
      let runtime = try makeRuntimeConfiguration(options: options)
      currentRuntime = runtime
      try prepareSharedFiles(appGroupIdentifier: runtime.appGroupIdentifier)
      currentSessionStartedAt = Date()
      writeActiveSessionSnapshot(runtime)
      writeTrafficStatsSnapshot()
      writeTunnelHealthSnapshot()
      log(level: "info", source: "tunnel", message: "Starting packet tunnel.")

      let settings = createNetworkSettings(
        mtu: runtime.mtu,
        dnsServers: runtime.dnsServers,
        enableIpv6: runtime.enableIpv6,
        bypassLocalNetworks: runtime.bypassLocalNetworks
      )

      setTunnelNetworkSettings(settings) { [weak self] error in
        guard let self else {
          completionHandler(PacketTunnelError("Tunnel provider was released during startup."))
          return
        }

        if let error {
          self.lastCrashReason = "network-settings"
          self.log(
            level: "error",
            source: "tunnel",
            message: "Failed to apply network settings: \(error.localizedDescription)"
          )
          self.writeTunnelHealthSnapshot()
          completionHandler(error)
          return
        }

        do {
          try self.startRuntime(runtime)
        } catch {
          self.lastCrashReason = "runtime-start"
          self.log(
            level: "error",
            source: "tunnel",
            message: "Failed to start Xray runtime: \(error.localizedDescription)"
          )
          self.stopRuntime(finalizeSession: false, clearActiveSession: false)
          completionHandler(error)
          return
        }

        self.waitForLocalProxy(attempts: 24) { waitResult in
          switch waitResult {
          case let .failure(error):
            self.lastCrashReason = "local-proxy-timeout"
            self.log(
              level: "error",
              source: "xray",
              message: "Local SOCKS proxy did not become ready: \(error.localizedDescription)"
            )
            self.stopRuntime(finalizeSession: false, clearActiveSession: false)
            completionHandler(error)
          case .success:
            self.startTun2Socks(mtu: runtime.mtu)
            self.startTrafficStatsPolling()
            self.startNetworkMonitoring()
            self.refreshTrafficStats()
            self.nativeState = "connected"
            self.writeTunnelHealthSnapshot()
            self.log(
              level: "info",
              source: "tunnel",
              message: "Packet tunnel started."
            )
            completionHandler(nil)
          }
        }
      }
    } catch {
      completionHandler(error)
    }
  }

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    nativeState = "stopping"
    log(
      level: "info",
      source: "tunnel",
      message: "Stopping packet tunnel with reason \(reason.rawValue)."
    )
    writeTunnelHealthSnapshot()
    stopRuntime(finalizeSession: true, clearActiveSession: true)
    completionHandler()
  }

  private func makeRuntimeConfiguration(
    options: [String: NSObject]?
  ) throws -> RuntimeConfiguration {
    let providerConfiguration =
      (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration

    guard
      let appGroupIdentifier =
        providerConfiguration?["appGroupIdentifier"] as? String,
      !appGroupIdentifier.isEmpty
    else {
      throw PacketTunnelError("Missing app group identifier in provider configuration.")
    }

    let configPath = (options?["configPath"] as? String) ??
      (providerConfiguration?["configPath"] as? String)
    guard let configPath, !configPath.isEmpty else {
      throw PacketTunnelError("Missing Xray configuration path.")
    }

    let assetDirectory = (options?["assetDirectory"] as? String) ??
      (providerConfiguration?["assetDirectory"] as? String)
    guard let assetDirectory, !assetDirectory.isEmpty else {
      throw PacketTunnelError("Missing Xray asset directory.")
    }

    let dnsServers =
      (options?["dnsServers"] as? [String]) ??
      (providerConfiguration?["dnsServers"] as? [String]) ??
      ["1.1.1.1", "8.8.8.8"]
    let mtu =
      readInt(options?["mtu"]) ??
      readInt(providerConfiguration?["mtu"]) ??
      1500
    let enableIpv6 =
      readBool(options?["enableIpv6"]) ??
      readBool(providerConfiguration?["enableIpv6"]) ??
      true
    let bypassLocalNetworks =
      readBool(options?["bypassLocalNetworks"]) ??
      readBool(providerConfiguration?["bypassLocalNetworks"]) ??
      true
    let strictRouting =
      readBool(options?["strictRouting"]) ??
      readBool(providerConfiguration?["strictRouting"]) ??
      true
    let reconnectReason = options?["reconnectReason"] as? String
    let activeTransport =
      (options?["activeTransport"] as? String) ??
      (providerConfiguration?["activeTransport"] as? String) ??
      "unknown"

    lastReconnectReason = reconnectReason

    return RuntimeConfiguration(
      appGroupIdentifier: appGroupIdentifier,
      configPath: configPath,
      assetDirectory: assetDirectory,
      mtu: mtu,
      dnsServers: dnsServers,
      enableIpv6: enableIpv6,
      bypassLocalNetworks: bypassLocalNetworks,
      strictRouting: strictRouting,
      reconnectReason: reconnectReason,
      activeTransport: activeTransport
    )
  }

  private func createNetworkSettings(
    mtu: Int,
    dnsServers: [String],
    enableIpv6: Bool,
    bypassLocalNetworks: Bool
  ) -> NEPacketTunnelNetworkSettings {
    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: tunnelAddressV4)
    settings.mtu = NSNumber(value: mtu)

    let ipv4Settings = NEIPv4Settings(
      addresses: [tunnelAddressV4],
      subnetMasks: [tunnelMaskV4]
    )
    ipv4Settings.includedRoutes = [NEIPv4Route.default()]
    if bypassLocalNetworks {
      ipv4Settings.excludedRoutes = [
        NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
        NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
        NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
        NEIPv4Route(destinationAddress: "127.0.0.0", subnetMask: "255.0.0.0"),
      ]
    }
    settings.ipv4Settings = ipv4Settings

    if enableIpv6 {
      let ipv6Settings = NEIPv6Settings(
        addresses: [tunnelAddressV6],
        networkPrefixLengths: [NSNumber(value: tunnelPrefixV6)]
      )
      ipv6Settings.includedRoutes = [NEIPv6Route.default()]
      if bypassLocalNetworks {
        ipv6Settings.excludedRoutes = [
          NEIPv6Route(destinationAddress: "::1", networkPrefixLength: 128),
          NEIPv6Route(destinationAddress: "fc00::", networkPrefixLength: 7),
          NEIPv6Route(destinationAddress: "fe80::", networkPrefixLength: 10),
        ]
      }
      settings.ipv6Settings = ipv6Settings
    }

    if !dnsServers.isEmpty {
      let dnsSettings = NEDNSSettings(servers: dnsServers)
      dnsSettings.matchDomains = [""]
      settings.dnsSettings = dnsSettings
    }

    return settings
  }

  private func startRuntime(_ runtime: RuntimeConfiguration) throws {
    let request = try makeRunRequest(
      datDir: runtime.assetDirectory,
      configPath: runtime.configPath
    )
    let response = LibXrayRunXray(request)
    _ = try decodeLibXrayResponse(response)
    log(level: "info", source: "xray", message: "libXray runtime started.")
  }

  private func stopRuntime(finalizeSession: Bool, clearActiveSession: Bool) {
    isStopping = true
    trafficStatsTimer?.cancel()
    trafficStatsTimer = nil

    pathMonitor?.cancel()
    pathMonitor = nil

    refreshTrafficStats()
    if finalizeSession {
      finalizeTrafficStatsSession()
    }

    Socks5Tunnel.quit()
    stopXray(logErrors: false)

    currentRuntime = nil
    isRestarting = false
    nativeState = "stopped"
    writeTunnelHealthSnapshot()

    if clearActiveSession {
      clearActiveSessionSnapshot()
    }
  }

  private func stopXray(logErrors: Bool) {
    let response = LibXrayStopXray()
    do {
      _ = try decodeLibXrayResponse(response)
    } catch {
      if logErrors {
        log(
          level: "warning",
          source: "xray",
          message: "Failed to stop libXray cleanly: \(error.localizedDescription)"
        )
      }
    }
  }

  private func startTun2Socks(mtu: Int) {
    let config = """
    tunnel:
      mtu: \(mtu)
      ipv4: \(tunnelAddressV4)
      ipv6: '\(tunnelAddressV6)'

    socks5:
      address: \(localSocksHost)
      port: \(localSocksPort)
      udp: 'udp'
      pipeline: true

    misc:
      task-stack-size: 24576
      tcp-buffer-size: 4096
      connect-timeout: 5000
      read-write-timeout: 60000
      log-file: stderr
      log-level: error
      limit-nofile: 65535
    """

    Socks5Tunnel.run(withConfig: .string(content: config)) { [weak self] code in
      guard let self else {
        return
      }

      self.log(
        level: code == 0 ? "info" : "error",
        source: "tun",
        message: "Tun2Socks exited with code \(code)."
      )

      if !self.isStopping && code != 0 {
        self.scheduleControlledReconnect(reason: "tun2socks-exit-\(code)")
      }
    }
  }

  private func startTrafficStatsPolling() {
    trafficStatsTimer?.cancel()

    let timer = DispatchSource.makeTimerSource(queue: monitorQueue)
    timer.schedule(deadline: .now() + 2, repeating: .seconds(3))
    timer.setEventHandler { [weak self] in
      self?.refreshTrafficStats()
      self?.refreshTunnelHealthAndWatchdog()
    }
    trafficStatsTimer = timer
    timer.resume()
  }

  private func startNetworkMonitoring() {
    pathMonitor?.cancel()

    let monitor = Network.NWPathMonitor()
    currentPathStatus = monitor.currentPath.status
    monitor.pathUpdateHandler = { [weak self] path in
      guard let self else {
        return
      }

      let previousStatus = self.currentPathStatus
      self.currentPathStatus = path.status

      if path.status == .satisfied {
        if previousStatus != .satisfied {
          self.log(level: "info", source: "network", message: "Network path is available again.")
          self.scheduleControlledReconnect(reason: "network-recovered")
        }
      } else if previousStatus != path.status {
        self.log(level: "warning", source: "network", message: "Network path became unavailable.")
      }
    }
    monitor.start(queue: monitorQueue)
    pathMonitor = monitor
  }

  private func refreshTrafficStats() {
    let stats = Socks5Tunnel.stats
    currentSessionUplinkBytes = Int64(stats.up.bytes)
    currentSessionDownlinkBytes = Int64(stats.down.bytes)
    writeTrafficStatsSnapshot()
  }

  private func refreshTunnelHealthAndWatchdog() {
    let residentMemoryBytes = readResidentMemoryBytes()
    peakResidentMemoryBytes = max(peakResidentMemoryBytes, residentMemoryBytes)
    let pressure = memoryPressureLevel(for: residentMemoryBytes)

    if !isStopping && !isRestarting && nativeState == "connected" && !LibXrayGetXrayState() {
      lastCrashReason = "xray-state-lost"
      scheduleControlledReconnect(reason: "xray-state-lost")
    }

    switch pressure {
    case "soft":
      performMemoryCleanup()
      lastWatchdogAction = "soft-cleanup"
    case "hard":
      lastWatchdogAction = "restart-hard-threshold"
      scheduleControlledReconnect(reason: "memory-hard-threshold")
    case "critical":
      lastWatchdogAction = "restart-emergency-threshold"
      scheduleControlledReconnect(reason: "memory-emergency-threshold", force: true)
    default:
      break
    }

    writeTunnelHealthSnapshot()
  }

  private func scheduleControlledReconnect(reason: String, force: Bool = false) {
    DispatchQueue.main.async { [weak self] in
      self?.performControlledReconnect(reason: reason, force: force)
    }
  }

  private func performControlledReconnect(reason: String, force: Bool) {
    guard let runtime = currentRuntime, !isStopping else {
      return
    }

    if isRestarting {
      return
    }

    if
      !force,
      let lastReconnectAt,
      Date().timeIntervalSince(lastReconnectAt) < reconnectCooldown
    {
      return
    }

    isRestarting = true
    nativeState = "reconnecting"
    lastReconnectReason = reason
    lastReconnectAt = Date()
    lastWatchdogAction = "restart-\(reason)"
    writeTunnelHealthSnapshot()
    log(level: "warning", source: "watchdog", message: "Restarting runtime after \(reason).")

    Socks5Tunnel.quit()
    stopXray(logErrors: true)

    do {
      try startRuntime(runtime)
    } catch {
      isRestarting = false
      lastCrashReason = "reconnect-start-failed"
      writeTunnelHealthSnapshot()
      log(
        level: "error",
        source: "watchdog",
        message: "Failed to restart runtime after \(reason): \(error.localizedDescription)"
      )
      cancelTunnelWithError(error)
      return
    }

    waitForLocalProxy(attempts: 20) { [weak self] result in
      guard let self else {
        return
      }

      switch result {
      case let .failure(error):
        self.isRestarting = false
        self.lastCrashReason = "reconnect-proxy-timeout"
        self.writeTunnelHealthSnapshot()
        self.log(
          level: "error",
          source: "watchdog",
          message: "Runtime restart failed after \(reason): \(error.localizedDescription)"
        )
        self.cancelTunnelWithError(error)
      case .success:
        self.startTun2Socks(mtu: runtime.mtu)
        self.isRestarting = false
        self.nativeState = "connected"
        self.writeActiveSessionSnapshot(runtime)
        self.refreshTrafficStats()
        self.writeTunnelHealthSnapshot()
        self.log(
          level: "info",
          source: "watchdog",
          message: "Runtime restart completed after \(reason)."
        )
      }
    }
  }

  private func waitForLocalProxy(
    attempts: Int,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard attempts > 0 else {
      completion(.failure(PacketTunnelError("Timed out waiting for the local SOCKS proxy.")))
      return
    }

    let connection = NWConnection(
      host: NWEndpoint.Host(localSocksHost),
      port: NWEndpoint.Port(rawValue: localSocksPort)!,
      using: .tcp
    )

    connection.stateUpdateHandler = { [weak self] state in
      switch state {
      case .ready:
        connection.cancel()
        completion(.success(()))
      case .failed:
        connection.cancel()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.25) {
          self?.waitForLocalProxy(attempts: attempts - 1, completion: completion)
        }
      case .cancelled:
        break
      default:
        break
      }
    }

    connection.start(queue: monitorQueue)
  }

  private func prepareSharedFiles(appGroupIdentifier: String) throws {
    guard let sharedContainerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    ) else {
      throw PacketTunnelError("App Group container is unavailable for \(appGroupIdentifier).")
    }

    let tunnelDirectory = sharedContainerURL.appendingPathComponent(
      tunnelDirectoryName,
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: tunnelDirectory,
      withIntermediateDirectories: true
    )

    logFileURL = tunnelDirectory.appendingPathComponent(nativeLogFileName)
    trafficStatsFileURL = tunnelDirectory.appendingPathComponent(trafficStatsFileName)
    tunnelHealthFileURL = tunnelDirectory.appendingPathComponent(tunnelHealthFileName)
    activeSessionFileURL = tunnelDirectory.appendingPathComponent(activeSessionFileName)

    for fileURL in [logFileURL, trafficStatsFileURL, tunnelHealthFileURL, activeSessionFileURL].compactMap({ $0 }) {
      if !FileManager.default.fileExists(atPath: fileURL.path) {
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
      }
    }

    if
      let trafficStatsFileURL,
      let data = try? Data(contentsOf: trafficStatsFileURL),
      let rawObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    {
      lifetimeUplinkBytes = readInt64(rawObject["totalUplinkBytes"])
      lifetimeDownlinkBytes = readInt64(rawObject["totalDownlinkBytes"])
      lastSessionUplinkBytes = readInt64(rawObject["lastSessionUplinkBytes"])
      lastSessionDownlinkBytes = readInt64(rawObject["lastSessionDownlinkBytes"])
    } else {
      lifetimeUplinkBytes = 0
      lifetimeDownlinkBytes = 0
      lastSessionUplinkBytes = 0
      lastSessionDownlinkBytes = 0
    }

    currentSessionUplinkBytes = 0
    currentSessionDownlinkBytes = 0
  }

  private func writeActiveSessionSnapshot(_ runtime: RuntimeConfiguration) {
    guard let activeSessionFileURL else {
      return
    }

    let payload: [String: Any] = [
      "updatedAt": ISO8601DateFormatter().string(from: Date()),
      "configPath": runtime.configPath,
      "assetDirectory": runtime.assetDirectory,
      "dnsServers": runtime.dnsServers,
      "mtu": runtime.mtu,
      "enableIpv6": runtime.enableIpv6,
      "bypassLocalNetworks": runtime.bypassLocalNetworks,
      "strictRouting": runtime.strictRouting,
      "activeTransport": runtime.activeTransport,
      "lastReconnectReason": lastReconnectReason ?? NSNull(),
      "lastReconnectAt": lastReconnectAt.map {
        ISO8601DateFormatter().string(from: $0)
      } ?? NSNull(),
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
      return
    }

    try? data.write(to: activeSessionFileURL, options: .atomic)
  }

  private func clearActiveSessionSnapshot() {
    guard let activeSessionFileURL else {
      return
    }
    try? FileManager.default.removeItem(at: activeSessionFileURL)
  }

  private func writeTrafficStatsSnapshot() {
    guard let trafficStatsFileURL else {
      return
    }

    let payload: [String: Any] = [
      "totalUplinkBytes": lifetimeUplinkBytes + currentSessionUplinkBytes,
      "totalDownlinkBytes": lifetimeDownlinkBytes + currentSessionDownlinkBytes,
      "currentSessionUplinkBytes": currentSessionUplinkBytes,
      "currentSessionDownlinkBytes": currentSessionDownlinkBytes,
      "lastSessionUplinkBytes": lastSessionUplinkBytes,
      "lastSessionDownlinkBytes": lastSessionDownlinkBytes,
      "currentSessionStartedAt": currentSessionStartedAt.map {
        ISO8601DateFormatter().string(from: $0)
      } ?? NSNull(),
      "updatedAt": ISO8601DateFormatter().string(from: Date()),
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
      return
    }

    try? data.write(to: trafficStatsFileURL, options: .atomic)
  }

  private func finalizeTrafficStatsSession() {
    lastSessionUplinkBytes = currentSessionUplinkBytes
    lastSessionDownlinkBytes = currentSessionDownlinkBytes
    lifetimeUplinkBytes += currentSessionUplinkBytes
    lifetimeDownlinkBytes += currentSessionDownlinkBytes
    currentSessionUplinkBytes = 0
    currentSessionDownlinkBytes = 0
    currentSessionStartedAt = nil
    writeTrafficStatsSnapshot()
  }

  private func writeTunnelHealthSnapshot() {
    guard let tunnelHealthFileURL else {
      return
    }

    let residentMemoryBytes = readResidentMemoryBytes()
    peakResidentMemoryBytes = max(peakResidentMemoryBytes, residentMemoryBytes)
    let payload: [String: Any] = [
      "updatedAt": ISO8601DateFormatter().string(from: Date()),
      "nativeState": nativeState,
      "xrayRunning": LibXrayGetXrayState(),
      "residentMemoryBytes": residentMemoryBytes,
      "peakResidentMemoryBytes": peakResidentMemoryBytes,
      "memoryPressure": memoryPressureLevel(for: residentMemoryBytes),
      "activeTransport": currentRuntime?.activeTransport ?? NSNull(),
      "lastWatchdogAction": lastWatchdogAction ?? NSNull(),
      "lastReconnectAt": lastReconnectAt.map {
        ISO8601DateFormatter().string(from: $0)
      } ?? NSNull(),
      "lastReconnectReason": lastReconnectReason ?? NSNull(),
      "lastCrashReason": lastCrashReason ?? NSNull(),
      "lastXrayExitCode": lastXrayExitCode ?? NSNull(),
      "proxyConfigured": false,
      "proxyReachable": true,
      "protectedServiceCount": 0,
      "totalServiceCount": 0,
      "lastProxyError": NSNull(),
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
      return
    }

    try? data.write(to: tunnelHealthFileURL, options: .atomic)
  }

  private func performMemoryCleanup() {
    URLCache.shared.removeAllCachedResponses()

    guard let activeSessionFileURL else {
      return
    }

    let tunnelDirectory = activeSessionFileURL.deletingLastPathComponent()
    let knownPaths = Set([
      logFileURL?.path,
      trafficStatsFileURL?.path,
      tunnelHealthFileURL?.path,
      activeSessionFileURL.path,
      currentRuntime?.configPath,
    ].compactMap { $0 })

    guard let files = try? FileManager.default.contentsOfDirectory(
      at: tunnelDirectory,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ) else {
      return
    }

    let cutoff = Date().addingTimeInterval(-6 * 60 * 60)
    for fileURL in files where !knownPaths.contains(fileURL.path) {
      let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
      if let modificationDate = values?.contentModificationDate, modificationDate < cutoff {
        try? FileManager.default.removeItem(at: fileURL)
      }
    }
  }

  private func readResidentMemoryBytes() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(
      MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
    )

    let result = withUnsafeMutablePointer(to: &info) { infoPointer in
      infoPointer.withMemoryRebound(
        to: integer_t.self,
        capacity: Int(count)
      ) { reboundPointer in
        task_info(
          mach_task_self_,
          task_flavor_t(MACH_TASK_BASIC_INFO),
          reboundPointer,
          &count
        )
      }
    }

    guard result == KERN_SUCCESS else {
      return 0
    }

    return UInt64(info.resident_size)
  }

  private func memoryPressureLevel(for residentMemoryBytes: UInt64) -> String {
    let megabyte = UInt64(1024 * 1024)
    switch residentMemoryBytes {
    case 0:
      return "unknown"
    case 0..<(36 * megabyte):
      return "normal"
    case ..<(42 * megabyte):
      return "soft"
    case ..<(48 * megabyte):
      return "hard"
    default:
      return "critical"
    }
  }

  private func makeRunRequest(datDir: String, configPath: String) throws -> String {
    var error: NSError?
    let request = LibXrayNewXrayRunRequest(datDir, "", configPath, &error)
    if let error {
      throw error
    }
    return request
  }

  private func decodeLibXrayResponse(_ encoded: String) throws -> [String: Any] {
    guard let data = Data(base64Encoded: encoded) else {
      throw PacketTunnelError("libXray returned invalid base64 data.")
    }

    guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw PacketTunnelError("libXray returned invalid JSON data.")
    }

    if (response["success"] as? Bool) == false {
      throw PacketTunnelError(
        response["error"] as? String ?? "Unknown libXray runtime error."
      )
    }

    return response
  }

  private func readInt(_ value: Any?) -> Int? {
    switch value {
    case let value as NSNumber:
      return value.intValue
    case let value as String:
      return Int(value)
    default:
      return nil
    }
  }

  private func readBool(_ value: Any?) -> Bool? {
    switch value {
    case let value as Bool:
      return value
    case let value as NSNumber:
      return value.boolValue
    case let value as String:
      switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
      case "1", "true":
        return true
      case "0", "false":
        return false
      default:
        return nil
      }
    default:
      return nil
    }
  }

  private func readInt64(_ value: Any?) -> Int64 {
    switch value {
    case let value as NSNumber:
      return value.int64Value
    case let value as String:
      return Int64(value) ?? 0
    default:
      return 0
    }
  }

  private func log(level: String, source: String, message: String) {
    let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else {
      return
    }

    NSLog("[%@] %@", source, normalized)

    guard let logFileURL else {
      return
    }

    let payload: [String: Any] = [
      "timestamp": ISO8601DateFormatter().string(from: Date()),
      "level": level,
      "source": source,
      "message": normalized,
    ]

    guard
      let data = try? JSONSerialization.data(withJSONObject: payload),
      let handle = try? FileHandle(forWritingTo: logFileURL)
    else {
      return
    }

    handle.seekToEndOfFile()
    handle.write(data)
    handle.write(Data([0x0A]))
    try? handle.close()
  }
}

private struct RuntimeConfiguration {
  let appGroupIdentifier: String
  let configPath: String
  let assetDirectory: String
  let mtu: Int
  let dnsServers: [String]
  let enableIpv6: Bool
  let bypassLocalNetworks: Bool
  let strictRouting: Bool
  let reconnectReason: String?
  let activeTransport: String
}

private struct PacketTunnelError: LocalizedError {
  let description: String

  init(_ description: String) {
    self.description = description
  }

  var errorDescription: String? {
    description
  }
}
