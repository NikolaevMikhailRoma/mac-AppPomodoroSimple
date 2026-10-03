import AppKit
import SwiftUI
import PomodoroCore
import PomodoroConfig

@MainActor
final class StatusItemController: NSObject {
    private let item: NSStatusItem
    private let popover = NSPopover()
    private let timer: TimerController
    private let config: AppConfig
    private let store: SettingsStore
    private let openSettings: () -> Void

    init(
        timer: TimerController,
        store: SettingsStore,
        config: AppConfig,
        openSettings: @escaping () -> Void
    ) {
        self.timer = timer
        self.store = store
        self.config = config
        self.openSettings = openSettings
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        // Where the user ⌘-dragged the icon to survives a restart.
        item.autosaveName = "PomodoroTimer"

        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(
            width: config.popover.width,
            height: config.popover.height
        )
        popover.contentViewController = NSHostingController(
            rootView: TimerPopoverView(
                timer: timer,
                config: config,
                openSettings: { [weak self] in
                    self?.popover.performClose(nil)
                    openSettings()
                }
            )
        )

        item.button?.target = self
        item.button?.action = #selector(handleClick)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        timer.onChange = { [weak self] in self?.refresh() }
        refresh()
    }

    private func refresh() {
        guard let button = item.button else { return }

        button.image = stateIcon
        let showDigits = store.settings.general.showTimerInMenuBar
        button.imagePosition = showDigits ? .imageTrailing : .imageOnly

        guard showDigits else {
            button.attributedTitle = NSAttributedString(string: "")
            return
        }

        let size = config.menuBar.fontSize
        let weight = Theme.weight(named: config.menuBar.fontWeight)
        let font = config.menuBar.monospacedDigits
            ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
            : NSFont.systemFont(ofSize: size, weight: weight)

        button.attributedTitle = NSAttributedString(
            string: timer.timeText,
            attributes: [.font: font, .foregroundColor: NSColor.textColor]
        )
    }

    private var stateIcon: NSImage? {
        Theme.image(config.icons.menuBar, color: iconColor)
    }

    private var iconColor: NSColor {
        let menuBar = config.menuBar
        guard timer.isRunning else {
            return Theme.color(menuBar.idleColor, fallback: .secondaryLabelColor)
        }
        return timer.phase == .work
            ? Theme.color(menuBar.workColor, fallback: .systemRed)
            : Theme.color(menuBar.breakColor, fallback: .systemGreen)
    }

    @objc private func handleClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = item.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            let window = popover.contentViewController?.view.window
            window?.makeKey()
            window?.makeFirstResponder(nil)
        }
    }

    private func showContextMenu() {
        guard let button = item.button else { return }
        popover.performClose(nil)

        let menu = NSMenu()
        menu.addItem(menuItem(timer.skipTitle, #selector(skipInterval)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Settings…", #selector(showSettings)))
        menu.addItem(menuItem("Quit Pomodoro", #selector(quit)))

        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.minY - 4),
            in: button
        )
    }

    private func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        return entry
    }

    @objc private func skipInterval() { timer.skip() }
    @objc private func showSettings() { openSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
}
