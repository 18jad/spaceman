import Foundation

final class DiskScanner: @unchecked Sendable {
    private let maxConcurrency: Int
    private let includeHiddenFiles: Bool
    private let minimumFileSize: Int64
    private let skipPackageContents: Bool
    private let excludedDirNames: Set<String>
    private let skipSymlinks: Bool
    private let crossVolumeScan: Bool

    init(maxConcurrency: Int = AppSettings.Default.scanThreadCount,
         includeHiddenFiles: Bool = AppSettings.Default.includeHiddenFiles,
         minimumFileSize: Int64 = 0,
         skipPackageContents: Bool = AppSettings.Default.skipPackageContents,
         excludedDirNames: Set<String> = [],
         skipSymlinks: Bool = AppSettings.Default.skipSymlinks,
         crossVolumeScan: Bool = AppSettings.Default.crossVolumeScan) {
        self.maxConcurrency = max(1, min(64, maxConcurrency))
        self.includeHiddenFiles = includeHiddenFiles
        self.minimumFileSize = minimumFileSize
        self.skipPackageContents = skipPackageContents
        self.excludedDirNames = excludedDirNames
        self.skipSymlinks = skipSymlinks
        self.crossVolumeScan = crossVolumeScan
    }

    // MARK: - Thread-safe state

    private let lock = NSLock()
    private var _itemCount = 0
    private var _bytesScanned: Int64 = 0
    private var _visitedDirs = Set<DirID>()
    private var _rootDev: dev_t = 0

    private struct DirID: Hashable {
        let dev: dev_t
        let ino: ino_t
    }

    private func addProgress(items: Int, bytes: Int64) -> (Int, Int64) {
        lock.lock()
        _itemCount += items
        _bytesScanned += bytes
        let count = _itemCount
        let total = _bytesScanned
        lock.unlock()
        return (count, total)
    }

    private func tryVisitDir(dev: dev_t, ino: ino_t) -> Bool {
        lock.lock()
        let inserted = _visitedDirs.insert(DirID(dev: dev, ino: ino)).inserted
        lock.unlock()
        return inserted
    }

    // MARK: - Concurrent Work Queue

    /// Lock-based producer-consumer queue. Workers dequeue directories,
    /// scan them, and enqueue discovered subdirectories. When outstanding
    /// count hits zero all work is done.
    private final class WorkQueue: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [FileNode] = []
        private var outstanding = 0
        private let semaphore = DispatchSemaphore(value: 0)
        private var _done = false
        private var _cancelled = false

        var isCancelled: Bool { _cancelled }

        func enqueue(_ node: FileNode) {
            lock.lock()
            items.append(node)
            outstanding += 1
            lock.unlock()
            semaphore.signal()
        }

        func enqueueBatch(_ nodes: [FileNode]) {
            guard !nodes.isEmpty else { return }
            lock.lock()
            items.append(contentsOf: nodes)
            outstanding += nodes.count
            lock.unlock()
            for _ in nodes { semaphore.signal() }
        }

        func dequeue() -> FileNode? {
            semaphore.wait()
            lock.lock()
            if _done || _cancelled {
                lock.unlock()
                semaphore.signal()
                return nil
            }
            let item = items.removeFirst()
            lock.unlock()
            return item
        }

        func markComplete() {
            lock.lock()
            outstanding -= 1
            if outstanding == 0 {
                _done = true
                lock.unlock()
                for _ in 0..<64 { semaphore.signal() }
            } else {
                lock.unlock()
            }
        }

        func cancel() {
            lock.lock()
            _cancelled = true
            _done = true
            lock.unlock()
            for _ in 0..<64 { semaphore.signal() }
        }
    }

    // MARK: - Public API

    func scan(url: URL, onProgress: @escaping @Sendable (Int, String, Int64) -> Void) async -> FileNode? {
        _itemCount = 0
        _bytesScanned = 0
        _visitedDirs.removeAll()

        var rootStat = stat()
        if lstat(url.path, &rootStat) == 0 {
            _rootDev = rootStat.st_dev
        }

        let root = FileNode(name: url.lastPathComponent, path: url.path, isDirectory: true)
        let queue = WorkQueue()
        queue.enqueue(root)

        // Spawn N real GCD threads — no cooperative pool cap
        let group = DispatchGroup()
        let gcdQueue = DispatchQueue(label: "com.spaceman.scanner", attributes: .concurrent)

        for _ in 0..<maxConcurrency {
            group.enter()
            gcdQueue.async { [self] in
                while let dirNode = queue.dequeue() {
                    self.processDirectory(dirNode, queue: queue, onProgress: onProgress)
                    queue.markComplete()
                }
                group.leave()
            }
        }

        // Await GCD completion, propagate task cancellation
        let result: FileNode? = await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                group.notify(queue: gcdQueue) {
                    cont.resume()
                }
            }

            if Task.isCancelled || queue.isCancelled {
                return nil
            }

            Self.computeSizes(root)
            return root
        } onCancel: {
            queue.cancel()
        }

        return result
    }

    // MARK: - Package handling

    private static let packageExtensions: Set<String> = ["app", "framework", "bundle", "plugin", "kext", "xcarchive"]

    @inline(__always)
    private static func isPackageName(_ name: String) -> Bool {
        guard let dotIdx = name.lastIndex(of: ".") else { return false }
        let ext = String(name[name.index(after: dotIdx)...]).lowercased()
        return packageExtensions.contains(ext)
    }

    private static func computeDirectorySize(dir: UnsafeMutablePointer<DIR>, dfd: Int32) -> Int64 {
        var total: Int64 = 0
        while let entry = readdir(dir) {
            let nameLen = Int(entry.pointee.d_namlen)
            if nameLen == 1 && entry.pointee.d_name.0 == 0x2E { continue }
            if nameLen == 2 && entry.pointee.d_name.0 == 0x2E && entry.pointee.d_name.1 == 0x2E { continue }

            let dType = Int32(entry.pointee.d_type)
            if dType == DT_DIR {
                let subfd = withUnsafePointer(to: entry.pointee.d_name) { namePtr in
                    openat(dfd, UnsafeRawPointer(namePtr).assumingMemoryBound(to: CChar.self), O_RDONLY | O_DIRECTORY)
                }
                guard subfd >= 0 else { continue }
                guard let subdir = fdopendir(subfd) else { close(subfd); continue }
                total += computeDirectorySize(dir: subdir, dfd: subfd)
                closedir(subdir)
            } else if dType != DT_LNK {
                var sb = stat()
                let rc = withUnsafePointer(to: entry.pointee.d_name) { namePtr in
                    fstatat(dfd, UnsafeRawPointer(namePtr).assumingMemoryBound(to: CChar.self), &sb, AT_SYMLINK_NOFOLLOW)
                }
                if rc == 0 { total += Int64(sb.st_blocks) * 512 }
            }
        }
        return total
    }

    // MARK: - Worker: scan one directory

    private func processDirectory(
        _ node: FileNode,
        queue: WorkQueue,
        onProgress: @escaping @Sendable (Int, String, Int64) -> Void
    ) {
        let path = node.path

        // Loop detection + cross-volume check
        var dirStat = stat()
        if lstat(path, &dirStat) == 0 {
            if !tryVisitDir(dev: dirStat.st_dev, ino: dirStat.st_ino) { return }
            if !crossVolumeScan && _rootDev != 0 && dirStat.st_dev != _rootDev { return }
        }

        guard let dir = opendir(path) else {
            node.isAccessible = false
            return
        }
        defer { closedir(dir) }

        let dfd = dirfd(dir)
        var fileChildren: [FileNode] = []
        var dirChildren: [FileNode] = []
        var batchItems = 0
        var batchBytes: Int64 = 0

        while let entryPtr = readdir(dir) {
            if queue.isCancelled { return }

            let dType = Int32(entryPtr.pointee.d_type)
            let nameLen = Int(entryPtr.pointee.d_namlen)

            if nameLen == 1 && entryPtr.pointee.d_name.0 == 0x2E { continue }
            if nameLen == 2 && entryPtr.pointee.d_name.0 == 0x2E && entryPtr.pointee.d_name.1 == 0x2E { continue }
            if !includeHiddenFiles && entryPtr.pointee.d_name.0 == 0x2E { continue }

            var resolvedType = dType
            var haveStat = false
            var sb = stat()

            if resolvedType == DT_UNKNOWN {
                let rc = withUnsafePointer(to: entryPtr.pointee.d_name) { namePtr in
                    fstatat(dfd, UnsafeRawPointer(namePtr).assumingMemoryBound(to: CChar.self), &sb, AT_SYMLINK_NOFOLLOW)
                }
                if rc == 0 {
                    haveStat = true
                    let mode = sb.st_mode & S_IFMT
                    if mode == S_IFDIR { resolvedType = DT_DIR }
                    else if mode == S_IFLNK { resolvedType = DT_LNK }
                    else { resolvedType = DT_REG }
                } else {
                    continue
                }
            }

            if resolvedType == DT_LNK {
                if skipSymlinks { continue }
                let name = Self.entryName(entryPtr)
                let child = FileNode(name: name, path: "\(path)/\(name)", isDirectory: false, size: 0)
                child.parent = node
                fileChildren.append(child)
                batchItems += 1
                continue
            }

            if resolvedType == DT_DIR {
                let name = Self.entryName(entryPtr)
                if !excludedDirNames.isEmpty && excludedDirNames.contains(name) { continue }

                let childPath = "\(path)/\(name)"

                if skipPackageContents && Self.isPackageName(name) {
                    guard let pkgDir = opendir(childPath) else {
                        batchItems += 1
                        continue
                    }
                    let pkgFd = dirfd(pkgDir)
                    let packageSize = Self.computeDirectorySize(dir: pkgDir, dfd: pkgFd)
                    closedir(pkgDir)

                    let child = FileNode(name: name, path: childPath, isDirectory: true)
                    child.parent = node
                    child.size = packageSize
                    child.fileCount = 1
                    fileChildren.append(child)
                    batchItems += 1
                    batchBytes += packageSize
                    continue
                }

                let child = FileNode(name: name, path: childPath, isDirectory: true)
                child.parent = node
                dirChildren.append(child)
                batchItems += 1
                continue
            }

            // Regular file
            if !haveStat {
                let rc = withUnsafePointer(to: entryPtr.pointee.d_name) { namePtr in
                    fstatat(dfd, UnsafeRawPointer(namePtr).assumingMemoryBound(to: CChar.self), &sb, AT_SYMLINK_NOFOLLOW)
                }
                if rc != 0 { continue }
            }

            let fileSize = Int64(sb.st_blocks) * 512
            if minimumFileSize > 0 && fileSize < minimumFileSize { continue }

            let name = Self.entryName(entryPtr)
            let child = FileNode(name: name, path: "\(path)/\(name)", isDirectory: false, size: fileSize)
            child.parent = node

            let sec = sb.st_mtimespec.tv_sec
            if sec > 0 {
                child.modificationDate = Date(timeIntervalSince1970: TimeInterval(sec))
            }

            fileChildren.append(child)
            batchItems += 1
            batchBytes += fileSize
        }

        // Attach children (unsorted — computeSizes sorts after sizes are final)
        var allChildren = fileChildren
        allChildren.append(contentsOf: dirChildren)
        node.children = allChildren

        if batchItems > 0 {
            let (count, total) = addProgress(items: batchItems, bytes: batchBytes)
            if count % 5000 < batchItems {
                onProgress(count, path, total)
            }
        }

        // Feed subdirectories back into the queue for other workers
        queue.enqueueBatch(dirChildren)
    }

    // MARK: - Post-processing

    /// Walk tree bottom-up: accumulate sizes, counts, and sort children.
    private static func computeSizes(_ node: FileNode) {
        guard !node.children.isEmpty else { return } // Preserve pre-set sizes (packages)

        var totalSize: Int64 = 0
        var totalCount = 0

        for child in node.children {
            if child.isDirectory {
                computeSizes(child)
            }
            totalSize += child.size
            totalCount += child.isDirectory ? (child.fileCount + 1) : 1 // +1 counts the dir itself
        }

        node.size = totalSize
        node.fileCount = totalCount
        node.children.sort { $0.size > $1.size }
    }

    // MARK: - Helpers

    @inline(__always)
    private static func entryName(_ entry: UnsafeMutablePointer<dirent>) -> String {
        var nameBuf = entry.pointee.d_name
        return withUnsafePointer(to: &nameBuf) { ptr in
            String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
        }
    }
}
