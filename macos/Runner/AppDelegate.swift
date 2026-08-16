import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let fixedWindowSize = NSSize(width: 700, height: 540)

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let window = mainFlutterWindow {
      window.setContentSize(fixedWindowSize)
      window.minSize = fixedWindowSize
      window.maxSize = fixedWindowSize
      window.styleMask.insert(.fullSizeContentView)
      window.styleMask.remove(.resizable)
      window.center()
      window.title = "VarPN"
      window.titleVisibility = .hidden
      window.titlebarAppearsTransparent = true
      window.isReleasedWhenClosed = false
      window.makeKeyAndOrderFront(nil)
    }

    super.applicationDidFinishLaunching(notification)
  }
}
