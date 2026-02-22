import Foundation

enum DownloadsScanner {
    /// Extensions considered "installer clutter" — safe to remove
    static let installerExtensions: Set<String> = ["dmg", "pkg", "iso"]

    /// Extensions considered "archive clutter" — needs review
    static let archiveExtensions: Set<String> = ["zip", "tar", "gz", "bz2", "7z", "rar", "xz", "tgz"]

    /// Age threshold for "large old file" classification (90 days)
    static let largeOldAgeDays: Int = 90

    /// Size threshold for "large old file" classification (100 MB)
    static let largeOldSizeThreshold: Int64 = 100 * 1024 * 1024

    /// Age threshold for installers to be considered clutter (7 days)
    static let installerAgeDays: Int = 7

    static func scan(
        onProgress: @escaping @Sendable (Int, String) -> Void
    ) async -> [CleanableItem] {
        let downloadsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")

        guard FileManager.default.fileExists(atPath: downloadsURL.path) else { return [] }

        var results: [CleanableItem] = []
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey, .isRegularFileKey]
        let now = Date()

        guard let enumerator = fm.enumerator(
            at: downloadsURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var count = 0
        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }

            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)),
                  resourceValues.isRegularFile == true,
                  let fileSize = resourceValues.fileSize,
                  fileSize > 0 else { continue }

            let size = Int64(fileSize)
            let modDate = resourceValues.contentModificationDate
            let name = fileURL.lastPathComponent
            let ext = fileURL.pathExtension.lowercased()

            count += 1
            if count % 50 == 0 {
                onProgress(count, fileURL.lastPathComponent)
            }

            let daysSinceModified: Int = {
                guard let mod = modDate else { return 0 }
                return Calendar.current.dateComponents([.day], from: mod, to: now).day ?? 0
            }()

            // Installer clutter (.dmg, .pkg, .iso)
            if installerExtensions.contains(ext) && daysSinceModified >= installerAgeDays {
                results.append(CleanableItem(
                    url: fileURL,
                    name: name,
                    size: size,
                    category: .downloads,
                    reason: "\(ext.uppercased()) installer — \(daysSinceModified) days old",
                    risk: .safe,
                    source: .downloadsScanner,
                    modificationDate: modDate,
                    isSelected: true
                ))
                continue
            }

            // Archive clutter (.zip, .tar.gz, etc.)
            if archiveExtensions.contains(ext) && daysSinceModified >= installerAgeDays {
                results.append(CleanableItem(
                    url: fileURL,
                    name: name,
                    size: size,
                    category: .downloads,
                    reason: "Archive — \(daysSinceModified) days old",
                    risk: .review,
                    source: .downloadsScanner,
                    modificationDate: modDate,
                    isSelected: false
                ))
                continue
            }

            // Large old files (>100MB, >90 days)
            if size >= largeOldSizeThreshold && daysSinceModified >= largeOldAgeDays {
                results.append(CleanableItem(
                    url: fileURL,
                    name: name,
                    size: size,
                    category: .largeOld,
                    reason: "Large file — \(SizeFormatter.format(bytes: size)), \(daysSinceModified) days old",
                    risk: .review,
                    source: .downloadsScanner,
                    modificationDate: modDate,
                    isSelected: false
                ))
            }
        }

        onProgress(count, "Done")
        return results.sorted { $0.size > $1.size }
    }
}
