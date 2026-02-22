import Foundation
import SwiftUI

enum AppSortOrder: String, CaseIterable {
    case totalSize = "Total Size"
    case appSize = "App Size"
    case dataSize = "Data Size"
    case name = "Name"
}

@MainActor
@Observable
final class AppManagerViewModel {
    var apps: [AppInfo] = []
    var selectedApp: AppInfo?
    var isScanning = false
    var isDeleting = false
    var deletingAppName: String = ""
    var scanProgress: Int = 0
    var scanCurrentApp: String = ""
    var searchText: String = ""
    var sortOrder: AppSortOrder = .totalSize
    var hasScanned = false

    private var scanTask: Task<Void, Never>?

    var filteredApps: [AppInfo] {
        let filtered: [AppInfo]
        if searchText.isEmpty {
            filtered = apps
        } else {
            filtered = apps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOrder {
        case .totalSize: return filtered.sorted { $0.totalSize > $1.totalSize }
        case .appSize: return filtered.sorted { $0.appSize > $1.appSize }
        case .dataSize: return filtered.sorted { $0.totalRelatedSize > $1.totalRelatedSize }
        case .name: return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var totalAppsSize: Int64 {
        apps.reduce(0) { $0 + $1.totalSize }
    }

    func startScan() {
        guard !isScanning else { return }
        scanTask?.cancel()
        isScanning = true
        scanProgress = 0
        scanCurrentApp = ""

        scanTask = Task.detached { [weak self] in
            let results = await AppScanner.scan { count, name in
                Task { @MainActor [weak self] in
                    self?.scanProgress = count
                    self?.scanCurrentApp = name
                }
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.apps = results
                self.isScanning = false
                self.hasScanned = true
            }
        }
    }

    func stopScan() {
        scanTask?.cancel()
        isScanning = false
    }

    func setRelatedFileSelected(appId: UUID, fileId: UUID, selected: Bool) {
        guard let appIndex = apps.firstIndex(where: { $0.id == appId }),
              let fileIndex = apps[appIndex].relatedFiles.firstIndex(where: { $0.id == fileId }) else { return }
        apps[appIndex].relatedFiles[fileIndex].isSelected = selected
        if selectedApp?.id == appId {
            selectedApp = apps[appIndex]
        }
    }

    func deleteApp(_ app: AppInfo, permanently: Bool) async {
        isDeleting = true
        deletingAppName = app.name

        let selectedFiles = app.relatedFiles.filter(\.isSelected)

        // Delete related files first
        for file in selectedFiles {
            do {
                if permanently {
                    try FileManager.default.removeItem(at: file.url)
                } else {
                    try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                }
            } catch {
                print("Failed to delete \(file.url.path): \(error)")
            }
        }

        // Delete the app itself
        do {
            if permanently {
                try FileManager.default.removeItem(at: app.url)
            } else {
                try FileManager.default.trashItem(at: app.url, resultingItemURL: nil)
            }

            // App deleted — remove from list and clear selection
            withAnimation {
                apps.removeAll { $0.id == app.id }
            }
            if selectedApp?.id == app.id {
                selectedApp = nil
            }
        } catch {
            print("Failed to delete \(app.url.path): \(error)")
        }

        isDeleting = false
        deletingAppName = ""
    }
}
