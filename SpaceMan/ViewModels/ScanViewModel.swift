import Foundation
import SwiftUI

@MainActor
@Observable
final class ScanViewModel {
    var rootNode: FileNode?
    var currentNode: FileNode?
    var selectedNode: FileNode?
    var hoveredNode: FileNode?
    var selectedNodes: Set<UUID> = []
    private var lastClickedNodeId: UUID?
    var isScanning = false
    var scanProgress: Int = 0
    var scanCurrentPath: String = ""
    var scanBytesProcessed: Int64 = 0
    var scanDuration: TimeInterval = 0
    var navigationStack: [FileNode] = []

    var totalDiskSpace: Int64 = 0
    var freeDiskSpace: Int64 = 0
    var usedDiskSpace: Int64 = 0
    var categoryBreakdown: [StorageInfo.CategorySize] = []

    private var scanTask: Task<Void, Never>?
    var selectedLargeFileCategory: FileCategory?

    @ObservationIgnored private var _cachedLargeFiles: [FileNode]?
    @ObservationIgnored private var _cachedLargeFilesByCategory: [FileCategory: [FileNode]]?
    @ObservationIgnored private var _cachedCategoryStats: [LargeFileCategoryStat]?

    private static let largeFileThreshold: Int64 = 104_857_600 // 100 MB

    struct LargeFileCategoryStat: Identifiable {
        let category: FileCategory
        let count: Int
        let size: Int64
        var id: FileCategory { category }
    }

    var largeFiles: [FileNode] {
        if let cached = _cachedLargeFiles { return cached }
        guard let root = rootNode else { return [] }
        var result: [FileNode] = []
        Self.collectLargeFiles(node: root, threshold: Self.largeFileThreshold, into: &result)
        result.sort { $0.size > $1.size }
        _cachedLargeFiles = result
        return result
    }

    var largeFileCategoryStats: [LargeFileCategoryStat] {
        if let cached = _cachedCategoryStats { return cached }
        let files = largeFiles
        var counts: [FileCategory: Int] = [:]
        var sizes: [FileCategory: Int64] = [:]
        for file in files {
            counts[file.category, default: 0] += 1
            sizes[file.category, default: 0] += file.size
        }
        let result = counts
            .sorted { $0.value > $1.value }
            .map { LargeFileCategoryStat(category: $0.key, count: $0.value, size: sizes[$0.key] ?? 0) }
        _cachedCategoryStats = result
        return result
    }

    func largeFilesFiltered(by category: FileCategory?) -> [FileNode] {
        guard let category else { return largeFiles }
        if _cachedLargeFilesByCategory == nil {
            var grouped: [FileCategory: [FileNode]] = [:]
            for file in largeFiles {
                grouped[file.category, default: []].append(file)
            }
            _cachedLargeFilesByCategory = grouped
        }
        return _cachedLargeFilesByCategory?[category] ?? []
    }

    private static func collectLargeFiles(node: FileNode, threshold: Int64, into result: inout [FileNode]) {
        if !node.isDirectory {
            if node.size >= threshold {
                result.append(node)
            }
            return
        }
        for child in node.children {
            collectLargeFiles(node: child, threshold: threshold, into: &result)
        }
    }

    var currentChildren: [FileNode] {
        currentNode?.children ?? []
    }

    var breadcrumbPath: [FileNode] {
        var path = navigationStack
        if let current = currentNode {
            path.append(current)
        }
        return path
    }

    var canGoBack: Bool {
        !navigationStack.isEmpty
    }

    var hasMultiSelection: Bool {
        selectedNodes.count > 1
    }

    var selectedFileNodes: [FileNode] {
        guard let current = currentNode else { return [] }
        return current.children.filter { selectedNodes.contains($0.id) }
    }

    var multiSelectionTotalSize: Int64 {
        selectedFileNodes.reduce(0) { $0 + $1.size }
    }

    func startScan(at url: URL? = nil) {
        scanTask?.cancel()

        let scanURL = url ?? AppSettings.defaultScanURL
        let threadCount = AppSettings.scanThreadCount
        let includeHidden = AppSettings.includeHiddenFiles
        let minimumFileSize = Int64(AppSettings.minimumFileSize)
        let skipPackageContents = AppSettings.skipPackageContents
        let skipSymlinks = AppSettings.skipSymlinks
        let crossVolumeScan = AppSettings.crossVolumeScan

        // Build excluded directory names set
        var excludedDirNames = Set<String>()
        if AppSettings.excludeNodeModules { excludedDirNames.insert("node_modules") }
        if AppSettings.excludeDerivedData { excludedDirNames.insert("DerivedData") }
        if AppSettings.excludeGitDirs { excludedDirNames.insert(".git") }

        isScanning = true
        scanProgress = 0
        scanCurrentPath = ""
        scanBytesProcessed = 0
        scanDuration = 0
        rootNode = nil
        currentNode = nil
        selectedNode = nil
        selectedNodes.removeAll()
        lastClickedNodeId = nil
        _cachedLargeFiles = nil
        _cachedLargeFilesByCategory = nil
        _cachedCategoryStats = nil
        selectedLargeFileCategory = nil
        navigationStack = []
        updateStorageInfo()

        let scanStart = Date()

        scanTask = Task.detached { [weak self] in
            let scanner = DiskScanner(
                maxConcurrency: threadCount,
                includeHiddenFiles: includeHidden,
                minimumFileSize: minimumFileSize,
                skipPackageContents: skipPackageContents,
                excludedDirNames: excludedDirNames,
                skipSymlinks: skipSymlinks,
                crossVolumeScan: crossVolumeScan
            )
            let result = await scanner.scan(url: scanURL) { count, path, bytes in
                Task { @MainActor [weak self] in
                    self?.scanProgress = count
                    self?.scanCurrentPath = path
                    self?.scanBytesProcessed = bytes
                }
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.rootNode = result
                self.currentNode = result
                self.isScanning = false
                self.scanDuration = Date().timeIntervalSince(scanStart)
                self.categoryBreakdown = StorageInfoService.computeCategories(from: result)
            }
        }
    }

    func stopScan() {
        scanTask?.cancel()
        isScanning = false
    }

    func navigateInto(_ node: FileNode) {
        guard node.isDirectory else { return }
        if let current = currentNode {
            navigationStack.append(current)
        }
        currentNode = node
        selectedNode = nil
        selectedNodes.removeAll()
        lastClickedNodeId = nil
    }

    func navigateBack() {
        guard let previous = navigationStack.popLast() else { return }
        currentNode = previous
        selectedNode = nil
        selectedNodes.removeAll()
        lastClickedNodeId = nil
    }

    func navigateToRoot() {
        guard let root = rootNode else { return }
        navigationStack.removeAll()
        currentNode = root
        selectedNode = nil
        selectedNodes.removeAll()
        lastClickedNodeId = nil
    }

    func navigateToBreadcrumb(_ node: FileNode) {
        if let index = navigationStack.firstIndex(where: { $0.id == node.id }) {
            currentNode = node
            navigationStack = Array(navigationStack.prefix(index))
            selectedNode = nil
            selectedNodes.removeAll()
            lastClickedNodeId = nil
        } else if node.id == currentNode?.id {
            // Already here
        }
    }

    func selectSingle(_ node: FileNode) {
        selectedNodes = [node.id]
        selectedNode = node
        lastClickedNodeId = node.id
    }

    func toggleSelection(_ node: FileNode) {
        if selectedNodes.contains(node.id) {
            selectedNodes.remove(node.id)
            if selectedNode?.id == node.id {
                if let firstId = selectedNodes.first,
                   let firstNode = currentNode?.children.first(where: { $0.id == firstId }) {
                    selectedNode = firstNode
                } else {
                    selectedNode = nil
                }
            }
        } else {
            selectedNodes.insert(node.id)
            selectedNode = node
        }
        lastClickedNodeId = node.id
    }

    func selectRange(to node: FileNode) {
        guard let children = currentNode?.children,
              let lastId = lastClickedNodeId,
              let lastIndex = children.firstIndex(where: { $0.id == lastId }),
              let targetIndex = children.firstIndex(where: { $0.id == node.id })
        else {
            selectSingle(node)
            return
        }

        let range = min(lastIndex, targetIndex)...max(lastIndex, targetIndex)
        for i in range {
            selectedNodes.insert(children[i].id)
        }
        selectedNode = node
    }

    func clearSelection() {
        selectedNodes.removeAll()
        selectedNode = nil
        lastClickedNodeId = nil
    }

    func handleClick(_ node: FileNode, isCommandDown: Bool, isShiftDown: Bool) {
        if isShiftDown {
            selectRange(to: node)
        } else if isCommandDown {
            toggleSelection(node)
        } else {
            selectSingle(node)
        }
    }

    func deleteSelected() async -> Bool {
        guard let node = selectedNode else { return false }
        let success = await FileDeleter.moveToTrash(node: node)
        if success {
            removeFromTree(node)
            selectedNode = nil
            selectedNodes.removeAll()
            lastClickedNodeId = nil
            updateStorageInfo()
        }
        return success
    }

    func purgeSelected() async -> Bool {
        guard let node = selectedNode else { return false }
        let success = await FileDeleter.purge(node: node)
        if success {
            removeFromTree(node)
            selectedNode = nil
            selectedNodes.removeAll()
            lastClickedNodeId = nil
            updateStorageInfo()
        }
        return success
    }

    func permanentlyDeleteSelected() async -> Bool {
        guard let node = selectedNode else { return false }
        let success = await FileDeleter.permanentDelete(node: node)
        if success {
            removeFromTree(node)
            selectedNode = nil
            selectedNodes.removeAll()
            lastClickedNodeId = nil
            updateStorageInfo()
        }
        return success
    }

    func deleteSelectedNodes() async {
        let nodes = selectedFileNodes
        guard !nodes.isEmpty else { return }
        for node in nodes {
            let success = await FileDeleter.moveToTrash(node: node)
            if success {
                removeFromTree(node)
                selectedNodes.remove(node.id)
            }
        }
        selectedNode = nil
        selectedNodes.removeAll()
        lastClickedNodeId = nil
        updateStorageInfo()
    }

    func permanentlyDeleteSelectedNodes() async {
        let nodes = selectedFileNodes
        guard !nodes.isEmpty else { return }
        for node in nodes {
            let success = await FileDeleter.permanentDelete(node: node)
            if success {
                removeFromTree(node)
                selectedNodes.remove(node.id)
            }
        }
        selectedNode = nil
        selectedNodes.removeAll()
        lastClickedNodeId = nil
        updateStorageInfo()
    }

    func purgeSelectedNodes() async {
        let nodes = selectedFileNodes
        guard !nodes.isEmpty else { return }
        for node in nodes {
            let success: Bool
            if node.pathExtension == "app" {
                success = await FileDeleter.purge(node: node)
            } else {
                success = await FileDeleter.permanentDelete(node: node)
            }
            if success {
                removeFromTree(node)
                selectedNodes.remove(node.id)
            }
        }
        selectedNode = nil
        selectedNodes.removeAll()
        lastClickedNodeId = nil
        updateStorageInfo()
    }

    func removeFromTree(_ node: FileNode) {
        guard let parent = node.parent else { return }
        parent.children.removeAll { $0.id == node.id }

        var current: FileNode? = parent
        while let p = current {
            p.size -= node.size
            p.fileCount -= node.fileCount
            current = p.parent
        }

        categoryBreakdown = StorageInfoService.computeCategories(from: rootNode)
        _cachedLargeFiles = nil
        _cachedLargeFilesByCategory = nil
        _cachedCategoryStats = nil
    }

    private func updateStorageInfo() {
        let info = StorageInfoService.getStorageInfo()
        totalDiskSpace = info.totalSpace
        freeDiskSpace = info.freeSpace
        usedDiskSpace = info.usedSpace
    }
}
