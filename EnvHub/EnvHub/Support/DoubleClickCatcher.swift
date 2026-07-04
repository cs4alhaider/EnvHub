//
//  DoubleClickCatcher.swift
//  EnvHub
//
//  Fires an action on a double-click WITHOUT swallowing single clicks — the reliable
//  way to add double-click to a SwiftUI `List` row on macOS. A plain SwiftUI
//  `.onTapGesture(count: 2)` / `.simultaneousGesture` competes with the list's own
//  single-click selection (and `.draggable`), which makes selection intermittent;
//  an AppKit `NSClickGestureRecognizer` with `delaysPrimaryMouseButtonEvents = false`
//  lets single clicks flow straight through to selection.
//

import SwiftUI
import AppKit

struct DoubleClickCatcher: NSViewRepresentable {
    var action: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let recognizer = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.fire)
        )
        recognizer.numberOfClicksRequired = 2
        // Don't delay/consume the primary mouse button — single clicks must still
        // reach the List row for selection.
        recognizer.delaysPrimaryMouseButtonEvents = false
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func fire() { action() }
    }
}

extension View {
    /// Run `action` on double-click, leaving single-click selection intact.
    func onDoubleClick(perform action: @escaping () -> Void) -> some View {
        background(DoubleClickCatcher(action: action))
    }
}
