import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
    // retain a strong reference to prevent deallocation
    private var keySenderPlugin: KeySenderPlugin?

    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        RegisterGeneratedPlugins(registry: flutterViewController)

        // register our native key sender plugin with the flutter engine
        keySenderPlugin = KeySenderPlugin(
            messenger: flutterViewController.engine.binaryMessenger
        )

        // set minimum window size for usability
        self.minSize = NSSize(width: 700, height: 600)

        super.awakeFromNib()
    }
}
