import Foundation
import SwiftUI

@Observable
final class FileNode: Identifiable, @unchecked Sendable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    var size: Int64
    var children: [FileNode]
    weak var parent: FileNode?
    var category: FileCategory
    var modificationDate: Date?
    var isAccessible: Bool = true
    var fileCount: Int = 0
    private var _cachedDominantCategory: FileCategory?
    private var _cachedIcon: NSImage?

    /// Lazy URL — only constructed when needed for file operations (delete, open, etc.)
    var url: URL { URL(fileURLWithPath: path, isDirectory: isDirectory) }

    var pathExtension: String {
        guard let dotIdx = name.lastIndex(of: ".") else { return "" }
        return String(name[name.index(after: dotIdx)...])
    }

    var parentPath: String {
        (path as NSString).deletingLastPathComponent
    }

    init(name: String, path: String, isDirectory: Bool, size: Int64 = 0, children: [FileNode] = []) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.children = children
        self.category = isDirectory ? .other : FileCategory.categorize(name: name, path: path)
    }

    var formattedSize: String {
        SizeFormatter.format(bytes: size)
    }

    var icon: NSImage {
        if let cached = _cachedIcon { return cached }
        let img = NSWorkspace.shared.icon(forFile: path)
        _cachedIcon = img
        return img
    }

    /// Non-recursive, cached. Only looks at direct children's categories.
    var dominantCategory: FileCategory {
        if let cached = _cachedDominantCategory { return cached }
        guard isDirectory, !children.isEmpty else { return category }
        var categorySizes: [FileCategory: Int64] = [:]
        for child in children.prefix(50) {
            categorySizes[child.category, default: 0] += child.size
        }
        let result = categorySizes.max(by: { $0.value < $1.value })?.key ?? .other
        _cachedDominantCategory = result
        return result
    }

    func invalidateCategoryCache() {
        _cachedDominantCategory = nil
    }

    var displayColor: Color {
        isDirectory ? dominantCategory.color : category.color
    }
}

extension FileNode: Hashable {
    static func == (lhs: FileNode, rhs: FileNode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
