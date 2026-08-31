import AppKit
import SwiftUI
import PomodoroCore

/// The menu bar item and the popover hanging off it.
///
/// The title is drawn in the system label colour. Colouring it by phase was
/// tried and dropped: a permanently tinted menu bar reads as an alert, and the
/// tint fights the highlight the menu bar paints while the item is open.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {

    private let item: NSStatusItem
    private let popover = NSPopover()
    private let timer: TimerController
    private let config: AppConfig
    private let store: SettingsStore

    init(
        timer: TimerController,
        store: SettingsStore,
        config: AppConfig,
        openSettings: @escaping () -> Void
    ) {
        self.timer = timer
        self.store = store
        self.config = config
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        popover.behavior = .transient          // closes when you click elsewhere
        popover.animates = false
        popover.contentSize = NSSize(width: config.popover.width, height: config.popover.height)
        popover.contentViewController = NSHostingController(
            rootView: TimerPopoverView(
                timer: timer,
                config: config,
                openSettings: { [weak self] in
                    self?.popover.performClose(nil)
                    openSettings()
                },
                quit: { NSApp.terminate(nil) }
            )
        )

        item.button?.target = self
        item.button?.action = #selector(togglePopover)

        timer.onChange = { [weak self] in self?.refresh() }
        refresh()
    }

    // MARK: - Title

    private func refresh() {
        guard let button = item.button else { return }

        guard store.settings.general.showTimerInMenuBar else {
            button.attributedTitle = NSAttributedString(string: "")
            button.image = tomatoIcon
            return
        }
        button.image = nil

        let size = config.menuBar.fontSize
        let font = config.menuBar.monospacedDigits
            ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
            : NSFont.systemFont(ofSize: size)

        button.attributedTitle = NSAttributedString(
            string: timer.timeText,
            attributes: [.font: font]
        )
    }

    /// Shown instead of the digits when the user hides the timer.
    private var tomatoIcon: NSImage? {
        let image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Pomodoro")
        image?.isTemplate = true
        return image
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = item.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
