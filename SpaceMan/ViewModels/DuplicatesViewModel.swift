import Foundation
import SwiftUI

enum ScanScope: Hashable {
    case home
    case downloads
    case desktop
    case documents
    case pictures
    case movies
    case custom([URL])
    case entireDisk

    var label: String {
        switch self {
        case .home: return "Home Folder"
        case .downloads: return "Downloads"
        case .desktop: return "Desktop"
        case .documents: return "Documents"
        case .pictures: return "Pictures"
        case .movies: return "Movies"
        case .custom(let urls): return urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) folders"
        case .entireDisk: return "Entire Disk"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .desktop: return "menubar.dock.rectangle"
        case .documents: return "doc.fill"
        case .pictures: return "photo.fill"
        case .movies: return "film.fill"
        case .custom: return "folder.fill"
        case .entireDisk: return "internaldrive.fill"
        }
    }

    var urls: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .home: return [home]
        case .downloads: return [home.appendingPathComponent("Downloads")]
        case .desktop: return [home.appendingPathComponent("Desktop")]
        case .documents: return [home.appendingPathComponent("Documents")]
        case .pictures: return [home.appendingPathComponent("Pictures")]
        case .movies: return [home.appendingPathComponent("Movies")]
        case .custom(let urls): return urls
        case .entireDisk: return [URL(fileURLWithPath: "/")]
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .home: hasher.combine("home")
        case .downloads: hasher.combine("downloads")
        case .desktop: hasher.combine("desktop")
        case .documents: hasher.combine("documents")
        case .pictures: hasher.combine("pictures")
        case .movies: hasher.combine("movies")
        case .custom(let urls): hasher.combine(urls)
        case .entireDisk: hasher.combine("entireDisk")
        }
    }

    static func == (lhs: ScanScope, rhs: ScanScope) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home), (.downloads, .downloads), (.desktop, .desktop),
             (.documents, .documents), (.pictures, .pictures), (.movies, .movies),
             (.entireDisk, .entireDisk):
            return true
        case (.custom(let a), .custom(let b)):
            return a == b
        default:
            return false
        }
    }
}

enum DuplicateFilter: String, CaseIterable {
    case all
    case images
    case videos
    case audio
    case archives
    case other

    var label: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .images: return "photo.fill"
        case .videos: return "film.fill"
        case .audio: return "music.note"
        case .archives: return "archivebox.fill"
        case .other: return "questionmark.folder.fill"
        }
    }

    func matches(_ category: FileCategory) -> Bool {
        switch self {
        case .all: return true
        case .images: return category == .image
        case .videos: return category == .video
        case .audio: return category == .audio
        case .archives: return category == .archive
        case .other: return category != .image && category != .video && category != .audio && category != .archive
        }
    }
}

enum DuplicatesState {
    case idle
    case scanning
    case results
    case error(String)
}

@MainActor
@Observable
final class DuplicatesViewModel {
    var state: DuplicatesState = .idle
    var groups: [DuplicateGroup] = []
    var selectedForDeletion: Set<UUID> = []
    var scanScope: ScanScope = .home
    var inaccessiblePaths: [String] = []

    // Progress
    var scanPhase: DuplicateFinder.Progress.Phase = .enumerating
    var filesEnumerated: Int = 0
    var sizeCandidates: Int = 0
    var filesHashed: Int = 0
    var bytesHashed: Int64 = 0
    var currentPath: String = ""

    // Sorting / filtering
    var searchText: String = ""
    var activeFilter: DuplicateFilter = .all
    var isDeleting = false

    private var scanTask: Task<Void, Never>?

    var filteredGroups: [DuplicateGroup] {
        var result = groups

        // Category filter
        if activeFilter != .all {
            result = result.filter { group in
                group.files.contains { activeFilter.matches($0.category) }
            }
        }

        // Search filter
        if !searchText.isEmpty {
            result = result.filter { group in
                group.files.contains { file in
                    file.name.localizedCaseInsensitiveContains(searchText) ||
                    file.url.path.localizedCaseInsensitiveContains(searchText)
                }
            }
        }

        return result
    }

    var totalWastedSize: Int64 {
        groups.reduce(0) { $0 + $1.wastedSize }
    }

    func wastedSize(for filter: DuplicateFilter) -> Int64 {
        if filter == .all { return totalWastedSize }
        return groups
            .filter { group in group.files.contains { filter.matches($0.category) } }
            .reduce(0) { $0 + $1.wastedSize }
    }

    func groupCount(for filter: DuplicateFilter) -> Int {
        if filter == .all { return groups.count }
        return groups.count { group in group.files.contains { filter.matches($0.category) } }
    }

    var selectedDeletionSize: Int64 {
        var total: Int64 = 0
        for group in groups {
            for file in group.files where selectedForDeletion.contains(file.id) {
                total += file.size
            }
        }
        return total
    }

    var selectedDeletionCount: Int {
        selectedForDeletion.count
    }

    // MARK: - Scanning

    func startScan() {
        switch state {
        case .idle, .results, .error:
            break
        case .scanning:
            return
        }

        scanTask?.cancel()
        groups = []
        selectedForDeletion = []
        inaccessiblePaths = []
        filesEnumerated = 0
        sizeCandidates = 0
        filesHashed = 0
        bytesHashed = 0
        currentPath = ""
        scanPhase = .enumerating
        state = .scanning

        let config = DuplicateFinder.ScanConfig(
            urls: scanScope.urls,
            includeHiddenFiles: false,
            excludedPaths: scanScope == .entireDisk ? [] : DuplicateFinder.ScanConfig.defaultExcludedPaths
        )

        scanTask = Task.detached { [weak self] in
            let results = await DuplicateFinder.scan(config: config) { progress in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.scanPhase = progress.phase
                    self.filesEnumerated = progress.filesEnumerated
                    self.sizeCandidates = progress.sizeCandidates
                    self.filesHashed = progress.filesHashed
                    self.bytesHashed = progress.bytesHashed
                    self.currentPath = progress.currentPath
                }
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                if Task.isCancelled {
                    self.state = .idle
                } else {
                    self.groups = results
                    self.state = .results
                }
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        state = .idle
    }

    func resetToIdle() {
        scanTask?.cancel()
        groups = []
        selectedForDeletion = []
        state = .idle
    }

    // MARK: - Selection

    func autoSelectAll() {
        selectedForDeletion.removeAll()
        for group in groups {
            for file in group.files where file.id != group.recommendedKeep {
                selectedForDeletion.insert(file.id)
            }
        }
    }

    func deselectAll() {
        selectedForDeletion.removeAll()
    }

    func toggleSelection(_ fileId: UUID, in group: DuplicateGroup) {
        if selectedForDeletion.contains(fileId) {
            selectedForDeletion.remove(fileId)
        } else {
            selectedForDeletion.insert(fileId)
        }
    }

    func allSelected(in group: DuplicateGroup) -> Bool {
        group.files.allSatisfy { selectedForDeletion.contains($0.id) }
    }

    // MARK: - Deletion

    func deleteSelected() async {
        await removeSelected(permanently: false)
    }

    func permanentlyDeleteSelected() async {
        await removeSelected(permanently: true)
    }

    private func removeSelected(permanently: Bool) async {
        guard !selectedForDeletion.isEmpty else { return }
        isDeleting = true

        var failedPaths: [String] = []

        for fileId in selectedForDeletion {
            for group in groups {
                if let file = group.files.first(where: { $0.id == fileId }) {
                    do {
                        if permanently {
                            try FileManager.default.removeItem(at: file.url)
                        } else {
                            try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                        }
                    } catch {
                        failedPaths.append(file.url.path)
                    }
                    break
                }
            }
        }

        // Remove deleted files from groups
        let removedIds = selectedForDeletion.subtracting(Set(failedPaths.flatMap { path in
            groups.flatMap(\.files).filter { $0.url.path == path }.map(\.id)
        }))

        withAnimation {
            for i in groups.indices.reversed() {
                groups[i].files.removeAll { removedIds.contains($0.id) }
                if groups[i].files.count <= 1 {
                    groups.remove(at: i)
                }
            }
            selectedForDeletion.removeAll()
        }

        isDeleting = false

        if !failedPaths.isEmpty {
            inaccessiblePaths.append(contentsOf: failedPaths)
        }
    }
}
