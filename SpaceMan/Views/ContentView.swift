import SwiftUI

enum AppMode {
    case splash
    case onboarding
    case dashboard
    case diskScanner
    case appManager
    case duplicates
    case smartClean
    case forgottenFiles
}

struct ContentView: View {
    @State private var appMode: AppMode = .splash
    @State private var scanViewModel = ScanViewModel()
    @State private var appManagerViewModel = AppManagerViewModel()
    @State private var duplicatesViewModel = DuplicatesViewModel()
    @State private var smartCleanViewModel = SmartCleanViewModel()
    @State private var forgottenFilesViewModel = ForgottenFilesViewModel()
    @State private var showInspector = true
    @Namespace private var heroNamespace

    // Storage info for dashboard (lightweight, no scan needed)
    @State private var totalDiskSpace: Int64 = 0
    @State private var freeDiskSpace: Int64 = 0

    var body: some View {
        Group {
            switch appMode {
            case .splash:
                splashBody
            case .onboarding:
                onboardingBody
            case .dashboard:
                dashboardBody
            case .diskScanner:
                diskScannerBody
            case .appManager:
                appManagerBody
            case .duplicates:
                duplicatesBody
            case .smartClean:
                smartCleanBody
            case .forgottenFiles:
                forgottenFilesBody
            }
        }
        .onAppear {
            let info = StorageInfoService.getStorageInfo()
            totalDiskSpace = info.totalSpace
            freeDiskSpace = info.freeSpace

            // Skip splash if disabled in settings
            if !AppSettings.showSplashScreen && appMode == .splash {
                appMode = AppSettings.hasCompletedOnboarding ? .dashboard : .onboarding
            }
        }
        .onChange(of: appMode) { oldMode, newMode in
            if newMode == .diskScanner && scanViewModel.rootNode == nil && !scanViewModel.isScanning {
                cleanupQueue.clear()
                scanViewModel.startScan()
            }
            if newMode == .appManager && !appManagerViewModel.hasScanned && !appManagerViewModel.isScanning {
                appManagerViewModel.startScan()
            }
        }
    }

    // MARK: - Splash

    private var splashBody: some View {
        SplashView(appMode: $appMode, namespace: heroNamespace)
            .navigationTitle("SpaceMan")
    }

    // MARK: - Onboarding

    private var onboardingBody: some View {
        OnboardingView(appMode: $appMode)
            .navigationTitle("SpaceMan")
    }

    // MARK: - Dashboard

    private var dashboardBody: some View {
        DashboardView(appMode: $appMode, namespace: heroNamespace, totalDiskSpace: totalDiskSpace, freeDiskSpace: freeDiskSpace)
            .navigationTitle("SpaceMan")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    SettingsLink {
                        Label("Settings", systemImage: "gear")
                    }
                    .help("Settings (⌘,)")
                }
            }
    }

    // MARK: - Disk Scanner

    @State private var cleanupQueue = CleanupQueue()
    @State private var showCleanupReview = false
    @State private var showLargeFiles = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @AppStorage(AppSettings.Key.confirmBeforeDelete) private var confirmBeforeDelete = AppSettings.Default.confirmBeforeDelete
    @State private var showToolbarTrashConfirm = false
    @State private var showToolbarDeleteConfirm = false
    @State private var showToolbarPurgeConfirm = false

    private var diskScannerBody: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Group {
                if showLargeFiles {
                    LargeFilesSidebar(scanViewModel: scanViewModel)
                } else {
                    SidebarView(viewModel: scanViewModel, cleanupQueue: cleanupQueue)
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 400)
        } detail: {
            VStack(spacing: 0) {
                StorageBarView(viewModel: scanViewModel)

                Divider()

                if showLargeFiles {
                    LargeFilesView(scanViewModel: scanViewModel, cleanupQueue: cleanupQueue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    BreadcrumbView(viewModel: scanViewModel)

                    Divider()

                    TreemapView(viewModel: scanViewModel, cleanupQueue: cleanupQueue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(8)
                }

                if !cleanupQueue.isEmpty {
                    Divider()
                    QueueBarView(cleanupQueue: cleanupQueue) {
                        showCleanupReview = true
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Divider()

                StatusBarView(viewModel: scanViewModel)
            }
            .animation(.easeInOut(duration: 0.2), value: cleanupQueue.isEmpty)
            .inspector(isPresented: $showInspector) {
                FileDetailView(viewModel: scanViewModel)
                    .inspectorColumnWidth(min: 220, ideal: 280, max: 360)
            }
        }
        .sheet(isPresented: $showCleanupReview) {
            CleanupReviewSheet(cleanupQueue: cleanupQueue, scanViewModel: scanViewModel)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    appMode = .dashboard
                } label: {
                    Image(systemName: "house")
                }
                .help("Back to Dashboard")
            }

            ToolbarItem(placement: .principal) {
                Picker("View", selection: $showLargeFiles) {
                    Text("Treemap")
                        .tag(false)
                    Text("Large Files")
                        .tag(true)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .disabled(scanViewModel.rootNode == nil || scanViewModel.isScanning)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    if scanViewModel.isScanning {
                        scanViewModel.stopScan()
                    } else {
                        cleanupQueue.clear()
                        scanViewModel.startScan()
                    }
                } label: {
                    Label(
                        scanViewModel.isScanning ? "Stop" : "Scan",
                        systemImage: scanViewModel.isScanning ? "stop.fill" : "arrow.clockwise"
                    )
                }
                .help(scanViewModel.isScanning ? "Stop Scan" : "Scan Default Location")

                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.message = "Choose a folder to scan"
                    panel.prompt = "Scan"
                    if panel.runModal() == .OK, let url = panel.url {
                        cleanupQueue.clear()
                        scanViewModel.startScan(at: url)
                    }
                } label: {
                    Label("Scan Folder", systemImage: "folder.badge.questionmark")
                }
                .disabled(scanViewModel.isScanning)
                .help("Choose a folder to scan")

                Menu {
                    if scanViewModel.hasMultiSelection {
                        let count = scanViewModel.selectedFileNodes.count
                        Button {
                            if confirmBeforeDelete {
                                showToolbarTrashConfirm = true
                            } else {
                                Task { await scanViewModel.deleteSelectedNodes() }
                            }
                        } label: {
                            Label("Move \(count) Items to Trash", systemImage: "trash")
                        }

                        Button {
                            if confirmBeforeDelete {
                                showToolbarDeleteConfirm = true
                            } else {
                                Task { await scanViewModel.permanentlyDeleteSelectedNodes() }
                            }
                        } label: {
                            Label("Delete \(count) Items Permanently", systemImage: "xmark.bin")
                        }

                        let hasApps = scanViewModel.selectedFileNodes.contains { $0.pathExtension == "app" }
                        if hasApps {
                            Divider()
                            Button {
                                if confirmBeforeDelete {
                                    showToolbarPurgeConfirm = true
                                } else {
                                    Task { await scanViewModel.purgeSelectedNodes() }
                                }
                            } label: {
                                Label("Purge \(count) Items & Data", systemImage: "flame")
                            }
                        }
                    } else {
                        Button {
                            if confirmBeforeDelete {
                                showToolbarTrashConfirm = true
                            } else {
                                Task { await scanViewModel.deleteSelected() }
                            }
                        } label: {
                            Label("Move to Trash", systemImage: "trash")
                        }

                        Button {
                            if confirmBeforeDelete {
                                showToolbarDeleteConfirm = true
                            } else {
                                Task { await scanViewModel.permanentlyDeleteSelected() }
                            }
                        } label: {
                            Label("Delete Permanently", systemImage: "xmark.bin")
                        }

                        if scanViewModel.selectedNode?.pathExtension == "app" {
                            Divider()
                            Button {
                                if confirmBeforeDelete {
                                    showToolbarPurgeConfirm = true
                                } else {
                                    Task { await scanViewModel.purgeSelected() }
                                }
                            } label: {
                                Label("Purge App & Data", systemImage: "flame")
                            }
                        }
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
                .disabled(scanViewModel.selectedNodes.isEmpty)
                .help("File actions")

                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .help("Toggle Inspector")
            }
        }
        .navigationTitle("Disk Scanner")
        .confirmationDialog("Move to Trash?", isPresented: $showToolbarTrashConfirm, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) {
                if scanViewModel.hasMultiSelection {
                    Task { await scanViewModel.deleteSelectedNodes() }
                } else {
                    Task { await scanViewModel.deleteSelected() }
                }
            }
        } message: {
            if scanViewModel.hasMultiSelection {
                Text("Move \(scanViewModel.selectedFileNodes.count) items (\(SizeFormatter.format(bytes: scanViewModel.multiSelectionTotalSize))) to the Trash?")
            } else {
                Text("Move \"\(scanViewModel.selectedNode?.name ?? "")\" to the Trash?")
            }
        }
        .confirmationDialog("Delete Permanently?", isPresented: $showToolbarDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Permanently", role: .destructive) {
                if scanViewModel.hasMultiSelection {
                    Task { await scanViewModel.permanentlyDeleteSelectedNodes() }
                } else {
                    Task { await scanViewModel.permanentlyDeleteSelected() }
                }
            }
        } message: {
            if scanViewModel.hasMultiSelection {
                Text("Permanently delete \(scanViewModel.selectedFileNodes.count) items (\(SizeFormatter.format(bytes: scanViewModel.multiSelectionTotalSize)))? This cannot be undone.")
            } else {
                Text("This will permanently delete \"\(scanViewModel.selectedNode?.name ?? "")\" and cannot be undone.")
            }
        }
        .confirmationDialog("Purge App & Data?", isPresented: $showToolbarPurgeConfirm, titleVisibility: .visible) {
            Button("Purge Everything", role: .destructive) {
                if scanViewModel.hasMultiSelection {
                    Task { await scanViewModel.purgeSelectedNodes() }
                } else {
                    Task { await scanViewModel.purgeSelected() }
                }
            }
        } message: {
            if scanViewModel.hasMultiSelection {
                Text("Permanently delete \(scanViewModel.selectedFileNodes.count) items (\(SizeFormatter.format(bytes: scanViewModel.multiSelectionTotalSize))) and all related app data?")
            } else {
                Text("Permanently delete \"\(scanViewModel.selectedNode?.name ?? "")\" and all related app data?")
            }
        }
    }

    // MARK: - App Manager

    private var appManagerBody: some View {
        VStack(spacing: 0) {
            AppManagerView(viewModel: appManagerViewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // App manager status bar
            HStack(spacing: 12) {
                if appManagerViewModel.isScanning {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    Text("Scanning: \(SizeFormatter.formatCount(appManagerViewModel.scanProgress)) apps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(appManagerViewModel.scanCurrentApp)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if appManagerViewModel.hasScanned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("\(SizeFormatter.formatCount(appManagerViewModel.apps.count)) apps · \(SizeFormatter.format(bytes: appManagerViewModel.totalAppsSize)) total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let selected = appManagerViewModel.selectedApp {
                    Image(systemName: "app.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(selected.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.bar)
        }
        .inspector(isPresented: $showInspector) {
            AppDetailView(viewModel: appManagerViewModel)
                .inspectorColumnWidth(min: 220, ideal: 280, max: 360)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    appMode = .dashboard
                } label: {
                    Image(systemName: "house.fill")
                }
                .help("Back to Dashboard")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    if appManagerViewModel.isScanning {
                        appManagerViewModel.stopScan()
                    } else {
                        appManagerViewModel.startScan()
                    }
                } label: {
                    Label(
                        appManagerViewModel.isScanning ? "Stop" : "Scan",
                        systemImage: appManagerViewModel.isScanning ? "stop.fill" : "arrow.clockwise"
                    )
                }
                .help(appManagerViewModel.isScanning ? "Stop Scan" : "Scan Applications")

                Divider()

                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .help("Toggle Inspector")
            }
        }
        .navigationTitle("App Manager")
    }

    // MARK: - Duplicates

    @State private var showDuplicatesTrashConfirm = false
    @State private var showDuplicatesDeleteConfirm = false
    @State private var showSmartCleanConfirm = false

    private var duplicatesBody: some View {
        VStack(spacing: 0) {
            DuplicatesView(viewModel: duplicatesViewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Status bar
            HStack(spacing: 12) {
                switch duplicatesViewModel.state {
                case .scanning:
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    switch duplicatesViewModel.scanPhase {
                    case .enumerating:
                        Text("Discovering: \(SizeFormatter.formatCount(duplicatesViewModel.filesEnumerated)) files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .hashing:
                        Text("Hashing: \(SizeFormatter.formatCount(duplicatesViewModel.filesHashed))/\(SizeFormatter.formatCount(duplicatesViewModel.sizeCandidates))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(duplicatesViewModel.currentPath)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                case .results:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("\(SizeFormatter.formatCount(duplicatesViewModel.groups.count)) duplicate groups \u{00B7} \(SizeFormatter.format(bytes: duplicatesViewModel.totalWastedSize)) reclaimable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                default:
                    Text("Duplicates Finder")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.bar)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    duplicatesViewModel.resetToIdle()
                    appMode = .dashboard
                } label: {
                    Image(systemName: "house.fill")
                }
                .help("Back to Dashboard")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if case .results = duplicatesViewModel.state {
                    Button {
                        duplicatesViewModel.autoSelectAll()
                    } label: {
                        Label("Auto-Select", systemImage: "checkmark.circle")
                    }
                    .help("Select all duplicates for removal (keeps newest)")

                    Menu {
                        Button {
                            if AppSettings.duplicatesConfirmBeforeDelete {
                                showDuplicatesTrashConfirm = true
                            } else {
                                Task { await duplicatesViewModel.deleteSelected() }
                            }
                        } label: {
                            Label("Move to Trash", systemImage: "trash")
                        }

                        Button {
                            if AppSettings.duplicatesConfirmBeforeDelete {
                                showDuplicatesDeleteConfirm = true
                            } else {
                                Task { await duplicatesViewModel.permanentlyDeleteSelected() }
                            }
                        } label: {
                            Label("Delete Permanently", systemImage: "xmark.bin")
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(duplicatesViewModel.selectedForDeletion.isEmpty || duplicatesViewModel.isDeleting)
                    .help("Delete selected duplicates")
                }

                if case .scanning = duplicatesViewModel.state {
                    Button {
                        duplicatesViewModel.cancelScan()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .help("Cancel Scan")
                } else {
                    Button {
                        duplicatesViewModel.startScan()
                    } label: {
                        Label("Scan", systemImage: "arrow.clockwise")
                    }
                    .help("Start Duplicate Scan")
                }
            }
        }
        .navigationTitle("Duplicates")
        .confirmationDialog("Move to Trash?", isPresented: $showDuplicatesTrashConfirm, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) {
                Task { await duplicatesViewModel.deleteSelected() }
            }
        } message: {
            Text("Move \(SizeFormatter.formatCount(duplicatesViewModel.selectedDeletionCount)) duplicate files (\(SizeFormatter.format(bytes: duplicatesViewModel.selectedDeletionSize))) to the Trash?")
        }
        .confirmationDialog("Delete Permanently?", isPresented: $showDuplicatesDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Permanently", role: .destructive) {
                Task { await duplicatesViewModel.permanentlyDeleteSelected() }
            }
        } message: {
            Text("Permanently delete \(SizeFormatter.formatCount(duplicatesViewModel.selectedDeletionCount)) duplicate files (\(SizeFormatter.format(bytes: duplicatesViewModel.selectedDeletionSize)))? This cannot be undone.")
        }
    }

    // MARK: - Smart Clean

    private var smartCleanBody: some View {
        VStack(spacing: 0) {
            SmartCleanView(viewModel: smartCleanViewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Status bar
            HStack(spacing: 12) {
                switch smartCleanViewModel.state {
                case .scanning:
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    Text(smartCleanViewModel.scanPhase.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(smartCleanViewModel.scanDetail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                case .results:
                    if let plan = smartCleanViewModel.plan {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("\(SizeFormatter.format(bytes: plan.totalSafeSize)) safe to clean \u{00B7} \(SizeFormatter.format(bytes: plan.totalSize)) total found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .executing:
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    Text("Cleaning: \(smartCleanViewModel.executionCurrent)/\(smartCleanViewModel.executionTotal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .done(let entry):
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.teal)
                    Text("\(entry.itemsCleaned) items cleaned \u{00B7} \(SizeFormatter.format(bytes: entry.bytesFreed)) freed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                default:
                    Text("Smart Clean")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.bar)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    smartCleanViewModel.resetToIdle()
                    appMode = .dashboard
                } label: {
                    Image(systemName: "house.fill")
                }
                .help("Back to Dashboard")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if case .results = smartCleanViewModel.state {
                    Button {
                        smartCleanViewModel.selectAllSafe()
                    } label: {
                        Label("Safe Only", systemImage: "shield.checkered")
                    }
                    .help("Select only safe items")

                    Button {
                        showSmartCleanConfirm = true
                    } label: {
                        Label("Clean", systemImage: "sparkles")
                    }
                    .disabled(smartCleanViewModel.plan?.totalSelectedCount == 0)
                    .help("Move selected items to Trash")
                }

                if case .scanning = smartCleanViewModel.state {
                    Button {
                        smartCleanViewModel.cancelScan()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .help("Cancel Analysis")
                } else if case .executing = smartCleanViewModel.state {
                    Button {
                        smartCleanViewModel.cancelClean()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .help("Cancel Cleanup")
                } else {
                    Button {
                        smartCleanViewModel.startScan()
                    } label: {
                        Label("Analyze", systemImage: "arrow.clockwise")
                    }
                    .help("Start Analysis")
                }

                Button {
                    smartCleanViewModel.showCleanLog.toggle()
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .help("Clean History")
            }
        }
        .navigationTitle("Smart Clean")
        .confirmationDialog("Smart Clean?", isPresented: $showSmartCleanConfirm, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) {
                smartCleanViewModel.executeClean()
            }
        } message: {
            if let plan = smartCleanViewModel.plan {
                Text("Move \(SizeFormatter.formatCount(plan.totalSelectedCount)) items (\(SizeFormatter.format(bytes: plan.totalSelectedSize))) to the Trash?")
            }
        }
        .sheet(isPresented: $smartCleanViewModel.showCleanLog) {
            CleanLogSheet(entries: smartCleanViewModel.cleanLog)
        }
    }

    // MARK: - Forgotten Files

    private var forgottenFilesBody: some View {
        VStack(spacing: 0) {
            ForgottenFilesView(viewModel: forgottenFilesViewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Status bar
            HStack(spacing: 12) {
                switch forgottenFilesViewModel.state {
                case .scanning:
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    Text("Scanning: \(SizeFormatter.formatCount(forgottenFilesViewModel.scanProgress)) files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(forgottenFilesViewModel.scanCurrentPath)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                case .results:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("\(SizeFormatter.formatCount(forgottenFilesViewModel.items.count)) forgotten files \u{00B7} \(SizeFormatter.format(bytes: forgottenFilesViewModel.totalReclaimableSize)) reclaimable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .empty:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("No forgotten files found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                default:
                    Text("Forgotten Files")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.bar)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    forgottenFilesViewModel.resetToIdle()
                    appMode = .dashboard
                } label: {
                    Image(systemName: "house.fill")
                }
                .help("Back to Dashboard")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if case .scanning = forgottenFilesViewModel.state {
                    Button {
                        forgottenFilesViewModel.cancelScan()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .help("Cancel Scan")
                } else {
                    Button {
                        forgottenFilesViewModel.startScan()
                    } label: {
                        Label("Scan", systemImage: "arrow.clockwise")
                    }
                    .help("Start Scan")
                }
            }
        }
        .navigationTitle("Forgotten Files")
    }

}
