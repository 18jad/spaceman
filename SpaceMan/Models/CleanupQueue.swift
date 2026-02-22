import Foundation

@MainActor
@Observable
final class CleanupQueue {
    private(set) var items: [FileNode] = []

    var count: Int { items.count }
    var isEmpty: Bool { items.isEmpty }
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }

    private var idSet: Set<UUID> = []

    func contains(_ node: FileNode) -> Bool {
        idSet.contains(node.id)
    }

    func add(_ node: FileNode) {
        guard !idSet.contains(node.id) else { return }
        items.append(node)
        idSet.insert(node.id)
    }

    func remove(_ node: FileNode) {
        items.removeAll { $0.id == node.id }
        idSet.remove(node.id)
    }

    func toggle(_ node: FileNode) {
        if contains(node) { remove(node) } else { add(node) }
    }

    func clear() {
        items.removeAll()
        idSet.removeAll()
    }
}
