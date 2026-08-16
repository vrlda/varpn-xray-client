import Darwin
import Foundation
import Network
import Tun2SocksKit

private let ctlIoCgInfo: UInt = 0xC0644E03

private enum HelperPaths {
  static let helperLabel = "cc.varpn.easyxray.utun-helper"
  static let sharedRoot = URL(fileURLWithPath: "/Users/Shared/VarPN", isDirectory: true)
  static let stateDirectory = sharedRoot.appendingPathComponent("state", isDirectory: true)
  static let configDirectory = sharedRoot.appendingPathComponent("configs", isDirectory: true)
  static let geodataDirectory = sharedRoot.appendingPathComponent("geodata", isDirectory: true)
  static let socketURL = stateDirectory.appendingPathComponent("helper.sock")
  static let activeSessionURL = stateDirectory.appendingPathComponent("active-session.json")
  static let trafficStatsURL = stateDirectory.appendingPathComponent("traffic-stats.json")
  static let tunnelHealthURL = stateDirectory.appendingPathComponent("tunnel-health.json")
  static let logURL = stateDirectory.appendingPathComponent("packet-tunnel.log")
  static let xrayExecutableURL = URL(
    fileURLWithPath: "/Library/Application Support/VarPN/xray-core/xray"
  )
  static let xrayWorkingDirectory = URL(
    fileURLWithPath: "/Library/Application Support/VarPN/xray-core",
    isDirectory: true
  )
  static let stateURLs = [
    sharedRoot,
    stateDirectory,
    configDirectory,
    geodataDirectory,
  ]
}

private struct ActiveSessionSnapshot {
  struct Candidate {
    let nodePayload: [String: Any]
    let nodeId: String
    let nodeName: String
    let countryCode: String?
    let serverAddress: String
    let configPath: String
    let activeTransport: String?

    init?(json: [String: Any]) {
      let node = json["node"] as? [String: Any] ?? [:]
      let nodeId = readString(node["id"]) ?? ""
      let nodeName = readString(node["name"]) ?? ""
      let serverAddress = readString(node["server"]) ?? ""
      let configPath = readString(json["configPath"]) ?? ""

      guard !nodeId.isEmpty,
            !nodeName.isEmpty,
            !serverAddress.isEmpty,
            !configPath.isEmpty
      else {
        return nil
      }

      self.nodePayload = node
      self.nodeId = nodeId
      self.nodeName = nodeName
      self.countryCode = readString(json["countryCode"]) ??
        readString(node["countryCode"])
      self.serverAddress = serverAddress
      self.configPath = configPath
      self.activeTransport = readString(json["activeTransport"])
    }

    func toJson() -> [String: Any] {
      [
        "node": nodePayload,
        "countryCode": countryCode as Any,
        "configPath": configPath,
        "activeTransport": activeTransport as Any,
      ]
    }
  }

  let isActive: Bool
  let connectionMode: String
  let selectedCountryCode: String?
  let lastWorkingNodeId: String?
  let tunnelSettings: [String: Any]
  let candidates: [Candidate]

  init?(
    json: [String: Any]
  ) {
    let rawCandidates = json["candidates"] as? [[String: Any]] ?? []
    let candidates = rawCandidates.compactMap(Candidate.init(json:))
    guard !candidates.isEmpty else {
      return nil
    }

    self.isActive = readBool(json["isActive"]) ?? false
    self.connectionMode = readString(json["connectionMode"]) ?? "node"
    self.selectedCountryCode = readString(json["selectedCountryCode"])
    self.lastWorkingNodeId = readString(json["lastWorkingNodeId"])
    self.tunnelSettings = json["tunnelSettings"] as? [String: Any] ?? [:]
    self.candidates = candidates
  }

  func toJson() -> [String: Any] {
    [
      "isActive": isActive,
      "connectionMode": connectionMode,
      "selectedCountryCode": selectedCountryCode as Any,
      "lastWorkingNodeId": lastWorkingNodeId as Any,
      "tunnelSettings": tunnelSettings,
      "candidates": candidates.map { $0.toJson() },
      "updatedAt": ISO8601DateFormatter().string(from: Date()),
    ]
  }
}

private struct RouteContext {
  let interfaceName: String
  let gateway: String?
  let primaryService: String?
  let routeServerIPs: [String]
  let ipv6Enabled: Bool
}

private struct TrafficCounters {
  let uplinkBytes: Int64
  let downlinkBytes: Int64
}

private struct HelperStatusSnapshot {
  let nativeState: String
  let helperInstalled: Bool
  let helperReachable: Bool
  let routesConfigured: Bool
  let dnsConfigured: Bool
  let utunInterfaceName: String?
}

private final class TunnelController {
  private let queue = DispatchQueue(label: "cc.varpn.easyxray.utun-helper.controller")
  private let ifconfigPath = "/sbin/ifconfig"
  private let routePath = "/sbin/route"
  private let networksetupPath = "/usr/sbin/networksetup"
  private let psPath = "/bin/ps"
  private let localSocksHost = "127.0.0.1"
  private let tunnelAddressV4 = "198.18.0.1"
  private let tunnelMaskV4 = "255.255.0.0"
  private let tunnelAddressV6 = "fd7a:115c:a1e0::1"
  private let tunnelPrefixV6 = 64
  private let splitRouteV4A = "0.0.0.0/1"
  private let splitRouteV4B = "128.0.0.0/1"
  private let splitRouteV6A = "::/1"
  private let splitRouteV6B = "8000::/1"

  private var xrayProcess: Process?
  private var stdoutPipe: Pipe?
  private var stderrPipe: Pipe?
  private var utunFileDescriptor: Int32 = -1
  private var utunInterfaceName: String?
  private var activeSession: ActiveSessionSnapshot?
  private var currentCandidateIndex = 0
  private var restartAttemptsForCandidate = 0
  private var restoreAttemptsRemaining = 0
  private var isStopping = false
  private var nativeState = "disconnected"
  private var routesConfigured = false
  private var dnsConfigured = false
  private var currentRouteContext: RouteContext?
  private var previousDnsServers: [String]?
  private var previousDnsService: String?
  private var trafficStatsTimer: DispatchSourceTimer?
  private var restoreTimer: DispatchSourceTimer?
  private var lifetimeUplinkBytes: Int64 = 0
  private var lifetimeDownlinkBytes: Int64 = 0
  private var sessionAccumulatedUplinkBytes: Int64 = 0
  private var sessionAccumulatedDownlinkBytes: Int64 = 0
  private var currentSessionUplinkBytes: Int64 = 0
  private var currentSessionDownlinkBytes: Int64 = 0
  private var lastSessionUplinkBytes: Int64 = 0
  private var lastSessionDownlinkBytes: Int64 = 0
  private var currentSessionStartedAt: Date?
  private var lastWatchdogAction: String?
  private var lastReconnectAt: Date?
  private var lastReconnectReason: String?
  private var lastRepairAction: String?
  private var lastCrashReason: String?
  private var lastXrayExitCode: Int32?
  private var peakResidentMemoryBytes = 0
  private var tun2SocksRunning = false
  private var currentApiPort: UInt16 = 10085
  private var currentLocalSocksPort: UInt16 = 10808
  private var healthWatchdogTimer: DispatchSourceTimer?
  private var pathMonitor: NWPathMonitor?
  private var lastPathStatus: NWPath.Status?
  private var lastRuntimeRepairAttemptAt: Date?

  init() {
    ensureRuntimeDirectories()
    restoreTrafficSnapshot()
    writeHealthSnapshot()
    startHealthWatchdog()
    startPathMonitor()
  }

  func bootstrap() {
    queue.async {
      self.restoreActiveSessionIfNeeded()
    }
  }

  func helperStatus() -> [String: Any] {
    queue.sync {
      [
        "installed": FileManager.default.fileExists(
          atPath: HelperPaths.xrayExecutableURL.path
        ),
        "reachable": true,
        "nativeState": nativeState,
        "helperInstalled": true,
        "helperReachable": true,
        "routesConfigured": routesConfigured,
        "dnsConfigured": dnsConfigured,
        "utunInterfaceName": utunInterfaceName as Any,
      ]
    }
  }

  func startTunnel(arguments: [String: Any]) throws -> [String: Any] {
    try queue.sync {
      guard let sessionJson = arguments["activeSession"] as? [String: Any],
            let session = ActiveSessionSnapshot(json: sessionJson)
      else {
        throw HelperError("Missing active session payload.")
      }

      self.activeSession = session
      self.currentCandidateIndex = Self.indexForPreferredCandidate(in: session)
      self.restartAttemptsForCandidate = 0
      self.restoreAttemptsRemaining = 0
      self.currentSessionStartedAt = Date()
      self.lastReconnectReason = readString(arguments["reconnectReason"])
      self.lastReconnectAt = self.lastReconnectReason == nil ? nil : Date()
      self.lastCrashReason = nil
      self.lastRepairAction = nil

      try self.persistActiveSession()
      try self.startCurrentCandidate(
        reconnectReason: self.lastReconnectReason,
        preserveSession: false
      )

      return [
        "status": nativeState,
        "candidate": currentCandidate?.nodeName as Any,
      ]
    }
  }

  func stopTunnel() throws -> [String: Any] {
    try queue.sync {
      try self.stopRuntime(
        clearActiveSession: true,
        finalizeSession: true,
        nextState: "disconnected"
      )
      return ["status": nativeState]
    }
  }

  func repairTunnel() throws -> [String: Any] {
    try queue.sync {
      guard let session = activeSession ?? loadActiveSessionSnapshot(), session.isActive else {
        throw HelperError("No active session is available to repair.")
      }

      activeSession = session
      lastRepairAction = "manual-repair"
      lastReconnectReason = "manual repair"
      lastReconnectAt = Date()
      try startCurrentCandidate(
        reconnectReason: "manual repair",
        preserveSession: true
      )
      return ["status": nativeState]
    }
  }

  func tunnelStatus() -> String {
    queue.sync { nativeState }
  }

  func tunnelHealth() -> [String: Any] {
    queue.sync {
      let snapshot = readJsonFile(at: HelperPaths.tunnelHealthURL)
      return snapshot.isEmpty ? currentHealthSnapshot() : snapshot
    }
  }

  func trafficStats() -> [String: Any] {
    queue.sync {
      let snapshot = readJsonFile(at: HelperPaths.trafficStatsURL)
      return snapshot.isEmpty ? currentTrafficSnapshot() : snapshot
    }
  }

  func nativeLogEntries() -> [[String: Any]] {
    queue.sync {
      guard let data = try? Data(contentsOf: HelperPaths.logURL),
            let content = String(data: data, encoding: .utf8)
      else {
        return []
      }

      return content
        .split(whereSeparator: \.isNewline)
        .suffix(200)
        .compactMap { line in
          guard let data = line.data(using: .utf8),
                let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
          else {
            return nil
          }
          return raw
        }
    }
  }

  func clearNativeLogs() {
    queue.sync {
      try? Data().write(to: HelperPaths.logURL, options: .atomic)
    }
  }

  private var currentCandidate: ActiveSessionSnapshot.Candidate? {
    guard let session = activeSession,
          currentCandidateIndex >= 0,
          currentCandidateIndex < session.candidates.count
    else {
      return nil
    }
    return session.candidates[currentCandidateIndex]
  }

  private static func indexForPreferredCandidate(
    in session: ActiveSessionSnapshot
  ) -> Int {
    guard let preferredNodeId = session.lastWorkingNodeId,
          let index = session.candidates.firstIndex(where: { $0.nodeId == preferredNodeId })
    else {
      return 0
    }
    return index
  }

  private func restoreActiveSessionIfNeeded() {
    guard let session = loadActiveSessionSnapshot(), session.isActive else {
      return
    }

    let previousHealth = readJsonFile(at: HelperPaths.tunnelHealthURL)
    let previousState = readString(previousHealth["nativeState"]) ?? "disconnected"
    guard previousState == "connected" || previousState == "connecting" else {
      log(
        level: "info",
        source: "helper",
        message: "Skipping background restore because the last recorded state was \(previousState)."
      )
      return
    }

    activeSession = session
    currentCandidateIndex = Self.indexForPreferredCandidate(in: session)
    restoreAttemptsRemaining = 5
    log(level: "info", source: "helper", message: "Restoring the last active session in the background.")
    scheduleRestoreRetry(reason: "boot restore")
  }

  private func scheduleRestoreRetry(reason: String) {
    restoreTimer?.cancel()
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + .seconds(2))
    timer.setEventHandler { [weak self] in
      guard let self else {
        return
      }

      guard self.restoreAttemptsRemaining > 0 else {
        self.restoreTimer?.cancel()
        self.restoreTimer = nil
        self.log(level: "warning", source: "helper", message: "Background restore stopped after repeated failures.")
        return
      }

      self.restoreAttemptsRemaining -= 1
      self.lastRepairAction = "boot-restore-attempt"
      do {
        try self.startCurrentCandidate(
          reconnectReason: reason,
          preserveSession: true
        )
        self.restoreTimer?.cancel()
        self.restoreTimer = nil
      } catch {
        self.log(
          level: "warning",
          source: "helper",
          message: "Restore attempt failed: \(error.localizedDescription)"
        )
        if self.restoreAttemptsRemaining > 0 {
          self.scheduleRestoreRetry(reason: reason)
        }
      }
    }
    restoreTimer = timer
    timer.resume()
  }

  private func startHealthWatchdog() {
    healthWatchdogTimer?.cancel()
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + .seconds(8), repeating: .seconds(8))
    timer.setEventHandler { [weak self] in
      self?.monitorRuntimeHealth()
    }
    healthWatchdogTimer = timer
    timer.resume()
  }

  private func startPathMonitor() {
    pathMonitor?.cancel()
    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { [weak self] path in
      self?.queue.async {
        self?.handlePathUpdate(path)
      }
    }
    monitor.start(queue: queue)
    pathMonitor = monitor
  }

  private func handlePathUpdate(_ path: NWPath) {
    let didChangeStatus = lastPathStatus != path.status
    lastPathStatus = path.status

    guard let session = activeSession, session.isActive else {
      if didChangeStatus {
        writeHealthSnapshot()
      }
      return
    }

    guard didChangeStatus else {
      return
    }

    switch path.status {
    case .satisfied:
      log(
        level: "info",
        source: "network",
        message: "Network path is available again. Re-validating the utun runtime."
      )
      if nativeState == "disconnected" || nativeState == "error" {
        maybeRepairRuntime(reason: "network path restored")
      } else {
        monitorRuntimeHealth()
      }
    case .unsatisfied:
      lastWatchdogAction = "network-unavailable"
      log(
        level: "warning",
        source: "network",
        message: "Network path is unavailable."
      )
      writeHealthSnapshot()
    case .requiresConnection:
      lastWatchdogAction = "network-waiting"
      log(
        level: "info",
        source: "network",
        message: "Network path requires a new connection. Keeping the session ready to recover."
      )
      writeHealthSnapshot()
    @unknown default:
      writeHealthSnapshot()
    }
  }

  private func monitorRuntimeHealth() {
    guard let session = activeSession, session.isActive else {
      writeHealthSnapshot()
      return
    }
    guard !isStopping else {
      return
    }

    if nativeState == "disconnected" || nativeState == "error" {
      maybeRepairRuntime(reason: "background restore")
      return
    }

    guard xrayProcess?.isRunning == true else {
      lastCrashReason = lastCrashReason ?? "watchdog-xray-stopped"
      handleUnexpectedExit(reason: lastCrashReason ?? "watchdog xray stop")
      return
    }

    guard let interfaceName = utunInterfaceName,
          verifyInterfaceExists(interfaceName)
    else {
      lastCrashReason = "watchdog-utun-missing"
      handleUnexpectedExit(reason: lastCrashReason ?? "watchdog utun missing")
      return
    }

    let routeHealthy = verifyRoutesStillApplied()
    let dnsHealthy = verifyDnsStillApplied()

    if routeHealthy && dnsHealthy {
      routesConfigured = true
      dnsConfigured = true
      writeHealthSnapshot()
      return
    }

    routesConfigured = routeHealthy
    dnsConfigured = dnsHealthy
    maybeRepairRuntime(
      reason: !routeHealthy && !dnsHealthy
        ? "routes and DNS drifted"
        : (routeHealthy ? "DNS drifted" : "routes drifted")
    )
  }

  private func maybeRepairRuntime(reason: String) {
    let now = Date()
    if let lastAttempt = lastRuntimeRepairAttemptAt,
       now.timeIntervalSince(lastAttempt) < 12
    {
      lastWatchdogAction = "repair-cooldown"
      writeHealthSnapshot()
      return
    }

    lastRuntimeRepairAttemptAt = now
    lastRepairAction = reason
    lastReconnectReason = reason
    lastReconnectAt = now
    lastWatchdogAction = "repair-runtime"
    log(
      level: "warning",
      source: "watchdog",
      message: "Repairing the utun runtime after \(reason)."
    )

    do {
      try startCurrentCandidate(
        reconnectReason: reason,
        preserveSession: true
      )
    } catch {
      log(
        level: "warning",
        source: "watchdog",
        message: "Runtime repair failed: \(error.localizedDescription)"
      )
      writeHealthSnapshot()
    }
  }

  private func startCurrentCandidate(
    reconnectReason: String?,
    preserveSession: Bool
  ) throws {
    guard let session = activeSession else {
      throw HelperError("No active session is available.")
    }
    guard let candidate = currentCandidate else {
      throw HelperError("No candidate config is available.")
    }

    log(level: "info", source: "tunnel", message: "Starting candidate \(candidate.nodeName).")

    try stopRuntime(
      clearActiveSession: false,
      finalizeSession: !preserveSession,
      nextState: "disconnected"
    )

    if preserveSession {
      preserveSessionProgress()
    } else {
      sessionAccumulatedUplinkBytes = 0
      sessionAccumulatedDownlinkBytes = 0
      currentSessionUplinkBytes = 0
      currentSessionDownlinkBytes = 0
      currentSessionStartedAt = Date()
    }

    nativeState = "connecting"
    writeHealthSnapshot()

    do {
      let tunnelSettings = session.tunnelSettings
      let mtu = readInt(tunnelSettings["mtu"]) ?? 1500
      let enableIpv6 = readBool(tunnelSettings["ipv6Enabled"]) ?? true
      let dnsMode = readString(tunnelSettings["dnsMode"]) ?? "custom"
      let dnsServers = dnsMode == "system"
        ? []
        : (tunnelSettings["dnsServers"] as? [Any] ?? [])
          .compactMap(readString)
          .filter { !$0.isEmpty }
      let runtimePorts = try readRuntimePorts(from: candidate.configPath)
      currentLocalSocksPort = runtimePorts.localSocksPort
      currentApiPort = runtimePorts.apiPort

      log(level: "info", source: "tunnel", message: "Preparing utun runtime for \(candidate.nodeName).")
      let routeContext = try resolveRouteContext(
        for: candidate.serverAddress,
        enableIpv6: enableIpv6
      )
      currentRouteContext = routeContext

      log(level: "info", source: "tunnel", message: "Creating utun interface.")
      let utun = try createUtun()
      utunFileDescriptor = utun.fileDescriptor
      utunInterfaceName = utun.interfaceName

      log(level: "info", source: "tunnel", message: "Configuring interface \(utun.interfaceName).")
      try configureUtunInterface(
        interfaceName: utun.interfaceName,
        mtu: mtu,
        enableIpv6: enableIpv6
      )

      log(level: "info", source: "tunnel", message: "Starting Xray runtime from \(candidate.configPath).")
      try startXray(configPath: candidate.configPath)
      log(level: "info", source: "tunnel", message: "Waiting for the local SOCKS bridge.")
      try waitForLocalProxy()
      log(level: "info", source: "tunnel", message: "Starting tun2socks.")
      startTun2Socks(mtu: mtu)

      log(level: "info", source: "tunnel", message: "Applying DNS override.")
      try applyDnsOverride(
        serviceName: routeContext.primaryService,
        dnsServers: dnsServers
      )
      log(level: "info", source: "tunnel", message: "Applying routes to \(utun.interfaceName).")
      try applyRoutes(routeContext: routeContext)
      try verifyRuntimeHealthy()

      nativeState = "connected"
      restartAttemptsForCandidate = 0
      lastReconnectReason = reconnectReason
      lastReconnectAt = reconnectReason == nil ? nil : Date()
      updateLastWorkingNode(candidate.nodeId)
      startTrafficPolling()
      writeTrafficSnapshot()
      writeHealthSnapshot()
      log(level: "info", source: "tunnel", message: "Connected through utun interface \(utun.interfaceName).")
    } catch {
      lastCrashReason = error.localizedDescription
      try? stopRuntime(
        clearActiveSession: false,
        finalizeSession: false,
        nextState: "error"
      )
      writeHealthSnapshot()
      throw error
    }
  }

  private func startXray(configPath: String) throws {
    guard FileManager.default.isExecutableFile(atPath: HelperPaths.xrayExecutableURL.path) else {
      throw HelperError("Bundled Xray executable is not installed.")
    }
    guard FileManager.default.fileExists(atPath: configPath) else {
      throw HelperError("Runtime config does not exist at \(configPath).")
    }

    let process = Process()
    process.executableURL = HelperPaths.xrayExecutableURL
    process.currentDirectoryURL = HelperPaths.xrayWorkingDirectory
    process.arguments = ["-c", configPath]
    process.environment = [
      "XRAY_LOCATION_ASSET": HelperPaths.geodataDirectory.path,
    ]

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    attachLogPipe(stdoutPipe, source: "xray", level: "info")
    attachLogPipe(stderrPipe, source: "xray", level: "warning")

    process.terminationHandler = { [weak self] process in
      self?.queue.async {
        guard let self else {
          return
        }

        self.lastXrayExitCode = process.terminationStatus
        if self.isStopping {
          self.writeHealthSnapshot()
          return
        }

        self.lastCrashReason = "xray-exit-\(process.terminationStatus)"
        self.log(
          level: "error",
          source: "xray",
          message: "Xray exited unexpectedly with code \(process.terminationStatus)."
        )
        self.handleUnexpectedExit(reason: self.lastCrashReason ?? "xray exit")
      }
    }

    try process.run()
    xrayProcess = process
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
      port: \(currentLocalSocksPort)
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

    tun2SocksRunning = true
    Socks5Tunnel.run(withConfig: .string(content: config)) { [weak self] code in
      self?.queue.async {
        guard let self else {
          return
        }

        self.tun2SocksRunning = false

        if self.isStopping {
          return
        }

        if code != 0 {
          self.lastCrashReason = "tun2socks-exit-\(code)"
          self.log(
            level: "error",
            source: "tun2socks",
            message: "Tun2Socks exited unexpectedly with code \(code)."
          )
          self.handleUnexpectedExit(reason: self.lastCrashReason ?? "tun2socks exit")
        }
      }
    }
  }

  private func verifyRuntimeHealthy() throws {
    Thread.sleep(forTimeInterval: 0.8)

    guard xrayProcess?.isRunning == true else {
      throw HelperError(
        lastCrashReason ?? "Xray exited before the tunnel became stable."
      )
    }

    try waitForLocalProxy()
  }

  private func verifyInterfaceExists(_ interfaceName: String) -> Bool {
    (try? runCommand(ifconfigPath, [interfaceName])) != nil
  }

  private func verifyRoutesStillApplied() -> Bool {
    guard let interfaceName = utunInterfaceName else {
      return false
    }

    let ipv4Healthy = routePointsThroughInterface(
      ["-n", "get", "1.1.1.1"],
      interfaceName: interfaceName
    )
    guard ipv4Healthy else {
      return false
    }

    guard currentRouteContext?.ipv6Enabled == true else {
      return true
    }

    return routePointsThroughInterface(
      ["-n", "get", "-inet6", "2606:4700:4700::1111"],
      interfaceName: interfaceName
    )
  }

  private func routePointsThroughInterface(
    _ arguments: [String],
    interfaceName: String
  ) -> Bool {
    guard let routedInterface = try? runCommand(routePath, arguments)
      .split(whereSeparator: \.isNewline)
      .map({ $0.trimmingCharacters(in: .whitespaces) })
      .first(where: { $0.hasPrefix("interface:") })?
      .replacingOccurrences(of: "interface:", with: "")
      .trimmingCharacters(in: .whitespaces),
      !routedInterface.isEmpty
    else {
      return false
    }

    return routedInterface == interfaceName
  }

  private func verifyDnsStillApplied() -> Bool {
    guard let session = activeSession else {
      return !dnsConfigured
    }

    let dnsMode = readString(session.tunnelSettings["dnsMode"]) ?? "custom"
    let expectedServers = (session.tunnelSettings["dnsServers"] as? [Any] ?? [])
      .compactMap(readString)
      .filter { !$0.isEmpty }

    if dnsMode == "system" || expectedServers.isEmpty {
      return true
    }

    guard let serviceName = previousDnsService ?? currentRouteContext?.primaryService,
          !serviceName.isEmpty,
          let currentServers = try? readDnsServers(for: serviceName)
    else {
      return false
    }

    return currentServers.count == expectedServers.count &&
      Set(currentServers) == Set(expectedServers)
  }

  private func readRuntimePorts(
    from configPath: String
  ) throws -> (localSocksPort: UInt16, apiPort: UInt16) {
    guard
      let data = FileManager.default.contents(atPath: configPath),
      let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      throw HelperError("Runtime config is missing or unreadable at \(configPath).")
    }

    let inboundPort =
      readInt((object["inbounds"] as? [[String: Any]])?.first?["port"]) ?? 10808
    let apiListen = ((object["api"] as? [String: Any])?["listen"])
      .flatMap(readString)
    let apiPortString = apiListen.flatMap { listen in
      listen.split(separator: ":").last.map(String.init)
    }
    let apiPort: Int = apiPortString.flatMap { Int($0) } ?? 10085

    guard inboundPort > 0 && inboundPort <= Int(UInt16.max) else {
      throw HelperError("Runtime config contained an invalid local SOCKS port.")
    }
    guard apiPort > 0 && apiPort <= Int(UInt16.max) else {
      throw HelperError("Runtime config contained an invalid Xray API port.")
    }

    return (UInt16(inboundPort), UInt16(apiPort))
  }

  private func handleUnexpectedExit(reason: String) {
    preserveSessionProgress()
    stopRuntimeWithoutFinalizing(nextState: "disconnected")

    guard var session = activeSession, session.isActive else {
      nativeState = "disconnected"
      writeHealthSnapshot()
      return
    }

    if restartAttemptsForCandidate < 2 {
      restartAttemptsForCandidate += 1
      lastWatchdogAction = "restart-current-node"
      lastReconnectReason = reason
      lastReconnectAt = Date()
      log(level: "warning", source: "watchdog", message: "Restarting the current node after \(reason).")
      do {
        try startCurrentCandidate(
          reconnectReason: reason,
          preserveSession: true
        )
        return
      } catch {
        log(level: "warning", source: "watchdog", message: "Restart attempt failed: \(error.localizedDescription)")
      }
    }

    if currentCandidateIndex + 1 < session.candidates.count {
      currentCandidateIndex += 1
      restartAttemptsForCandidate = 0
      lastWatchdogAction = "same-country-failover"
      lastReconnectReason = "same-country failover"
      lastReconnectAt = Date()
      log(level: "warning", source: "watchdog", message: "Switching to a same-country fallback after \(reason).")
      do {
        try startCurrentCandidate(
          reconnectReason: "same-country failover",
          preserveSession: true
        )
        return
      } catch {
        log(level: "warning", source: "watchdog", message: "Failover attempt failed: \(error.localizedDescription)")
      }
    }

    session = ActiveSessionSnapshot(
      json: [
        "isActive": false,
        "connectionMode": session.connectionMode,
        "selectedCountryCode": session.selectedCountryCode as Any,
        "lastWorkingNodeId": session.lastWorkingNodeId as Any,
        "tunnelSettings": session.tunnelSettings,
        "candidates": session.candidates.map { $0.toJson() },
      ]
    ) ?? session
    activeSession = session
    try? persistActiveSession()
    nativeState = "disconnected"
    writeHealthSnapshot()
  }

  private func stopRuntime(
    clearActiveSession: Bool,
    finalizeSession: Bool,
    nextState: String
  ) throws {
    isStopping = true
    trafficStatsTimer?.cancel()
    trafficStatsTimer = nil
    restoreTimer?.cancel()
    restoreTimer = nil

    refreshTrafficStats(logErrors: false)
    if finalizeSession {
      finalizeCurrentSession()
    }

    try restoreDnsOverride()
    try removeRoutes()
    dnsConfigured = false
    routesConfigured = false

    if tun2SocksRunning {
      Socks5Tunnel.quit()
      tun2SocksRunning = false
    }

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
      xrayProcess = nil
    }

    if utunFileDescriptor >= 0 {
      Darwin.close(utunFileDescriptor)
      utunFileDescriptor = -1
      utunInterfaceName = nil
    }

    if clearActiveSession {
      if let session = activeSession {
        activeSession = ActiveSessionSnapshot(
          json: [
            "isActive": false,
            "connectionMode": session.connectionMode,
            "selectedCountryCode": session.selectedCountryCode as Any,
            "lastWorkingNodeId": session.lastWorkingNodeId as Any,
            "tunnelSettings": session.tunnelSettings,
            "candidates": session.candidates.map { $0.toJson() },
          ]
        )
      }
      try? persistActiveSession()
    }

    currentRouteContext = nil
    previousDnsServers = nil
    previousDnsService = nil

    nativeState = nextState
    isStopping = false
    writeTrafficSnapshot()
    writeHealthSnapshot()
  }

  private func stopRuntimeWithoutFinalizing(nextState: String) {
    try? stopRuntime(
      clearActiveSession: false,
      finalizeSession: false,
      nextState: nextState
    )
  }

  private func preserveSessionProgress() {
    sessionAccumulatedUplinkBytes += currentSessionUplinkBytes
    sessionAccumulatedDownlinkBytes += currentSessionDownlinkBytes
    currentSessionUplinkBytes = 0
    currentSessionDownlinkBytes = 0
    writeTrafficSnapshot()
  }

  private func finalizeCurrentSession() {
    let sessionUplink = sessionAccumulatedUplinkBytes + currentSessionUplinkBytes
    let sessionDownlink = sessionAccumulatedDownlinkBytes + currentSessionDownlinkBytes

    lifetimeUplinkBytes += sessionUplink
    lifetimeDownlinkBytes += sessionDownlink
    lastSessionUplinkBytes = sessionUplink
    lastSessionDownlinkBytes = sessionDownlink
    sessionAccumulatedUplinkBytes = 0
    sessionAccumulatedDownlinkBytes = 0
    currentSessionUplinkBytes = 0
    currentSessionDownlinkBytes = 0
    currentSessionStartedAt = nil
    writeTrafficSnapshot()
  }

  private func startTrafficPolling() {
    trafficStatsTimer?.cancel()
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + .seconds(3), repeating: .seconds(5))
    timer.setEventHandler { [weak self] in
      self?.refreshTrafficStats(logErrors: false)
    }
    trafficStatsTimer = timer
    timer.resume()
  }

  private func refreshTrafficStats(logErrors: Bool) {
    guard xrayProcess?.isRunning == true else {
      writeTrafficSnapshot()
      return
    }

    do {
      let stats = try queryTrafficStats()
      currentSessionUplinkBytes = stats.uplinkBytes
      currentSessionDownlinkBytes = stats.downlinkBytes
      writeTrafficSnapshot()
      writeHealthSnapshot()
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

  private func queryTrafficStats() throws -> TrafficCounters {
    let process = Process()
    process.executableURL = HelperPaths.xrayExecutableURL
    process.currentDirectoryURL = HelperPaths.xrayWorkingDirectory
    process.arguments = [
      "api",
      "statsquery",
      "--server=127.0.0.1:\(currentApiPort)",
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
      throw HelperError("Traffic stats query failed: \(stderr)")
    }

    guard
      let object = try JSONSerialization.jsonObject(with: stdoutData) as? [String: Any],
      let entries = object["stat"] as? [[String: Any]]
    else {
      throw HelperError("Traffic stats response was not valid JSON.")
    }

    var uplinkBytes: Int64 = 0
    var downlinkBytes: Int64 = 0
    for entry in entries {
      let name = readString(entry["name"]) ?? ""
      let value = readInt64(entry["value"]) ?? 0
      if name.hasSuffix(">>>uplink") {
        uplinkBytes = value
      } else if name.hasSuffix(">>>downlink") {
        downlinkBytes = value
      }
    }

    return TrafficCounters(uplinkBytes: max(uplinkBytes, 0), downlinkBytes: max(downlinkBytes, 0))
  }

  private func waitForLocalProxy() throws {
    var attempts = 24
    while attempts > 0 {
      let connection = NWConnection(
        host: NWEndpoint.Host(localSocksHost),
        port: NWEndpoint.Port(rawValue: currentLocalSocksPort)!,
        using: .tcp
      )
      let semaphore = DispatchSemaphore(value: 0)
      var success = false

      connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
          success = true
          connection.cancel()
          semaphore.signal()
        case .failed:
          connection.cancel()
          semaphore.signal()
        case .cancelled:
          break
        default:
          break
        }
      }

      connection.start(queue: .global(qos: .utility))
      _ = semaphore.wait(timeout: .now() + .milliseconds(500))
      if success {
        return
      }

      attempts -= 1
      Thread.sleep(forTimeInterval: 0.2)
    }

    throw HelperError("Timed out waiting for the local SOCKS proxy.")
  }

  private func resolveRouteContext(
    for serverAddress: String,
    enableIpv6: Bool
  ) throws -> RouteContext {
    let defaultRoute = try readDefaultRouteInfo()
    let serviceName = try readPrimaryService(for: defaultRoute.interfaceName)
    let serverIPs = resolveServerAddresses(serverAddress).filter { address in
      enableIpv6 || !address.contains(":")
    }

    return RouteContext(
      interfaceName: defaultRoute.interfaceName,
      gateway: defaultRoute.gateway,
      primaryService: serviceName,
      routeServerIPs: serverIPs,
      ipv6Enabled: enableIpv6
    )
  }

  private func readDefaultRouteInfo() throws -> (interfaceName: String, gateway: String?) {
    let output = try runCommand(routePath, ["-n", "get", "default"])
    var interfaceName: String?
    var gateway: String?
    for line in output.split(whereSeparator: \.isNewline) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("interface:") {
        interfaceName = trimmed
          .replacingOccurrences(of: "interface:", with: "")
          .trimmingCharacters(in: .whitespaces)
      } else if trimmed.hasPrefix("gateway:") {
        gateway = trimmed
          .replacingOccurrences(of: "gateway:", with: "")
          .trimmingCharacters(in: .whitespaces)
      }
    }

    guard let interfaceName, !interfaceName.isEmpty else {
      throw HelperError("Could not determine the active default interface.")
    }

    return (interfaceName, gateway)
  }

  private func readPrimaryService(for interfaceName: String) throws -> String? {
    let output = try runCommand(networksetupPath, ["-listnetworkserviceorder"])
    var currentService: String?
    for rawLine in output.split(whereSeparator: \.isNewline) {
      let line = rawLine.trimmingCharacters(in: .whitespaces)
      if line.hasPrefix("("),
         let range = line.range(of: #"\)\s"#, options: .regularExpression) {
        currentService = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        continue
      }

      if line.contains("Device: \(interfaceName)"), let currentService, !currentService.isEmpty {
        return currentService
      }
    }

    return nil
  }

  private func resolveServerAddresses(_ serverAddress: String) -> [String] {
    if serverAddress.contains(":") && serverAddress.contains(".") == false {
      return [serverAddress]
    }
    if serverAddress.split(separator: ".").count == 4 {
      return [serverAddress]
    }

    var addresses = Set<String>()
    var hints = addrinfo(
      ai_flags: AI_ADDRCONFIG,
      ai_family: AF_UNSPEC,
      ai_socktype: SOCK_STREAM,
      ai_protocol: IPPROTO_TCP,
      ai_addrlen: 0,
      ai_canonname: nil,
      ai_addr: nil,
      ai_next: nil
    )
    var infoPointer: UnsafeMutablePointer<addrinfo>?
    let status = getaddrinfo(serverAddress, nil, &hints, &infoPointer)
    guard status == 0, let head = infoPointer else {
      return []
    }
    defer { freeaddrinfo(head) }

    var pointer: UnsafeMutablePointer<addrinfo>? = head
    while let current = pointer {
      var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      let numericResult = getnameinfo(
        current.pointee.ai_addr,
        current.pointee.ai_addrlen,
        &hostBuffer,
        socklen_t(hostBuffer.count),
        nil,
        0,
        NI_NUMERICHOST
      )
      if numericResult == 0 {
        let value = String(cString: hostBuffer)
        if !value.isEmpty {
          addresses.insert(value)
        }
      }
      pointer = current.pointee.ai_next
    }

    return Array(addresses)
  }

  private func applyRoutes(routeContext: RouteContext) throws {
    guard let interfaceName = utunInterfaceName else {
      throw HelperError("utun interface is not ready.")
    }

    if let gateway = routeContext.gateway {
      for serverIP in routeContext.routeServerIPs where !serverIP.contains(":") {
        try runCommand(
          routePath,
          ["-n", "add", "-host", serverIP, gateway]
        )
      }
    }

    try runCommand(
      routePath,
      ["-n", "add", "-net", splitRouteV4A, "-interface", interfaceName]
    )
    try runCommand(
      routePath,
      ["-n", "add", "-net", splitRouteV4B, "-interface", interfaceName]
    )

    if routeContext.ipv6Enabled {
      try runCommand(
        routePath,
        ["-n", "add", "-inet6", "-net", splitRouteV6A, "-interface", interfaceName]
      )
      try runCommand(
        routePath,
        ["-n", "add", "-inet6", "-net", splitRouteV6B, "-interface", interfaceName]
      )
    }

    routesConfigured = true
  }

  private func removeRoutes() throws {
    guard let routeContext = currentRouteContext else {
      routesConfigured = false
      return
    }

    if let interfaceName = utunInterfaceName {
      _ = try? runCommand(routePath, ["-n", "delete", "-net", splitRouteV4A, "-interface", interfaceName])
      _ = try? runCommand(routePath, ["-n", "delete", "-net", splitRouteV4B, "-interface", interfaceName])
      if routeContext.ipv6Enabled {
        _ = try? runCommand(routePath, ["-n", "delete", "-inet6", "-net", splitRouteV6A, "-interface", interfaceName])
        _ = try? runCommand(routePath, ["-n", "delete", "-inet6", "-net", splitRouteV6B, "-interface", interfaceName])
      }
    }

    if let gateway = routeContext.gateway {
      for serverIP in routeContext.routeServerIPs where !serverIP.contains(":") {
        _ = try? runCommand(routePath, ["-n", "delete", "-host", serverIP, gateway])
      }
    }

    routesConfigured = false
  }

  private func applyDnsOverride(
    serviceName: String?,
    dnsServers: [String]
  ) throws {
    guard let serviceName, !serviceName.isEmpty else {
      dnsConfigured = false
      return
    }
    guard !dnsServers.isEmpty else {
      dnsConfigured = false
      return
    }

    previousDnsService = serviceName
    previousDnsServers = try readDnsServers(for: serviceName)
    var command = [networksetupPath, "-setdnsservers", serviceName]
    command.append(contentsOf: dnsServers)
    _ = try runCommand(command[0], Array(command.dropFirst()))
    dnsConfigured = true
  }

  private func restoreDnsOverride() throws {
    guard let serviceName = previousDnsService else {
      dnsConfigured = false
      return
    }

    let previousDnsServers = previousDnsServers ?? []
    if previousDnsServers.isEmpty {
      _ = try runCommand(networksetupPath, ["-setdnsservers", serviceName, "Empty"])
    } else {
      var command = [networksetupPath, "-setdnsservers", serviceName]
      command.append(contentsOf: previousDnsServers)
      _ = try runCommand(command[0], Array(command.dropFirst()))
    }
    dnsConfigured = false
  }

  private func readDnsServers(for serviceName: String) throws -> [String] {
    let output = try runCommand(networksetupPath, ["-getdnsservers", serviceName])
    if output.contains("There aren't any DNS Servers set") {
      return []
    }
    return output
      .split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private func configureUtunInterface(
    interfaceName: String,
    mtu: Int,
    enableIpv6: Bool
  ) throws {
    _ = try runCommand(
      ifconfigPath,
      [
        interfaceName,
        "inet",
        tunnelAddressV4,
        tunnelAddressV4,
        "netmask",
        tunnelMaskV4,
        "mtu",
        "\(mtu)",
        "up",
      ]
    )

    if enableIpv6 {
      _ = try? runCommand(
        ifconfigPath,
        [
          interfaceName,
          "inet6",
          "\(tunnelAddressV6)/\(tunnelPrefixV6)",
          "alias",
        ]
      )
    }
  }

  private func createUtun() throws -> (fileDescriptor: Int32, interfaceName: String) {
    let fd = Darwin.socket(PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL)
    guard fd >= 0 else {
      let message = String(cString: strerror(errno))
      throw HelperError("Failed to create the utun control socket: \(message) (\(errno)).")
    }

    var ctlInfo = ctl_info()
    let controlName = Array("com.apple.net.utun_control".utf8CString.dropLast())
      .map(UInt8.init(bitPattern:))
    withUnsafeMutableBytes(of: &ctlInfo.ctl_name) { buffer in
      buffer.copyBytes(from: controlName)
    }

    guard ioctl(fd, ctlIoCgInfo, &ctlInfo) >= 0 else {
      let errorCode = errno
      let message = String(cString: strerror(errorCode))
      Darwin.close(fd)
      throw HelperError("Could not resolve the utun control ID: \(message) (\(errorCode)).")
    }

    var address = sockaddr_ctl(
      sc_len: UInt8(MemoryLayout<sockaddr_ctl>.stride),
      sc_family: UInt8(AF_SYSTEM),
      ss_sysaddr: UInt16(AF_SYS_CONTROL),
      sc_id: ctlInfo.ctl_id,
      sc_unit: 0,
      sc_reserved: (0, 0, 0, 0, 0)
    )

    let connectResult = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
        Darwin.connect(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_ctl>.stride))
      }
    }

    guard connectResult == 0 else {
      let errorCode = errno
      let message = String(cString: strerror(errorCode))
      Darwin.close(fd)
      throw HelperError("Failed to connect to the utun control socket: \(message) (\(errorCode)).")
    }

    var interfaceNameBuffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))
    var length = socklen_t(interfaceNameBuffer.count)
    guard getsockopt(
      fd,
      SYSPROTO_CONTROL,
      UTUN_OPT_IFNAME,
      &interfaceNameBuffer,
      &length
    ) == 0 else {
      let errorCode = errno
      let message = String(cString: strerror(errorCode))
      Darwin.close(fd)
      throw HelperError("Failed to read the utun interface name: \(message) (\(errorCode)).")
    }

    return (fd, String(cString: interfaceNameBuffer))
  }

  private func runCommand(
    _ executablePath: String,
    _ arguments: [String],
    shellSplit: Bool = false
  ) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = shellSplit
      ? arguments.flatMap { $0.split(separator: " ").map(String.init) }
      : arguments
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
    let stdoutText = String(data: stdoutData, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let stderrText = String(data: stderrData, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard process.terminationStatus == 0 else {
      throw HelperError(stderrText.isEmpty ? stdoutText : stderrText)
    }

    return stdoutText
  }

  private func attachLogPipe(_ pipe: Pipe, source: String, level: String) {
    pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard !data.isEmpty,
            let content = String(data: data, encoding: .utf8)
      else {
        return
      }

      for rawLine in content.split(whereSeparator: \.isNewline) {
        self?.log(level: level, source: source, message: String(rawLine))
      }
    }
  }

  private func ensureRuntimeDirectories() {
    let manager = FileManager.default
    for url in HelperPaths.stateURLs {
      try? manager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    if !manager.fileExists(atPath: HelperPaths.logURL.path) {
      manager.createFile(atPath: HelperPaths.logURL.path, contents: nil)
    }
  }

  private func restoreTrafficSnapshot() {
    let snapshot = readJsonFile(at: HelperPaths.trafficStatsURL)
    lifetimeUplinkBytes = readInt64(snapshot["totalUplinkBytes"]) ?? 0
    lifetimeDownlinkBytes = readInt64(snapshot["totalDownlinkBytes"]) ?? 0
    lastSessionUplinkBytes = readInt64(snapshot["lastSessionUplinkBytes"]) ?? 0
    lastSessionDownlinkBytes = readInt64(snapshot["lastSessionDownlinkBytes"]) ?? 0
  }

  private func loadActiveSessionSnapshot() -> ActiveSessionSnapshot? {
    ActiveSessionSnapshot(json: readJsonFile(at: HelperPaths.activeSessionURL))
  }

  private func persistActiveSession() throws {
    guard let activeSession else {
      try Data().write(to: HelperPaths.activeSessionURL, options: .atomic)
      return
    }

    let data = try JSONSerialization.data(withJSONObject: activeSession.toJson())
    try data.write(to: HelperPaths.activeSessionURL, options: .atomic)
  }

  private func updateLastWorkingNode(_ nodeId: String) {
    guard let session = activeSession else {
      return
    }

    activeSession = ActiveSessionSnapshot(
      json: [
        "isActive": true,
        "connectionMode": session.connectionMode,
        "selectedCountryCode": session.selectedCountryCode as Any,
        "lastWorkingNodeId": nodeId,
        "tunnelSettings": session.tunnelSettings,
        "candidates": session.candidates.map { $0.toJson() },
      ]
    )
    try? persistActiveSession()
  }

  private func currentTrafficSnapshot() -> [String: Any] {
    [
      "totalUplinkBytes": lifetimeUplinkBytes + sessionAccumulatedUplinkBytes + currentSessionUplinkBytes,
      "totalDownlinkBytes": lifetimeDownlinkBytes + sessionAccumulatedDownlinkBytes + currentSessionDownlinkBytes,
      "currentSessionUplinkBytes": sessionAccumulatedUplinkBytes + currentSessionUplinkBytes,
      "currentSessionDownlinkBytes": sessionAccumulatedDownlinkBytes + currentSessionDownlinkBytes,
      "lastSessionUplinkBytes": lastSessionUplinkBytes,
      "lastSessionDownlinkBytes": lastSessionDownlinkBytes,
      "currentSessionStartedAt": currentSessionStartedAt.map {
        ISO8601DateFormatter().string(from: $0)
      } as Any,
      "updatedAt": ISO8601DateFormatter().string(from: Date()),
    ]
  }

  private func writeTrafficSnapshot() {
    let payload = currentTrafficSnapshot()
    guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
      return
    }
    try? data.write(to: HelperPaths.trafficStatsURL, options: .atomic)
  }

  private func currentHealthSnapshot() -> [String: Any] {
    let residentMemoryBytes = readResidentMemoryBytes()
    peakResidentMemoryBytes = max(peakResidentMemoryBytes, residentMemoryBytes)

    return [
      "updatedAt": ISO8601DateFormatter().string(from: Date()),
      "nativeState": nativeState,
      "xrayRunning": xrayProcess?.isRunning == true,
      "residentMemoryBytes": residentMemoryBytes,
      "peakResidentMemoryBytes": peakResidentMemoryBytes,
      "memoryPressure": memoryPressureLevel(for: residentMemoryBytes),
      "activeTransport": currentCandidate?.activeTransport as Any,
      "lastWatchdogAction": lastWatchdogAction as Any,
      "lastReconnectAt": lastReconnectAt.map {
        ISO8601DateFormatter().string(from: $0)
      } as Any,
      "lastReconnectReason": lastReconnectReason as Any,
      "lastCrashReason": lastCrashReason as Any,
      "lastXrayExitCode": lastXrayExitCode as Any,
      "proxyConfigured": false,
      "proxyReachable": false,
      "protectedServiceCount": 0,
      "totalServiceCount": 0,
      "lastProxyError": NSNull(),
      "connectionMode": activeSession?.connectionMode as Any,
      "helperInstalled": true,
      "helperReachable": true,
      "utunInterfaceName": utunInterfaceName as Any,
      "routesConfigured": routesConfigured,
      "dnsConfigured": dnsConfigured,
      "lastRepairAction": lastRepairAction as Any,
    ]
  }

  private func writeHealthSnapshot() {
    let payload = currentHealthSnapshot()
    guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
      return
    }
    try? data.write(to: HelperPaths.tunnelHealthURL, options: .atomic)
  }

  private func readResidentMemoryBytes() -> Int {
    guard let process = xrayProcess else {
      return 0
    }

    do {
      let output = try runCommand(psPath, ["-o", "rss=", "-p", "\(process.processIdentifier)"])
      let kilobytes = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
      return kilobytes * 1024
    } catch {
      return 0
    }
  }

  private func memoryPressureLevel(for residentMemoryBytes: Int) -> String {
    if residentMemoryBytes >= 256 * 1024 * 1024 {
      return "critical"
    }
    if residentMemoryBytes >= 128 * 1024 * 1024 {
      return "high"
    }
    if residentMemoryBytes >= 64 * 1024 * 1024 {
      return "moderate"
    }
    return residentMemoryBytes == 0 ? "unknown" : "normal"
  }

  private func readJsonFile(at url: URL) -> [String: Any] {
    guard let data = try? Data(contentsOf: url),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return [:]
    }
    return object
  }

  private func log(level: String, source: String, message: String) {
    let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else {
      return
    }

    NSLog("[%@] %@", source, normalized)

    let payload: [String: Any] = [
      "timestamp": ISO8601DateFormatter().string(from: Date()),
      "level": level,
      "source": source,
      "message": normalized,
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let handle = try? FileHandle(forWritingTo: HelperPaths.logURL)
    else {
      return
    }

    handle.seekToEndOfFile()
    handle.write(data)
    handle.write(Data([0x0A]))
    try? handle.close()
  }
}

private final class HelperDaemon {
  private var serverFileDescriptor: Int32 = -1
  private let controller = TunnelController()
  private let queue = DispatchQueue(label: "cc.varpn.easyxray.utun-helper.socket")

  func run() throws {
    try FileManager.default.createDirectory(
      at: HelperPaths.stateDirectory,
      withIntermediateDirectories: true
    )
    try startUnixSocketServer()
    controller.bootstrap()

    queue.async { [weak self] in
      self?.acceptLoop()
    }

    dispatchMain()
  }

  private func startUnixSocketServer() throws {
    if FileManager.default.fileExists(atPath: HelperPaths.socketURL.path) {
      try? FileManager.default.removeItem(at: HelperPaths.socketURL)
    }

    let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      throw HelperError("Failed to create the helper control socket.")
    }
    serverFileDescriptor = fd

    var (address, addressLength) = try unixSocketAddress(for: HelperPaths.socketURL.path)

    let bindResult = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
        Darwin.bind(
          fd,
          sockaddrPointer,
          addressLength
        )
      }
    }

    guard bindResult == 0 else {
      throw HelperError("Failed to bind the helper control socket.")
    }

    guard Darwin.listen(fd, 16) == 0 else {
      throw HelperError("Failed to listen on the helper control socket.")
    }

    chmod(HelperPaths.socketURL.path, 0o666)
  }

  private func unixSocketAddress(for path: String) throws -> (sockaddr_un, socklen_t) {
    var address = sockaddr_un()
    let pathBytes = path.utf8CString
    let maxLength = MemoryLayout.size(ofValue: address.sun_path)
    guard pathBytes.count <= maxLength else {
      throw HelperError("The helper socket path is too long.")
    }

    let sunPathOffset = MemoryLayout<sockaddr_un>.offset(of: \.sun_path) ?? 2
    let addressLength = socklen_t(sunPathOffset + pathBytes.count)
    address.sun_len = UInt8(addressLength)
    address.sun_family = sa_family_t(AF_UNIX)

    withUnsafeMutableBytes(of: &address.sun_path) { buffer in
      buffer.initializeMemory(as: CChar.self, repeating: 0)
      buffer.copyBytes(from: pathBytes.map(UInt8.init(bitPattern:)))
    }

    return (address, addressLength)
  }

  private func acceptLoop() {
    while true {
      let clientFD = Darwin.accept(serverFileDescriptor, nil, nil)
      guard clientFD >= 0 else {
        continue
      }
      handleClient(clientFD)
    }
  }

  private func handleClient(_ clientFD: Int32) {
    defer { Darwin.close(clientFD) }

    var buffer = [UInt8](repeating: 0, count: 65536)
    let bytesRead = Darwin.read(clientFD, &buffer, buffer.count)
    guard bytesRead > 0 else {
      return
    }

    let data = Data(buffer.prefix(bytesRead))

    let response: [String: Any]
    do {
      guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw HelperError("The helper command was not a JSON object.")
      }
      let command = readString(object["command"]) ?? ""
      let arguments = object["arguments"] as? [String: Any] ?? [:]
      let result = try dispatch(command: command, arguments: arguments)
      response = ["ok": true, "result": result]
    } catch {
      response = [
        "ok": false,
        "error": error.localizedDescription,
      ]
    }

    guard let responseData = try? JSONSerialization.data(withJSONObject: response) else {
      return
    }
    _ = responseData.withUnsafeBytes { rawBuffer in
      Darwin.write(clientFD, rawBuffer.baseAddress, responseData.count)
    }
  }

  private func dispatch(
    command: String,
    arguments: [String: Any]
  ) throws -> Any {
    switch command {
    case "helperStatus":
      return controller.helperStatus()
    case "startTunnel":
      return try controller.startTunnel(arguments: arguments)
    case "stopTunnel":
      return try controller.stopTunnel()
    case "tunnelStatus":
      return ["status": controller.tunnelStatus()]
    case "nativeLogEntries":
      return controller.nativeLogEntries()
    case "trafficStats":
      return controller.trafficStats()
    case "tunnelHealth":
      return controller.tunnelHealth()
    case "clearNativeLogs":
      controller.clearNativeLogs()
      return [:]
    case "repairTunnel":
      return try controller.repairTunnel()
    default:
      throw HelperError("Unsupported helper command: \(command)")
    }
  }
}

private struct HelperError: LocalizedError {
  let description: String

  init(_ description: String) {
    self.description = description
  }

  var errorDescription: String? {
    description
  }
}

private func readString(_ value: Any?) -> String? {
  switch value {
  case let value as String:
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  case let value?:
    let trimmed = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  case nil:
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
    switch value.lowercased() {
    case "true":
      return true
    case "false":
      return false
    default:
      return nil
    }
  default:
    return nil
  }
}

private func readInt(_ value: Any?) -> Int? {
  switch value {
  case let value as Int:
    return value
  case let value as NSNumber:
    return value.intValue
  case let value as String:
    return Int(value)
  default:
    return nil
  }
}

private func readInt64(_ value: Any?) -> Int64? {
  switch value {
  case let value as Int64:
    return value
  case let value as Int:
    return Int64(value)
  case let value as NSNumber:
    return value.int64Value
  case let value as String:
    return Int64(value)
  default:
    return nil
  }
}

do {
  let daemon = HelperDaemon()
  try daemon.run()
} catch {
  fputs("VarPN utun helper failed: \(error.localizedDescription)\n", stderr)
  exit(1)
}
