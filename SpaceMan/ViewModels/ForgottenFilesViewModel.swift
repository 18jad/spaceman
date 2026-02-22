import Foundation
import SwiftUI

@MainActor
@Observable
final class ForgottenFilesViewModel {

    enum State {
        case idle
        case scanning
        case results
        case empty
        case error(String)
    }

    enum SortOrder {
        case size
        case age
        case name
    }

    var state: State = .idle

    // Scan config
    var scope: ScanScope = .home
    var minimumAgeDays: Int = AppSettings.forgottenFilesMinimumAge
    var minimumSize: Int64 = 0

    // Progress
    var scanProgress: Int = 0
    var scanCurrentPath: String = ""

    // Results
    var items: [ForgottenFileItem] = []
    var selectedItems: Set<UUID> = []
    var sortOrder: SortOrder = .size
    var filterBucket: AgeBucket? = nil
    var searchText: String = ""
    var filterCategory: FileCategory? = nil

    private var scanTask: Task<Void, Never>?

    // MARK: - Computed

    var filteredItems: [ForgottenFileItem] {
        var result = items
        if let bucket = filterBucket {
            result = result.filter { $0.ageBucket == bucket }
        }
        if let category = filterCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(query) }
        }
        switch sortOrder {
        case .size:
            result.sort { $0.size > $1.size }
        case .age:
            result.sort { $0.lastOpened < $1.lastOpened }
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return result
    }

    var totalReclaimableSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var selectedSize: Int64 {
        items.filter { selectedItems.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    var selectedCount: Int {
        selectedItems.count
    }

    var bucketSummaries: [(bucket: AgeBucket, count: Int, size: Int64)] {
        AgeBucket.allCases.compactMap { bucket in
            let matching = items.filter { $0.ageBucket == bucket }
            guard !matching.isEmpty else { return nil }
            let size = matching.reduce(0 as Int64) { $0 + $1.size }
            return (bucket, matching.count, size)
        }
    }

    var presentCategories: [FileCategory] {
        let cats = Set(items.map(\.category))
        return FileCategory.allCases.filter { cats.contains($0) }
    }

    var summary: ForgottenFilesSummary {
        guard !items.isEmpty else { return .empty }
        let recommendedSize = items.filter(\.isRecommended).reduce(0 as Int64) { $0 + $1.size }
        let oldest = items.map(\.ageBucket).max()
        return ForgottenFilesSummary(
            totalSize: totalReclaimableSize,
            filesCount: items.count,
            safeRecommendedSize: recommendedSize,
            oldestBucket: oldest
        )
    }

    // MARK: - Scanning

    func startScan() {
        switch state {
        case .idle, .results, .empty, .error:
            break
        case .scanning:
            return
        }

        scanTask?.cancel()
        items = []
        selectedItems = []
        scanProgress = 0
        scanCurrentPath = ""
        state = .scanning

        // Re-read from settings in case user changed it
        minimumAgeDays = AppSettings.forgottenFilesMinimumAge

        let currentScope = scope
        let minAge = minimumAgeDays
        let minSize = minimumSize

        scanTask = Task.detached { [weak self] in
            let rawItems = await ForgottenFilesScanner.scan(
                scope: currentScope,
                minimumAge: minAge,
                minimumSize: minSize
            ) { count, path in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.scanProgress = count
                    self.scanCurrentPath = path
                }
            }

            let classified = ForgottenFilesRuleEngine.classify(rawItems)

            await MainActor.run { [weak self] in
                guard let self else { return }
                if Task.isCancelled {
                    self.state = .idle
                } else {
                    self.items = classified
                    self.state = classified.isEmpty ? .empty : .results
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
        items = []
        selectedItems = []
        state = .idle
    }

    // MARK: - Selection

    func toggleSelection(_ id: UUID) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }

    func selectAllRecommended() {
        let recommendedIds = Set(items.filter(\.isRecommended).map(\.id))
        selectedItems.formUnion(recommendedIds)
    }

    func selectAll(in bucket: AgeBucket) {
        let bucketIds = items.filter { $0.ageBucket == bucket }.map(\.id)
        selectedItems.formUnion(bucketIds)
    }

    func deselectAll() {
        selectedItems.removeAll()
    }

    // MARK: - Deletion

    func moveSelectedToTrash() async -> Int {
        let toDelete = items.filter { selectedItems.contains($0.id) }
        var deletedIds = Set<UUID>()

        for item in toDelete {
            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                deletedIds.insert(item.id)
            } catch {
                // Skip failures silently
            }
        }

        // Remove successfully deleted items from results
        items.removeAll { deletedIds.contains($0.id) }
        selectedItems.subtract(deletedIds)

        if items.isEmpty {
            state = .idle
        }

        return deletedIds.count
    }
}
