//
//  RootView.swift
//  EnvHub
//
//  The top-level sidebar + detail split view, cross-project search, and the owner of
//  the app-wide actions (add/scan/import/new-workspace/welcome). Actions live here —
//  on the window, not the sidebar column — so the toolbar "+" menu and the menu-bar
//  shortcuts keep working when the sidebar collapses.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import Core

// (The openSettings action lives on RootView so the ENVHUB_SHOW_SETTINGS test hook
// can drive the Settings scene without synthetic ⌘, keystrokes.)

/// Wrapper so a picked .envenc URL can drive a `.sheet(item:)`.
struct ImportItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @Query private var projects: [ProjectRecord]
    @Query private var settingsRows: [AppSettings]
    /// Sidebar selection — a set so projects can be multi-selected for bulk
    /// move/remove; the detail pane shows an editor only for a single selection.
    @State private var selection: Set<UUID> = []
    @State private var searchText = ""
    @State private var index = SearchIndex.empty

    // App-wide action state (reachable from the toolbar, menu bar, sidebar empty
    // state, and onboarding).
    @State private var showScan = false
    @State private var importItem: ImportItem?
    @State private var newWorkspaceRequested = false
    @State private var showOnboarding = false
    @State private var showQuickOpen = false
    /// Pre-filled quick-open query (only used by the ENVHUB_QUICK_OPEN test hook).
    @State private var quickOpenSeed = ""
    @State private var showStarPrompt = false
    // Occasional "star on GitHub" nudge, gated on real usage.
    @AppStorage("launchCount") private var launchCount = 0
    /// The launch number at which to next show the star prompt; ≤ 0 means never again.
    @AppStorage("starPromptNextLaunch") private var starPromptNextLaunch = 5
    /// A clicked workspace section shows its dashboard in the detail pane; selecting
    /// any project clears it (and vice versa).
    @State private var dashboardTarget: DashboardTarget?

    /// Environment kinds excluded from search results (Settings → Search).
    private var searchExcludedKinds: Set<String> {
        Set(settingsRows.first?.searchExcludedKinds ?? [])
    }

    /// The user's environment catalog (title/color/order), injected into the view tree.
    private var catalog: EnvironmentCatalog {
        settingsRows.first?.environmentCatalog ?? .builtin
    }

    var body: some View {
        // One search pass per render, shared by the sidebar filter and the results list.
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let excluded = searchExcludedKinds
        let hits = ProjectSearch.search(query, in: index).filter { !excluded.contains($0.kind.rawValue) }
        let actions = AppActions(
            addProject: addProjects,
            newWorkspace: { newWorkspaceRequested = true },
            scan: requestScan,
            importEnvenc: importEnvenc,
            showWelcome: { showOnboarding = true },
            quickOpen: { showQuickOpen = true }
        )

        NavigationSplitView {
            SidebarView(
                selection: $selection,
                newWorkspaceRequested: $newWorkspaceRequested,
                dashboardTarget: $dashboardTarget,
                matchingIDs: matchingIDs(query: query, hits: hits),
                fileCounts: index.fileCounts
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            detail(query: query, hits: hits)
        }
        .frame(minWidth: 860, minHeight: 560)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search projects & keys")
        .toolbar { toolbarContent }
        .environment(\.appActions, actions)
        .environment(\.environmentCatalog, catalog)
        .focusedSceneValue(\.appActions, actions)
        .sheet(isPresented: $showScan) { ScanView() }
        .sheet(item: $importItem) { item in ImportView(fileURL: item.url) }
        .sheet(isPresented: $showOnboarding, onDismiss: markOnboardingSeen) {
            OnboardingView()
        }
        .sheet(isPresented: $showStarPrompt) {
            StarPromptView { outcome in
                switch outcome {
                case .starred, .shared, .dontAsk:
                    starPromptNextLaunch = -1                 // don't nudge again
                case .notNow:
                    starPromptNextLaunch = launchCount + 15   // ask again much later
                }
                showStarPrompt = false
            }
        }
        .overlay { quickOpenOverlay }
        .animation(.snappy(duration: 0.15), value: showQuickOpen)
        .onChange(of: selection) { _, newValue in
            if !newValue.isEmpty { dashboardTarget = nil }
        }
        .task {
            let settings = EnvHubStore.settings(in: context)
            let env = ProcessInfo.processInfo.environment
            // Testing/demo hooks (used by headless smoke tests and screenshot runs):
            // ENVHUB_SKIP_ONBOARDING=1  marks the welcome flow as seen,
            // ENVHUB_ADD_PROJECT=<path> auto-adds (and selects) a project folder,
            // ENVHUB_SELECT_PROJECT=<path> selects an already-added project.
            if env["ENVHUB_SKIP_ONBOARDING"] == "1" {
                settings.hasSeenOnboarding = true
            }
            if !settings.hasSeenOnboarding {
                showOnboarding = true
            }
            if let path = env["ENVHUB_ADD_PROJECT"], !path.isEmpty,
               let added = ProjectStore.addProject(at: URL(filePath: path), to: context) {
                selection = [added.id]
            }
            if let path = env["ENVHUB_SELECT_PROJECT"], !path.isEmpty {
                let canonical = ProjectStore.canonicalPath(for: URL(filePath: path))
                if let match = projects.first(where: { ProjectStore.canonicalPath(for: $0.url) == canonical }) {
                    selection = [match.id]
                }
            }
            if let name = env["ENVHUB_SHOW_DASHBOARD"], !name.isEmpty {
                selection = []
                if name.lowercased() == "others" {
                    dashboardTarget = .others
                } else if let workspace = WorkspaceStore.find(named: name, in: context) {
                    dashboardTarget = .workspace(workspace.id)
                }
            }
            if let seed = env["ENVHUB_QUICK_OPEN"] {
                quickOpenSeed = seed
                showQuickOpen = true
            }
            if env["ENVHUB_SHOW_SETTINGS"] == "1" {
                openSettings()
            }
            if env["ENVHUB_SHOW_ABOUT"] == "1" {
                openWindow(id: "about")
            }
            if env["ENVHUB_SHOW_STAR_PROMPT"] == "1" {
                showStarPrompt = true
            }
            if let path = env["ENVHUB_OPEN_WINDOW"], !path.isEmpty {
                let canonical = ProjectStore.canonicalPath(for: URL(filePath: path))
                if let match = projects.first(where: { ProjectStore.canonicalPath(for: $0.url) == canonical }) {
                    openWindow(id: "project", value: ProjectWindowRef.saved(match.id))
                }
            }
            // Any `envhub .` request queued before the app launched.
            consumePendingOpen()
            // Occasional star nudge — only for real, onboarded usage (never during
            // the test/screenshot launches, which set ENVHUB_SKIP_ONBOARDING).
            if settings.hasSeenOnboarding, env["ENVHUB_SKIP_ONBOARDING"] == nil,
               starPromptNextLaunch > 0, launchCount >= starPromptNextLaunch {
                try? await Task.sleep(for: .seconds(2))   // let the window settle first
                showStarPrompt = true
            }
        }
        .task(id: indexKey) { await rebuildIndex() }
        // `envhub .` while the app is already running: the CLI activates us, which
        // fires didBecomeActive — that's when we pick up the queued folder.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            consumePendingOpen()
        }
    }

    /// Handle a folder queued by the CLI (`envhub add` / `envhub .`).
    /// - `addProject`: add it to the sidebar (if new) and select it.
    /// - `openWindow`: open a project window for it *without* adding — re-using the
    ///   saved project's window when the folder already is one.
    /// A folder with no `.env` files works either way; the detail view offers the
    /// create-a-file flow with type presets.
    private func consumePendingOpen() {
        guard let pending = EnvHubStore.consumePendingOpen() else { return }
        let canonical = ProjectStore.canonicalPath(for: pending.url)
        let existing = projects.first { ProjectStore.canonicalPath(for: $0.url) == canonical }

        switch pending.action {
        case .addProject:
            let record = ProjectStore.addProject(at: pending.url, to: context) ?? existing
            if let record {
                dashboardTarget = nil
                searchText = ""
                selection = [record.id]
            }
        case .openWindow:
            if let existing {
                openWindow(id: "project", value: ProjectWindowRef.saved(existing.id))
            } else {
                openWindow(id: "project", value: ProjectWindowRef.folder(canonical))
            }
        }
    }

    // MARK: Toolbar

    /// One consolidated "+" menu instead of a row of sidebar buttons — attached to the
    /// window (`primaryAction`), so nothing disappears when the sidebar collapses.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Add Project…", systemImage: "folder.badge.plus", action: addProjects)
                Button("New Workspace…", systemImage: "rectangle.stack.badge.plus") {
                    newWorkspaceRequested = true
                }
                Divider()
                Button("Scan for .env Files…", systemImage: "magnifyingglass", action: requestScan)
                Button("Import .envenc…", systemImage: "square.and.arrow.down", action: importEnvenc)
            } label: {
                Label("Add", systemImage: "plus")
            }
            .help("Add a project, create a workspace, scan, or import")
        }
    }

    @ViewBuilder
    private func detail(query: String, hits: [IndexedVariable]) -> some View {
        if !query.isEmpty {
            SearchResultsView(query: query, hits: hits) { projectID, _ in
                selection = [projectID]
                searchText = ""
            }
        } else if let target = dashboardTarget {
            WorkspaceDashboardView(target: target, index: index) { projectID in
                dashboardTarget = nil
                selection = [projectID]
            }
        } else if selection.count == 1, let id = selection.first,
                  let project = projects.first(where: { $0.id == id }) {
            ProjectDetailView(project: ProjectRef(project))
        } else if selection.count > 1 {
            ContentUnavailableView {
                Label("\(selection.count) Projects Selected", systemImage: "square.stack.3d.up")
            } description: {
                Text("Right-click the selection in the sidebar to move the projects to a workspace or remove them.")
            }
        } else {
            ContentUnavailableView {
                Label("No Project Selected", systemImage: "sidebar.left")
            } description: {
                Text("Select a project, add a folder, or scan for .env files.")
            } actions: {
                Button("Add Project…", action: addProjects)
                Button("Scan…", action: requestScan)
            }
        }
    }

    // MARK: Quick Open (⇧⌘O)

    @ViewBuilder
    private var quickOpenOverlay: some View {
        if showQuickOpen {
            ZStack(alignment: .top) {
                // Dimmed backdrop; clicking it dismisses, like Xcode's Open Quickly.
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture { showQuickOpen = false }
                QuickOpenPanel(
                    index: index,
                    projects: projects,
                    excludedKinds: searchExcludedKinds,
                    initialQuery: quickOpenSeed,
                    onOpen: { projectID in
                        showQuickOpen = false
                        dashboardTarget = nil
                        selection = [projectID]
                    },
                    onClose: { showQuickOpen = false }
                )
                .padding(.top, 90)
            }
            .transition(.opacity)
        }
    }

    // MARK: Actions

    private func addProjects() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose one or more folders that contain .env files"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let added = ProjectStore.addProject(at: url, to: context) {
                selection = [added.id]
            }
        }
    }

    /// Present the scan sheet — closing onboarding first when it's in the way
    /// (two sheets can't animate in at once).
    private func requestScan() {
        if showOnboarding {
            markOnboardingSeen()
            showOnboarding = false
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                showScan = true
            }
        } else {
            showScan = true
        }
    }

    private func importEnvenc() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "envenc") ?? .json]
        panel.prompt = "Import"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importItem = ImportItem(url: url)
    }

    private func markOnboardingSeen() {
        EnvHubStore.settings(in: context).hasSeenOnboarding = true
    }

    // MARK: Search

    /// Project IDs that match the query (via variable hits or name/path). `nil` when not
    /// searching, meaning "show everything".
    private func matchingIDs(query: String, hits: [IndexedVariable]) -> Set<UUID>? {
        guard !query.isEmpty else { return nil }
        var ids = Set(hits.map(\.projectID))
        for project in projects where ProjectSearch.projectMatches(query: query, name: project.name, path: project.path) {
            ids.insert(project.id)
        }
        return ids
    }

    // MARK: Index

    /// Everything the index depends on: rebuild when projects are added/removed or the
    /// user edits filename patterns / classification rules in Settings.
    private struct IndexKey: Hashable {
        var projectIDs: [UUID]
        var patterns: [String]
        var rules: [ClassificationRule]
    }

    private var indexKey: IndexKey {
        IndexKey(
            projectIDs: projects.map(\.id),
            patterns: settingsRows.first?.filenamePatterns ?? ScanConfig.defaultFilenamePatterns,
            rules: settingsRows.first?.classificationRules ?? ClassificationRule.defaults
        )
    }

    /// Rebuilds the in-memory search index (reads each project's env files once,
    /// off the main actor — see `SearchIndex.build`).
    private func rebuildIndex() async {
        let sources = projects.map { Project(id: $0.id, name: $0.name, path: $0.url) }
        let settings = EnvHubStore.settings(in: context)
        index = await SearchIndex.build(
            projects: sources,
            rules: settings.classificationRules,
            patterns: settings.filenamePatterns
        )
    }
}
