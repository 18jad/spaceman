import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ScanningSettingsTab()
                .tabItem {
                    Label("Scanning", systemImage: "magnifyingglass")
                }

            DisplaySettingsTab()
                .tabItem {
                    Label("Display", systemImage: "rectangle.split.3x3")
                }

            DuplicatesSettingsTab()
                .tabItem {
                    Label("Duplicates", systemImage: "doc.on.doc")
                }

            ForgottenFilesSettingsTab()
                .tabItem {
                    Label("Forgotten Files", systemImage: "hourglass")
                }
        }
        .frame(width: 450)
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {
    @AppStorage(AppSettings.Key.showSplashScreen) private var showSplashScreen = AppSettings.Default.showSplashScreen
    @AppStorage(AppSettings.Key.confirmBeforeDelete) private var confirmBeforeDelete = AppSettings.Default.confirmBeforeDelete

    var body: some View {
        Form {
            Section {
                Toggle("Show splash screen on launch", isOn: $showSplashScreen)
            } footer: {
                Text("Disable to skip the splash animation and go straight to the dashboard.")
            }

            Section {
                Toggle("Confirm before delete", isOn: $confirmBeforeDelete)
            } footer: {
                Text("When enabled, a confirmation dialog appears before trashing or deleting files.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Scanning Tab

private struct ScanningSettingsTab: View {
    @AppStorage(AppSettings.Key.includeHiddenFiles) private var includeHiddenFiles = AppSettings.Default.includeHiddenFiles
    @AppStorage(AppSettings.Key.scanThreadCount) private var scanThreadCount = AppSettings.Default.scanThreadCount
    @AppStorage(AppSettings.Key.defaultScanPath) private var defaultScanPath = AppSettings.Default.defaultScanPath
    @AppStorage(AppSettings.Key.minimumFileSize) private var minimumFileSize = AppSettings.Default.minimumFileSize
    @AppStorage(AppSettings.Key.skipPackageContents) private var skipPackageContents = AppSettings.Default.skipPackageContents
    @AppStorage(AppSettings.Key.excludeNodeModules) private var excludeNodeModules = AppSettings.Default.excludeNodeModules
    @AppStorage(AppSettings.Key.excludeDerivedData) private var excludeDerivedData = AppSettings.Default.excludeDerivedData
    @AppStorage(AppSettings.Key.excludeGitDirs) private var excludeGitDirs = AppSettings.Default.excludeGitDirs
    @AppStorage(AppSettings.Key.skipSymlinks) private var skipSymlinks = AppSettings.Default.skipSymlinks
    @AppStorage(AppSettings.Key.crossVolumeScan) private var crossVolumeScan = AppSettings.Default.crossVolumeScan

    var body: some View {
        Form {
            Section {
                Toggle("Include hidden files", isOn: $includeHiddenFiles)
            } footer: {
                Text("Scan dotfiles like .git, .cache, and .Trash. Disabling this skips hidden files and folders.")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Scan speed")
                        Spacer()
                        Text("\(scanThreadCount) thread\(scanThreadCount == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(value: threadBinding, in: 1...16, step: 1) {
                        EmptyView()
                    } minimumValueLabel: {
                        Text("Slower")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("Faster")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("More threads scan faster but use more CPU and battery.")
            }

            Section {
                Picker("Minimum file size", selection: $minimumFileSize) {
                    Text("None").tag(0)
                    Text("1 KB").tag(1_024)
                    Text("10 KB").tag(10_240)
                    Text("100 KB").tag(102_400)
                    Text("1 MB").tag(1_048_576)
                }

                Toggle("Skip package contents", isOn: $skipPackageContents)

                Toggle("Skip symbolic links", isOn: $skipSymlinks)
            } header: {
                Text("Filtering")
            } footer: {
                Text("Filter out small files, treat app bundles as single items, and skip symlinks to reduce noise.")
            }

            Section {
                Toggle("node_modules", isOn: $excludeNodeModules)
                Toggle("DerivedData", isOn: $excludeDerivedData)
                Toggle(".git", isOn: $excludeGitDirs)
            } header: {
                Text("Excluded Directories")
            } footer: {
                Text("Skip these directories entirely during scanning. Useful for ignoring developer build artifacts.")
            }

            Section {
                Toggle("Scan across volumes", isOn: $crossVolumeScan)
            } header: {
                Text("Advanced")
            } footer: {
                Text("When disabled, the scan stays on the same disk volume. Enable to include mounted drives, disk images, and network shares.")
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default scan location")
                        Text(defaultScanPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    Button("Choose...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        panel.directoryURL = URL(fileURLWithPath: defaultScanPath)
                        if panel.runModal() == .OK, let url = panel.url {
                            defaultScanPath = url.path
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var threadBinding: Binding<Double> {
        Binding(
            get: { Double(scanThreadCount) },
            set: { scanThreadCount = Int($0) }
        )
    }
}

// MARK: - Display Tab

private struct DisplaySettingsTab: View {
    @AppStorage(AppSettings.Key.treemapMaxItems) private var treemapMaxItems = AppSettings.Default.treemapMaxItems
    @AppStorage(AppSettings.Key.showEmptyItems) private var showEmptyItems = AppSettings.Default.showEmptyItems

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Treemap detail level")
                        Spacer()
                        Text("\(treemapMaxItems) items")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(value: itemsBinding, in: 50...500, step: 10) {
                        EmptyView()
                    } minimumValueLabel: {
                        Text("Less")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("More")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Controls how many items are rendered in the treemap. Higher values show more detail but may affect performance.")
            }

            Section {
                Toggle("Show empty items", isOn: $showEmptyItems)
            } footer: {
                Text("Show files and folders with zero bytes in the treemap. When disabled, only items that use disk space are displayed.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var itemsBinding: Binding<Double> {
        Binding(
            get: { Double(treemapMaxItems) },
            set: { treemapMaxItems = Int($0) }
        )
    }
}

// MARK: - Duplicates Tab

private struct DuplicatesSettingsTab: View {
    @AppStorage(AppSettings.Key.duplicatesWarnAllSelected) private var warnAllSelected = AppSettings.Default.duplicatesWarnAllSelected
    @AppStorage(AppSettings.Key.duplicatesConfirmBeforeDelete) private var confirmBeforeDelete = AppSettings.Default.duplicatesConfirmBeforeDelete

    var body: some View {
        Form {
            Section {
                Toggle("Confirm before delete", isOn: $confirmBeforeDelete)
            } footer: {
                Text("Shows a confirmation dialog before moving duplicates to the Trash or permanently deleting them.")
            }

            Section {
                Toggle("Warn when all copies are selected", isOn: $warnAllSelected)
            } footer: {
                Text("Shows a warning popover when you select every copy of a duplicate file, which would remove all versions from your system.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Forgotten Files Tab

private struct ForgottenFilesSettingsTab: View {
    @AppStorage(AppSettings.Key.forgottenFilesMinimumAge) private var minimumAge = AppSettings.Default.forgottenFilesMinimumAge

    private let ageOptions: [(label: String, days: Int)] = [
        ("1 week", 7),
        ("3 months", 90),
        ("6 months", 180),
        ("1 year", 365),
        ("2 years", 730),
        ("5 years", 1825),
    ]

    var body: some View {
        Form {
            Section {
                Picker("Minimum age", selection: $minimumAge) {
                    ForEach(ageOptions, id: \.days) { option in
                        Text(option.label).tag(option.days)
                    }
                }
            } footer: {
                Text("Files that haven't been opened or modified within this period will be flagged as forgotten.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
