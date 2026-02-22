import Foundation
import AppKit

struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let url: URL
    let icon: NSImage
    let appSize: Int64
    var relatedFiles: [RelatedFile]

    var totalRelatedSize: Int64 {
        relatedFiles.reduce(0) { $0 + $1.size }
    }

    var totalSize: Int64 {
        appSize + totalRelatedSize
    }

    var selectedRelatedSize: Int64 {
        relatedFiles.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    var isRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty == false
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct RelatedFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let category: String
    let size: Int64
    var isSelected: Bool = true

    static func == (lhs: RelatedFile, rhs: RelatedFile) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
