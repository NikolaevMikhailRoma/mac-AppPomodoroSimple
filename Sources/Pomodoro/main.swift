import AppKit

// The delegate must be held in a variable and assigned before run(): the
// `delegate` property is weak, so a temporary would be released immediately.
let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
// .accessory: lives in the menu bar, no Dock icon, no main window.
app.setActivationPolicy(.accessory)
app.run()
