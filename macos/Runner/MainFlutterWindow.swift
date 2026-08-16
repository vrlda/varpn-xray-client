import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    contentViewController = flutterViewController

    RegisterGeneratedPlugins(registry: flutterViewController)
    TunnelBridge.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
