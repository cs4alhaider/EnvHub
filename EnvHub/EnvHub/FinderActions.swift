//
//  FinderActions.swift
//  EnvHub
//
//  Small helpers for revealing / opening folders in Finder and copying paths.
//

import AppKit

enum FinderActions {
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path(percentEncoded: false), forType: .string)
    }
}
