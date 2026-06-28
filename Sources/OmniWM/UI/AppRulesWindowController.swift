// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import AppKit
import SwiftUI

@MainActor
final class AppRulesWindowController: NSObject, NSWindowDelegate {
    static let shared = AppRulesWindowController()

    private var window: NSWindow?
    private let ownedWindowRegistry = OwnedWindowRegistry.shared
    private let editorState = AppRulesEditorState()

    func show(settings: SettingsStore, controller: WMController) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let appRulesView = AppRulesView(settings: settings, controller: controller, editorState: editorState)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)

        let hosting = NSHostingController(rootView: appRulesView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "App Rules"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.setContentSize(NSSize(width: 1140, height: 870))
        window.minSize = NSSize(width: 880, height: 680)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        ownedWindowRegistry.register(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default
            .addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.ownedWindowRegistry.unregister(window)
                    self?.editorState.isDirty = false
                    self?.window = nil
                }
            }
        self.window = window
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard editorState.isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "Discard unsaved changes?"
        alert.informativeText = "You have unsaved changes to this app rule. Closing the window will discard them."
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            editorState.isDirty = false
            return true
        }
        return false
    }

    func isPointInside(_ point: CGPoint) -> Bool {
        guard let window, window.isVisible else { return false }
        return window.frame.contains(point)
    }
}
