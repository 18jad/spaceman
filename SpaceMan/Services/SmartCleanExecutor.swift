import Foundation

enum SmartCleanExecutor {

    /// Execute cleanup by trashing all selected items in the plan.
    /// Returns a CleanLogEntry summarizing what was cleaned.
    static func execute(
        plan: SmartCleanPlan,
        onProgress: @escaping @Sendable (Int, Int, String) -> Void
    ) async -> CleanLogEntry {
        let selectedItems = plan.groups.flatMap { $0.items.filter(\.isSelected) }
        let total = selectedItems.count
        var cleaned = 0
        var bytesFreed: Int64 = 0
        var categoriesSet = Set<CleanableCategory>()

        for (index, item) in selectedItems.enumerated() {
            if Task.isCancelled { break }

            onProgress(index + 1, total, item.name)

            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                cleaned += 1
                bytesFreed += item.size
                categoriesSet.insert(item.category)
            } catch {
                // Skip items that fail (permission denied, already deleted, etc.)
                continue
            }
        }

        let entry = CleanLogEntry(
            itemsCleaned: cleaned,
            bytesFreed: bytesFreed,
            categories: Array(categoriesSet)
        )

        // Persist to log
        CleanLog.append(entry)

        return entry
    }
}

// MARK: - CleanLog (persistent storage)

enum CleanLog {
    private static let key = "smartCleanLog"

    static func entries() -> [CleanLogEntry] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([CleanLogEntry].self, from: data)) ?? []
    }

    static func append(_ entry: CleanLogEntry) {
        var log = entries()
        log.insert(entry, at: 0) // Newest first
        if log.count > 50 { log = Array(log.prefix(50)) } // Keep last 50
        if let data = try? JSONEncoder().encode(log) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
