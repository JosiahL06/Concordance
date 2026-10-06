import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Concordance is landscape-tablet-first (design target: Fire HD 10 at
    // 1280x800 logical dp). Open at that size and refuse to shrink below
    // something still usable by a scorekeeper.
    self.setContentSize(NSSize(width: 1280, height: 800))
    self.minSize = NSSize(width: 1024, height: 700)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
