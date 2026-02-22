import Foundation
import AppKit

enum AppScanner {
    /// Scans /Applications for .app bundles and finds their related Library data.
    static func scan(progress: @escaping (Int, String) -> Void) async -> [AppInfo] {
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(
            at: applicationsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let appURLs = contents.filter { $0.pathExtension == "app" }
        var apps: [AppInfo] = []

        for (index, appURL) in appURLs.enumerated() {
            if Task.isCancelled { break }

            let name = appURL.deletingPathExtension().lastPathComponent
            progress(index + 1, name)

            guard let bundle = Bundle(url: appURL),
                  let bundleId = bundle.bundleIdentifier else { continue }

            // NSWorkspace.shared.icon() must be called on the main thread
            let icon = await MainActor.run {
                let img = NSWorkspace.shared.icon(forFile: appURL.path)
                img.size = NSSize(width: 64, height: 64)
                return img
            }

            let appSize = directorySize(at: appURL)
            let relatedFiles = findRelatedFiles(bundleId: bundleId)

            let appInfo = AppInfo(
                name: name,
                bundleIdentifier: bundleId,
                url: appURL,
                icon: icon,
                appSize: appSize,
                relatedFiles: relatedFiles
            )
            apps.append(appInfo)

            if index % 5 == 0 {
                await Task.yield()
            }
        }

        return apps.sorted { $0.totalSize > $1.totalSize }
    }

    /// Calculate total size of a directory recursively.
    static func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    /// Find related Library files for a given bundle identifier.
    static func findRelatedFiles(bundleId: String) -> [RelatedFile] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library")
        let fm = FileManager.default

        let searchPaths: [(String, URL)] = [
            ("Caches", library.appendingPathComponent("Caches/\(bundleId)")),
            ("Application Support", library.appendingPathComponent("Application Support/\(bundleId)")),
            ("Preferences", library.appendingPathComponent("Preferences/\(bundleId).plist")),
            ("HTTP Storage", library.appendingPathComponent("HTTPStorages/\(bundleId)")),
            ("WebKit", library.appendingPathComponent("WebKit/\(bundleId)")),
            ("Saved State", library.appendingPathComponent("Saved Application State/\(bundleId).savedState")),
            ("Containers", library.appendingPathComponent("Containers/\(bundleId)")),
            ("Logs", library.appendingPathComponent("Logs/\(bundleId)")),
        ]

        var results: [RelatedFile] = []

        for (category, path) in searchPaths {
            guard fm.fileExists(atPath: path.path) else { continue }
            let size = directorySize(at: path)
            // For single files (like .plist), use file size directly
            let finalSize = size > 0 ? size : fileSize(at: path)
            if finalSize > 0 {
                results.append(RelatedFile(url: path, category: category, size: finalSize))
            }
        }

        // Check Group Containers
        let groupContainers = library.appendingPathComponent("Group Containers")
        if let groupContents = try? fm.contentsOfDirectory(at: groupContainers, includingPropertiesForKeys: nil) {
            for item in groupContents where item.lastPathComponent.contains(bundleId) {
                let size = directorySize(at: item)
                if size > 0 {
                    results.append(RelatedFile(url: item, category: "Group Containers", size: size))
                }
            }
        }

        return results.sorted { $0.size > $1.size }
    }

    /// Get file size for a single file (not directory).
    private static func fileSize(at url: URL) -> Int64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return 0 }
        return size
    }
}
