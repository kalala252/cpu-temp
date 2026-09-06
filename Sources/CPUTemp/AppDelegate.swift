import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let store = SensorStore()
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()

        store.onUpdate = { [weak self] in self?.updateTitle() }
        store.start()
        updateTitle()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
        removeEventMonitor()
    }

    // MARK: - Status bar item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.title = "…℃"
        }
    }

    private func updateTitle() {
        guard let button = statusItem.button else { return }

        let title = NSMutableAttributedString()
        let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        let unitFont = NSFont.systemFont(ofSize: 11, weight: .regular)

        if let temp = store.headline {
            let number = "\(Int(temp.rounded()))"
            title.append(NSAttributedString(string: number, attributes: [
                .foregroundColor: TempColor.nsColor(for: temp),
                .font: numberFont
            ]))
            title.append(NSAttributedString(string: "℃", attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: unitFont
            ]))
        } else {
            title.append(NSAttributedString(string: "--℃", attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: numberFont
            ]))
        }

        button.attributedTitle = title
    }

    // MARK: - Popover

    private func setupPopover() {
        let popover = NSPopover()
        popover.delegate = self
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .aqua)

        let view = PopoverView(store: store) { [weak self] in
            self?.quit()
        }
        let hosting = NSHostingController(rootView: view)
        hosting.view.appearance = NSAppearance(named: .aqua)
        popover.contentViewController = hosting
        self.popover = popover
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        store.refresh()

        let view = PopoverView(store: store) { [weak self] in self?.quit() }
        let hosting = NSHostingController(rootView: view)
        hosting.view.appearance = NSAppearance(named: .aqua)
        popover.contentViewController = hosting

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()

        removeEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        removeEventMonitor()
    }

    func popoverDidClose(_ notification: Notification) {
        removeEventMonitor()
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func quit() {
        closePopover()
        NSApp.terminate(nil)
    }
}
