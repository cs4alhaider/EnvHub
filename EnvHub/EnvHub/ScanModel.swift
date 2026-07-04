//
//  ScanModel.swift
//  EnvHub
//
//  Drives a cancellable, off-main scan and turns accepted results into projects.
//

import SwiftUI
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

    private let scanService: ScanService
    private var task: Task<Void, Never>?

    init(scanService: ScanService, deepScan: Bool) {
        self.scanService = scanService
        self.deepScan = deepScan
    }

    func run(roots: [URL], baseConfig: ScanConfig) {
        guard !roots.isEmpty else { return }
        cancel()
        isScanning = true
        hasScanned = true
        results = []
        selected = []
        progress = ScanProgress()

        var config = baseConfig
        config.deepScan = deepScan
        let service = scanService
        // Progress crosses actors via a Sendable stream, so the @Sendable onProgress
        // closure never captures this @MainActor model.
        let (stream, continuation) = AsyncStream.makeStream(of: ScanProgress.self)

        // This Task inherits @MainActor isolation, but `scan` is a nonisolated async
        // function, so its filesystem walk runs off the main actor while the await is
        // suspended — the UI stays responsive.
        task = Task {
            let consumer = Task { @MainActor in
                for await update in stream { self.progress = update }
            }
            let found = await service.scan(roots: roots, config: config) { update in
                continuation.yield(update)
            }
            continuation.finish()
            await consumer.value
            if !Task.isCancelled {
                self.results = found
                self.selected = Set(found.map(\.folder))
            }
            self.isScanning = false
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isScanning = false
    }

    @discardableResult
    func addSelectedProjects(to context: ModelContext) -> Int {
        var added = 0
        for project in results where selected.contains(project.folder) {
            if ProjectStore.addProject(at: project.folder, to: context) != nil { added += 1 }
        }
        return added
    }
}
