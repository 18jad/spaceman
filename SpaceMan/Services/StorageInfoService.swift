import Foundation

struct StorageInfo {
    let totalSpace: Int64
    let freeSpace: Int64
    var usedSpace: Int64 { totalSpace - freeSpace }

    var categories: [CategorySize]

    struct CategorySize: Identifiable {
        let id = UUID()
        let category: FileCategory
        var size: Int64
    }
}

enum StorageInfoService {
    static func getStorageInfo() -> StorageInfo {
        var total: Int64 = 0
        var free: Int64 = 0

        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            total = (attrs[.systemSize] as? Int64) ?? 0
            free = (attrs[.systemFreeSize] as? Int64) ?? 0
        }

        return StorageInfo(totalSpace: total, freeSpace: free, categories: [])
    }

    static func computeCategories(from rootNode: FileNode?) -> [StorageInfo.CategorySize] {
        guard let root = rootNode else { return [] }

        var categorySizes: [FileCategory: Int64] = [:]
        accumulateCategories(node: root, into: &categorySizes)

        return FileCategory.allCases.compactMap { cat in
            guard let size = categorySizes[cat], size > 0 else { return nil }
            return StorageInfo.CategorySize(category: cat, size: size)
        }.sorted { $0.size > $1.size }
    }

    private static func accumulateCategories(node: FileNode, into result: inout [FileCategory: Int64]) {
        if !node.isDirectory {
            result[node.category, default: 0] += node.size
        }
        for child in node.children {
            accumulateCategories(node: child, into: &result)
        }
    }
}
