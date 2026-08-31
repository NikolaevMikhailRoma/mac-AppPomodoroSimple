import AppKit

if Snapshot.runIfRequested() { exit(0) }

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
