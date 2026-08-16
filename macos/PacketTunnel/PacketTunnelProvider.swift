import Darwin
import Foundation
import Network
import NetworkExtension
import Tun2SocksKit

final class PacketTunnelProvider: NEPacketTunnelProvider {
  private let localSocksHost = "127.0.0.1"
  private let localSocksPort: UInt16 = 10808
  private let xrayApiAddress = "127.0.0.1:10085"
  private let tunnelAddressV4 = "198.18.0.1"
  private let tunnelMaskV4 = "255.255.0.0"
  private let tunnelAddressV6 = "fd7a:115c:a1e0::1"
  private let tunnelPrefixV6 = 64
  private let tunnelDirectoryName = "PacketTunnel"
  private let nativeLogFileName = "packet-tunnel.log"
  private let trafficStatsFileName = "traffic-stats.json"
  private let tunnelHealthFileName = "tunnel-health.json"

  private var xrayProcess: Process?
  private var stdoutPipe: Pipe?
  private var stderrPipe: Pipe?
  private var logFileURL: URL?
  private var trafficStatsFileURL: URL?
  private var tunnelHealthFileURL: URL?
  private var trafficStatsTimer: DispatchSourceTimer?
  private let trafficStatsQueue = DispatchQueue(
    label: "cc.varpn.easyxray.packet-tunnel.traffic-stats"
  )
  private var lifetimeUplinkBytes: Int64 = 0
  private var lifetimeDownlinkBytes: Int64 = 0
  private var currentSessionUplinkBytes: Int64 = 0
  private var currentSessionDownlinkBytes: Int64 = 0
  private var lastSessionUplinkBytes: Int64 = 0
  private var lastSessionDownlinkBytes: Int64 = 0
  private var currentSessionStartedAt: Date?
  private var isStopping = false
  private var nativeState = "stopped"
  private var lastReconnectReason: String?
  private var lastCrashReason: String?
  private var lastXrayExitCode: Int32?

  override func startTunnel(
    options: [String: NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    isStopping = false
    nativeState = "starting"
    lastCrashReason = nil
    writeTunnelHealthSnapshot()

    do {
      let runtime = try makeRuntimeConfiguration(options: options)
      try prepareLogFile(appGroupIdentifier: runtime.appGroupIdentifier)
      try prepareTrafficStatsFile(appGroupIdentifier: runtime.appGroupIdentifier)
      try prepareTunnelHealthFile(appGroupIdentifier: runtime.appGroupIdentifier)
      currentSessionStartedAt = Date()
      writeTrafficStatsSnapshot()
      writeTunnelHealthSnapshot()
      log(
        level: "info",
        source: "tunnel",
        message: "Starting packet tunnel."
      )

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
          self.log(
            level: "error",
            source: "tunnel",
            message: "Failed to apply network settings: \(error.localizedDescription)"
          )
          completionHandler(error)
          return
        }

        do {
          try self.startXray(
            configPath: runtime.configPath,
            assetDirectory: runtime.assetDirectory
          )
        } catch {
          self.log(
            level: "error",
            source: "xray",
            message: "Failed to start Xray: \(error.localizedDescription)"
          )
          self.stopRuntime()
          completionHandler(error)
          return
        }

        self.waitForLocalProxy(attempts: 24) { proxyResult in
          switch proxyResult {
          case let .failure(error):
            self.log(
              level: "error",
              source: "xray",
              message: "Local SOCKS proxy did not become ready: \(error.localizedDescription)"
            )
            self.stopRuntime()
            completionHandler(error)
          case .success:
            self.refreshTrafficStats(logErrors: false)
            self.startTrafficStatsPolling()
            self.startTun2Socks(mtu: runtime.mtu)
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
    log(
      level: "info",
      source: "tunnel",
      message: "Stopping packet tunnel with reason \(reason.rawValue)."
    )
    nativeState = "stopping"
    writeTunnelHealthSnapshot()
    stopRuntime()
    completionHandler()
  }

  private func makeRuntimeConfiguration(
    options: [String: NSObject]?
  ) throws -> RuntimeConfiguration {
    let providerConfiguration =
      (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration

    guard let appGroupIdentifier =
      providerConfiguration?["appGroupIdentifier"] as? String,
      !appGroupIdentifier.isEmpty
    else {
      throw PacketTunnelError("Missing app group identifier in provider configuration.")
    }

    guard let configPath = options?["configPath"] as? String, !configPath.isEmpty else {
      throw PacketTunnelError("Missing Xray configuration path.")
    }

    guard let assetDirectory =
      options?["assetDirectory"] as? String,
      !assetDirectory.isEmpty
    else {
      throw PacketTunnelError("Missing Xray asset directory.")
    }

    let mtu = (options?["mtu"] as? NSNumber)?.intValue ?? 1500
    let dnsServers = options?["dnsServers"] as? [String] ?? ["1.1.1.1", "8.8.8.8"]
    let enableIpv6 = (options?["enableIpv6"] as? NSNumber)?.boolValue ?? true
    let bypassLocalNetworks =
      (options?["bypassLocalNetworks"] as? NSNumber)?.boolValue ?? true
    let strictRouting = (options?["strictRouting"] as? NSNumber)?.boolValue ?? true
    let reconnectReason = options?["reconnectReason"] as? String
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
      reconnectReason: reconnectReason
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

  private func startXray(
    configPath: String,
    assetDirectory: String
  ) throws {
    let executableURL = try resolveXrayExecutableURL()
    let process = Process()
    process.executableURL = executableURL
    process.arguments = ["-c", configPath]
    process.currentDirectoryURL = executableURL.deletingLastPathComponent()

    var environment = ProcessInfo.processInfo.environment
    environment["XRAY_LOCATION_ASSET"] = assetDirectory
    process.environment = environment

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    attachReadHandler(
      to: stdoutPipe.fileHandleForReading,
      source: "xray",
      level: "info"
    )
    attachReadHandler(
      to: stderrPipe.fileHandleForReading,
      source: "xray",
      level: "warning"
    )

    process.terminationHandler = { [weak self] terminatedProcess in
      guard let self else {
        return
      }

      self.lastXrayExitCode = terminatedProcess.terminationStatus
      let level = terminatedProcess.terminationStatus == 0 ? "info" : "error"
      self.log(
        level: level,
        source: "xray",
        message: "Xray exited with code \(terminatedProcess.terminationStatus)."
      )
      if terminatedProcess.terminationStatus != 0 {
        self.lastCrashReason = "xray-exit-\(terminatedProcess.terminationStatus)"
      }
      self.writeTunnelHealthSnapshot()

      if !self.isStopping {
        self.cancelTunnelWithError(
          PacketTunnelError(
            "Xray exited unexpectedly with code \(terminatedProcess.terminationStatus)."
          )
        )
      }
    }

    try process.run()
    self.xrayProcess = process
    self.stdoutPipe = stdoutPipe
    self.stderrPipe = stderrPipe
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
        self.cancelTunnelWithError(
          PacketTunnelError("Tun2Socks exited unexpectedly with code \(code).")
        )
      }
    }
  }

  private func stopRuntime() {
    isStopping = true
    nativeState = "stopping"
    refreshTrafficStats(logErrors: false)
    finalizeTrafficStatsSession()
    trafficStatsTimer?.cancel()
    trafficStatsTimer = nil
    Socks5Tunnel.quit()

    stdoutPipe?.fileHandleForReading.readabilityHandler = nil
    stderrPipe?.fileHandleForReading.readabilityHandler = nil
    stdoutPipe = nil
    stderrPipe = nil

    if let process = xrayProcess {
      process.terminationHandler = nil
      if process.isRunning {
        process.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
          if process.isRunning {
            process.interrupt()
          }
        }
      }
    }

    xrayProcess = nil
    nativeState = "stopped"
    writeTunnelHealthSnapshot()
  }

  private func startTrafficStatsPolling() {
    trafficStatsTimer?.cancel()

    let timer = DispatchSource.makeTimerSource(queue: trafficStatsQueue)
    timer.schedule(deadline: .now() + 3, repeating: .seconds(5))
    timer.setEventHandler { [weak self] in
      self?.refreshTrafficStats(logErrors: false)
    }
    trafficStatsTimer = timer
    timer.resume()
  }

  private func refreshTrafficStats(logErrors: Bool) {
    guard xrayProcess?.isRunning == true else {
      writeTrafficStatsSnapshot()
      return
    }

    do {
      let stats = try queryTrafficStats()
      currentSessionUplinkBytes = stats.uplinkBytes
      currentSessionDownlinkBytes = stats.downlinkBytes
      writeTrafficStatsSnapshot()
      writeTunnelHealthSnapshot()
    } catch {
      if logErrors {
        log(
          level: "warning",
          source: "traffic",
          message: "Failed to refresh traffic stats: \(error.localizedDescription)"
        )
      }
    }
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

  private func queryTrafficStats() throws -> TrafficCounters {
    let executableURL = try resolveXrayExecutableURL()
    let process = Process()
    process.executableURL = executableURL
    process.arguments = [
      "api",
      "statsquery",
      "--server=\(xrayApiAddress)",
      "-timeout",
      "3",
      "-pattern",
      "outbound>>>proxy>>>traffic>>>",
    ]

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

    guard process.terminationStatus == 0 else {
      let stderr = String(data: stderrData, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
      throw PacketTunnelError("Traffic stats query failed: \(stderr)")
    }

    return try parseTrafficCounters(from: stdoutData)
  }

  private func parseTrafficCounters(from data: Data) throws -> TrafficCounters {
    guard
      let rawObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let rawStats = rawObject["stat"] as? [[String: Any]]
    else {
      throw PacketTunnelError("Traffic stats response was not valid JSON.")
    }

    var uplinkBytes: Int64 = 0
    var downlinkBytes: Int64 = 0

    for entry in rawStats {
      guard
        let name = entry["name"] as? String,
        let value = entry["value"]
      else {
        continue
      }

      let parsedValue = Int64("\(value)") ?? 0
      if name.hasSuffix(">>>uplink") {
        uplinkBytes = parsedValue
      } else if name.hasSuffix(">>>downlink") {
        downlinkBytes = parsedValue
      }
    }

    return TrafficCounters(
      uplinkBytes: max(uplinkBytes, 0),
      downlinkBytes: max(downlinkBytes, 0)
    )
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

    connection.start(queue: .global(qos: .utility))
  }

  private func resolveXrayExecutableURL() throws -> URL {
    let candidates = [
      Bundle.main.resourceURL?.appendingPathComponent("xray-core/xray"),
      Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/xray-core/xray"),
    ].compactMap { $0 }

    for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate.path) {
      return candidate
    }

    throw PacketTunnelError("Bundled Xray executable was not found inside the packet tunnel extension.")
  }

  private func prepareLogFile(appGroupIdentifier: String) throws {
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

    let fileURL = tunnelDirectory.appendingPathComponent(nativeLogFileName)
    if !FileManager.default.fileExists(atPath: fileURL.path) {
      FileManager.default.createFile(atPath: fileURL.path, contents: nil)
    }
    logFileURL = fileURL
  }

  private func prepareTrafficStatsFile(appGroupIdentifier: String) throws {
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

    let fileURL = tunnelDirectory.appendingPathComponent(trafficStatsFileName)
    trafficStatsFileURL = fileURL

    if
      let data = try? Data(contentsOf: fileURL),
      let rawObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    {
      lifetimeUplinkBytes = readInt64(rawObject["totalUplinkBytes"])
      lifetimeDownlinkBytes = readInt64(rawObject["totalDownlinkBytes"])
      lastSessionUplinkBytes = readInt64(rawObject["lastSessionUplinkBytes"])
      lastSessionDownlinkBytes = readInt64(rawObject["lastSessionDownlinkBytes"])
    } else if !FileManager.default.fileExists(atPath: fileURL.path) {
      FileManager.default.createFile(atPath: fileURL.path, contents: nil)
    }

    currentSessionUplinkBytes = 0
    currentSessionDownlinkBytes = 0
  }

  private func prepareTunnelHealthFile(appGroupIdentifier: String) throws {
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

    let fileURL = tunnelDirectory.appendingPathComponent(tunnelHealthFileName)
    tunnelHealthFileURL = fileURL
    if !FileManager.default.fileExists(atPath: fileURL.path) {
      FileManager.default.createFile(atPath: fileURL.path, contents: nil)
    }
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

  private func writeTunnelHealthSnapshot() {
    guard let tunnelHealthFileURL else {
      return
    }

    let residentMemoryBytes = readResidentMemoryBytes()
    let payload: [String: Any] = [
      "updatedAt": ISO8601DateFormatter().string(from: Date()),
      "nativeState": nativeState,
      "xrayRunning": xrayProcess?.isRunning == true,
      "residentMemoryBytes": residentMemoryBytes,
      "memoryPressure": memoryPressureLevel(for: residentMemoryBytes),
      "lastReconnectReason": lastReconnectReason ?? NSNull(),
      "lastCrashReason": lastCrashReason ?? NSNull(),
      "lastXrayExitCode": lastXrayExitCode ?? NSNull(),
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
      return
    }

    try? data.write(to: tunnelHealthFileURL, options: .atomic)
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
    case 0..<(128 * megabyte):
      return "normal"
    case ..<(256 * megabyte):
      return "soft"
    case ..<(384 * megabyte):
      return "hard"
    default:
      return "critical"
    }
  }

  private func readInt64(_ value: Any?) -> Int64 {
    switch value {
    case let number as NSNumber:
      return number.int64Value
    case let string as String:
      return Int64(string) ?? 0
    default:
      return 0
    }
  }

  private func attachReadHandler(
    to fileHandle: FileHandle,
    source: String,
    level: String
  ) {
    fileHandle.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard !data.isEmpty else {
        return
      }

      guard let content = String(data: data, encoding: .utf8) else {
        return
      }

      for rawLine in content.split(whereSeparator: \.isNewline) {
        self?.log(
          level: level,
          source: source,
          message: String(rawLine)
        )
      }
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
}

private struct TrafficCounters {
  let uplinkBytes: Int64
  let downlinkBytes: Int64
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
