import AppKit

if Snapshot.runIfRequested() { exit(0) }

// A second copy would put a second timer in the menu bar.
if let bundleID = Bundle.main.bundleIdentifier,
   NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
       .contains(where: { $0 != .current }) {
    exit(0)
}

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
