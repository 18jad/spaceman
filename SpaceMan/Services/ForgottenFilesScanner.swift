import Foundation

enum ForgottenFilesScanner {

    /// Paths to exclude from scanning — system-critical or irrelevant
    private static let excludedPathComponents: [String] = [
        "/Library/",
        ".app/",
        "/System/",
        "/private/",
        ".Trash/",
        "/Applications/",
        "node_modules/",
        ".git/",
        "DerivedData/"
    ]


    static func scan(
        scope: ScanScope,
        minimumAge: Int = 180,
        minimumSize: Int64 = 0,
        onProgress: @escaping @Sendable (Int, String) -> Void
    ) async -> [ForgottenFileItem] {
        var results: [ForgottenFileItem] = []
        let fm = FileManager.default
        let now = Date()
        let calendar = Calendar.current

        let keys: Set<URLResourceKey> = [
            .contentModificationDateKey,
            .contentAccessDateKey,
            .creationDateKey,
            .fileSizeKey,
            .isRegularFileKey,
            .isDirectoryKey
        ]

        for scopeURL in scope.urls {
            guard fm.fileExists(atPath: scopeURL.path) else { continue }

            guard let enumerator = fm.enumerator(
                at: scopeURL,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            var count = 0
            for case let fileURL as URL in enumerator {
                if Task.isCancelled { return results }

                // Progress every 100 files
                count += 1
                if count % 100 == 0 {
                    onProgress(count, fileURL.lastPathComponent)
                }

                // Get resource values
                guard let rv = try? fileURL.resourceValues(forKeys: keys),
                      rv.isRegularFile == true,
                      let fileSize = rv.fileSize,
                      fileSize > 0 else { continue }

                let size = Int64(fileSize)

                // Skip files below minimum size
                if size < minimumSize { continue }

                // Skip excluded paths
                let path = fileURL.path
                if excludedPathComponents.contains(where: { path.contains($0) }) { continue }

                // Get dates
                let modDate = rv.contentModificationDate ?? Date.distantPast
                let accessDate = rv.contentAccessDate ?? modDate
                let creationDate = rv.creationDate
                let lastOpened = max(accessDate, modDate)

                // Calculate days since last opened
                let daysSinceOpened = calendar.dateComponents([.day], from: lastOpened, to: now).day ?? 0

                // Skip files not old enough
                if daysSinceOpened < minimumAge { continue }

                // Determine age bucket
                guard let bucket = AgeBucket.bucket(forDays: daysSinceOpened) else { continue }

                let name = fileURL.lastPathComponent
                let category = FileCategory.categorize(name: name, path: path)

                results.append(ForgottenFileItem(
                    id: UUID(),
                    url: fileURL,
                    name: name,
                    size: size,
                    lastOpened: lastOpened,
                    lastModified: modDate,
                    creationDate: creationDate,
                    ageBucket: bucket,
                    category: category,
                    isRecommended: false,
                    isSelected: false
                ))
            }

            onProgress(count, "Done")
        }

        return results
    }
}
