//
//  ScanModel.swift
//  EnvHub
//
//  Drives a cancellable, off-main scan and turns accepted results into projects.
//

import Foundation
import Observation
import SwiftData
import Core

@MainActor
@Observable
final class ScanModel {
    var deepScan: Bool
    var isScanning = false
    var progress = ScanProgress()
    var results: [DiscoveredProject] = []
    var selected: Set<URL> = []
    var hasScanned = false
    /// How long the last completed (or stopped) scan took.
    private(set) var scanDuration: Duration?
    /// Result folders that are already projects in the sidebar — shown with an
    /// "Added" badge and excluded from the default selection so a re-scan never
    /// re-imports what you already have.
    private(set) var alreadyAdded: Set<URL> = []

    private let scanService: ScanService
    private var task: Task<Void, Never>?
    /// Identity of the latest `run`. A finishing task publishes its results only if it
    /// is still the current run — that's what makes **Stop & Review** work (a stopped
    /// scan publishes the partial results the scanner returns on cancellation) without
    /// a stale run ever clobbering a newer one.
    private var runToken = UUID()
    /// Canonical paths of the projects that existed when the scan started.
    private var existingPaths: Set<String> = []

    init(scanService: ScanService, deepScan: Bool) {
        self.scanService = scanService
        self.deepScan = deepScan
    }

    func isAlreadyAdded(_ project: DiscoveredProject) -> Bool {
        alreadyAdded.contains(project.folder)
    }

    /// The results that would actually be imported (selected and not already added).
    var newSelectionCount: Int { selected.count }

    func run(roots: [URL], baseConfig: ScanConfig, existingProjectPaths: Set<String>) {
        guard !roots.isEmpty else { return }
        task?.cancel()
        runToken = UUID()
        let token = runToken

        isScanning = true
        hasScanned = true
        results = []
        selected = []
        alreadyAdded = []
        progress = ScanProgress()
        scanDuration = nil
        existingPaths = existingProjectPaths

        var config = baseConfig
        config.deepScan = deepScan
        let service = scanService
        let clock = ContinuousClock()
        let start = clock.now
        // Progress crosses actors via a Sendable stream, so the @Sendable onProgress
        // closure never captures this @MainActor model. The scanner throttles updates,
        // so the stream stays shallow.
        let (stream, continuation) = AsyncStream.makeStream(of: ScanProgress.self)

        // `scan` is `@concurrent`, so the (parallel) filesystem walk runs off the main
        // actor while this task is suspended — the UI stays responsive.
        task = Task {
            let consumer = Task {
                for await update in stream { self.progress = update }
            }
            let found = await service.scan(roots: roots, config: config) { update in
                continuation.yield(update)
            }
            continuation.finish()
            await consumer.value
            guard token == runToken else { return }   // superseded by a newer run

            let added = Set(found.map(\.folder).filter {
                self.existingPaths.contains(ProjectStore.canonicalPath(for: $0))
            })
            results = found
            alreadyAdded = added
            selected = Set(found.map(\.folder)).subtracting(added)   // preselect only NEW folders
            scanDuration = clock.now - start
            isScanning = false
        }
    }

    /// Stop the walk and review what it found so far. The scanner returns its partial
    /// results on cancellation and the run task above publishes them.
    func stop() {
        task?.cancel()
    }

    /// Adds every selected discovered project (duplicates are ignored by
    /// `ProjectStore`), optionally straight into a workspace.
    @discardableResult
    func addSelectedProjects(to context: ModelContext, workspaceID: UUID? = nil) -> Int {
        var added = 0
        for project in results where selected.contains(project.folder) {
            if ProjectStore.addProject(at: project.folder, to: context, workspaceID: workspaceID) != nil {
                added += 1
            }
        }
        return added
    }
}
