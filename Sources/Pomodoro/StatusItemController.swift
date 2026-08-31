import AppKit
import SwiftUI
import PomodoroCore

/// The menu bar item, the popover hanging off it, and the right-click menu.
///
/// The digits are drawn in the system label colour — tinting them made the
/// whole menu bar read as an alert and fought the highlight macOS paints on an
/// open item. State is carried by the stopwatch glyph beside them instead,
/// which is also what the reference app does.
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

        popover.behavior = .transient          // closes when you click elsewhere
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
        // Both buttons come through the same action; the event tells them apart.
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        timer.onChange = { [weak self] in self?.refresh() }
        refresh()
    }

    // MARK: - Title

    private func refresh() {
        guard let button = item.button else { return }

        button.image = stateIcon
        let showDigits = store.settings.general.showTimerInMenuBar
        // The glyph never goes away, so there is always something to click.
        button.imagePosition = showDigits ? .imageTrailing : .imageOnly

        guard showDigits else {
            button.attributedTitle = NSAttributedString(string: "")
            return
        }

        let size = config.menuBar.fontSize
        let font = config.menuBar.monospacedDigits
            ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
            : NSFont.systemFont(ofSize: size)

        button.attributedTitle = NSAttributedString(
            string: timer.timeText,
            attributes: [.font: font]
        )
    }

    /// Red while work counts down, green on a break, neutral when stopped.
    private var stateIcon: NSImage? {
        let icon = config.menuBar.icon
        let image = NSImage(
            systemSymbolName: icon.symbolName,
            accessibilityDescription: "Pomodoro"
        )
        // A palette colour only takes effect on a non-template image; a
        // template one is repainted by the menu bar itself.
        image?.isTemplate = false
        return image?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: icon.size, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [iconColor]))
        )
    }

    private var iconColor: NSColor {
        let icon = config.menuBar.icon
        guard timer.isRunning else {
            return Theme.color(icon.idleColor, fallback: .secondaryLabelColor)
        }
        return timer.phase == .work
            ? Theme.color(icon.workColor, fallback: .systemRed)
            : Theme.color(icon.breakColor, fallback: .systemGreen)
    }

    // MARK: - Clicks

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
            // Tab still walks the controls, but nothing is focused on opening,
            // so the popover does not appear with a focus ring already drawn.
            window?.makeFirstResponder(nil)
        }
    }

    /// Built and popped up on the spot rather than assigned to `item.menu`:
    /// a status item with a menu hands *every* click to the menu, and the
    /// left-click popover would stop opening.
    private func showContextMenu() {
        guard let button = item.button else { return }
        popover.performClose(nil)

        let menu = NSMenu()
        menu.addItem(menuItem("Skip interval", #selector(skipInterval)))
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
