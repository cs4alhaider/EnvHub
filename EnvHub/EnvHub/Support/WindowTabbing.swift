//
//  WindowTabbing.swift
//  EnvHub
//
//  Native (Finder/Xcode-style) window tabs. SwiftUI has no "open window as a tab"
//  API, so this bridges to AppKit. A tab is a FULL main window — sidebar + detail —
//  with the requested project selected, mirroring Finder, where every tab keeps the
//  whole window chrome. Flow:
//   • "Open in New Tab" queues (host window, project) and opens the "main" scene,
//   • the new RootView reports its NSWindow via WindowAccessor,
//   • the window is adopted into the host's tab group (addTabbedWindow — which also
//     gives drag-to-reorder, tear-off, and Merge All Windows for free) and the
//     project gets selected.
//

import AppKit
import SwiftUI

@MainActor
enum WindowTabbing {
    private struct PendingTab {
        weak var host: NSWindow?
        let projectID: UUID
    }

    private static var pending: [PendingTab] = []

    /// Standalone project windows share one tabbing identifier so the system can
    /// group them (Merge All Windows / system-preference automatic tabbing).
    static let projectTabbingIdentifier = "net.alhaider.EnvHub.project"

    /// Open a new main-window tab showing `projectID`, attached to the key window's
    /// tab group. Always creates a new tab (Finder semantics) — tabs are free-
    /// navigating windows, so they aren't deduplicated per project.
    static func openTab(selecting projectID: UUID, using openWindow: OpenWindowAction) {
        pending.append(PendingTab(host: NSApp.keyWindow ?? NSApp.mainWindow, projectID: projectID))
        openWindow(id: "main")
    }

    /// Called by every RootView as its window appears. Returns the project to select
    /// when the window was spawned by `openTab` (after adopting it into the host's
    /// tab group); nil for ordinary windows (launch, ⌘N, restoration).
    static func adoptPendingTab(_ window: NSWindow) -> UUID? {
        guard !pending.isEmpty else { return nil }
        let request = pending.removeFirst()
        if let host = request.host, host !== window, host.isVisible {
            host.addTabbedWindow(window, ordered: .above)
            window.makeKeyAndOrderFront(nil)
        }
        return request.projectID
    }

    /// Tag a standalone project window so Merge All Windows groups project windows.
    static func markProjectWindow(_ window: NSWindow?) {
        window?.tabbingIdentifier = projectTabbingIdentifier
    }
}

/// Reports the NSWindow hosting a SwiftUI view (nil when the view leaves it).
/// Attach as a `.background`.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ view: TrackingView, context: Context) {}

    final class TrackingView: NSView {
        var onWindow: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow?(window)
        }
    }
}
