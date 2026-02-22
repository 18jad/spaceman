import Foundation

enum ForgottenFilesRuleEngine {

    // MARK: - Extension sets for safe heuristics

    private static let installerExtensions: Set<String> = ["dmg", "pkg", "iso"]
    private static let archiveExtensions: Set<String> = ["zip", "tar", "gz", "bz2", "7z", "rar", "xz", "tgz"]
    private static let screenRecordingExtensions: Set<String> = ["mov"]
    private static let largeVideoExtensions: Set<String> = ["mp4", "mkv", "avi", "wmv", "flv", "webm", "m4v"]
    private static let logExtensions: Set<String> = ["log"]

    /// Large video size threshold: 500 MB
    private static let largeVideoSizeThreshold: Int64 = 500 * 1024 * 1024

    /// Home subdirectories where screen recordings are typically saved
    private static let screenRecordingPaths: [String] = ["/Desktop/", "/Documents/"]

    /// Classify items: set isRecommended based on safe heuristics.
    /// Items are returned sorted by size descending.
    static func classify(_ items: [ForgottenFileItem]) -> [ForgottenFileItem] {
        let calendar = Calendar.current
        let now = Date()

        var classified = items.map { item -> ForgottenFileItem in
            let ext = item.url.pathExtension.lowercased()
            let daysSinceOpened = calendar.dateComponents([.day], from: item.lastOpened, to: now).day ?? 0
            let path = item.url.path
            let recommended = isRecommended(ext: ext, path: path, size: item.size, daysSinceOpened: daysSinceOpened)

            return ForgottenFileItem(
                id: item.id,
                url: item.url,
                name: item.name,
                size: item.size,
                lastOpened: item.lastOpened,
                lastModified: item.lastModified,
                creationDate: item.creationDate,
                ageBucket: item.ageBucket,
                category: item.category,
                isRecommended: recommended,
                isSelected: false
            )
        }

        classified.sort { $0.size > $1.size }
        return classified
    }

    private static func isRecommended(ext: String, path: String, size: Int64, daysSinceOpened: Int) -> Bool {
        // Old installers (6+ months)
        if installerExtensions.contains(ext) && daysSinceOpened >= 180 {
            return true
        }

        // Old archives (1+ year)
        if archiveExtensions.contains(ext) && daysSinceOpened >= 365 {
            return true
        }

        // Old screen recordings in Desktop/Documents (1+ year)
        if screenRecordingExtensions.contains(ext) && daysSinceOpened >= 365 {
            if screenRecordingPaths.contains(where: { path.contains($0) }) {
                return true
            }
        }

        // Large old videos (500MB+, 1+ year)
        if largeVideoExtensions.contains(ext) && size >= largeVideoSizeThreshold && daysSinceOpened >= 365 {
            return true
        }

        // Old log files (6+ months)
        if logExtensions.contains(ext) && daysSinceOpened >= 180 {
            return true
        }

        return false
    }
}
