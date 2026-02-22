import Foundation

struct DuplicateFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let modificationDate: Date?
    let category: FileCategory

    static func == (lhs: DuplicateFile, rhs: DuplicateFile) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct DuplicateGroup: Identifiable {
    let id = UUID()
    let hash: String
    let fileSize: Int64
    var files: [DuplicateFile]
    var recommendedKeep: UUID

    var wastedSize: Int64 {
        fileSize * Int64(files.count - 1)
    }

    var wastedCount: Int {
        files.count - 1
    }
}
