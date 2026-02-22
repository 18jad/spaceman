import Foundation

enum FileDeleter {
    static func moveToTrash(node: FileNode) async -> Bool {
        do {
            try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
            return true
        } catch {
            print("Failed to trash \(node.path): \(error)")
            return false
        }
    }

    static func permanentDelete(node: FileNode) async -> Bool {
        do {
            try FileManager.default.removeItem(at: node.url)
            return true
        } catch {
            print("Failed to permanently delete \(node.path): \(error)")
            return false
        }
    }

    static func purge(node: FileNode) async -> Bool {
        let relatedURLs = findRelatedFiles(for: node)
        var success = true

        for url in relatedURLs {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Failed to remove \(url.path): \(error)")
                success = false
            }
        }

        do {
            try FileManager.default.removeItem(at: node.url)
        } catch {
            print("Failed to remove \(node.path): \(error)")
            success = false
        }

        return success
    }

    static func findRelatedFiles(for node: FileNode) -> [URL] {
        guard node.pathExtension == "app" else { return [] }

        guard let bundle = Bundle(url: node.url),
              let bundleId = bundle.bundleIdentifier else { return [] }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library")

        let searchPaths = [
            library.appendingPathComponent("Caches/\(bundleId)"),
            library.appendingPathComponent("Application Support/\(bundleId)"),
            library.appendingPathComponent("Preferences/\(bundleId).plist"),
            library.appendingPathComponent("HTTPStorages/\(bundleId)"),
            library.appendingPathComponent("WebKit/\(bundleId)"),
            library.appendingPathComponent("Saved Application State/\(bundleId).savedState"),
            library.appendingPathComponent("Containers/\(bundleId)"),
            library.appendingPathComponent("Logs/\(bundleId)"),
        ]

        let fm = FileManager.default
        var relatedURLs: [URL] = []

        for path in searchPaths {
            if fm.fileExists(atPath: path.path) {
                relatedURLs.append(path)
            }
        }

        let groupContainers = library.appendingPathComponent("Group Containers")
        if let contents = try? fm.contentsOfDirectory(at: groupContainers, includingPropertiesForKeys: nil) {
            for item in contents where item.lastPathComponent.contains(bundleId) {
                relatedURLs.append(item)
            }
        }

        return relatedURLs
    }

    static func totalRelatedSize(for node: FileNode) -> Int64 {
        let urls = findRelatedFiles(for: node)
        var total: Int64 = 0
        let fm = FileManager.default

        for url in urls {
            if let attrs = try? fm.attributesOfItem(atPath: url.path) {
                total += (attrs[.size] as? Int64) ?? 0
            }
            if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                        total += Int64(values.fileSize ?? 0)
                    }
                }
            }
        }

        return total
    }
}
