//
//  ProjectRef.swift
//  EnvHub
//
//  Lightweight identities for the project detail view and its window. A project window
//  can show either a saved project (by ID) or an ad-hoc folder opened via `envhub .`
//  that was never added to the sidebar.
//

import Foundation
import Core

/// The folder ProjectDetailView renders — just enough identity (name + URL) to load
/// and edit it, so the same view works for both saved projects and ad-hoc folders.
struct ProjectRef: Hashable {
    let name: String
    let url: URL
    var path: String { url.path(percentEncoded: false) }

    init(name: String, url: URL) {
        self.name = name
        self.url = url
    }

    init(_ record: ProjectRecord) {
        self.init(name: record.name, url: record.url)
    }

    init(folder url: URL) {
        self.init(name: url.lastPathComponent, url: url)
    }
}

/// What a project window is showing. Keyed value for the "project" `WindowGroup` —
/// `saved` re-uses the existing window for that project; `folder` is an ad-hoc window
/// for a folder that isn't a saved project.
enum ProjectWindowRef: Codable, Hashable {
    case saved(UUID)
    case folder(String)   // canonical path
}
