import Foundation
import CryptoKit

enum DuplicateFinder {

    // MARK: - Configuration

    struct ScanConfig: Sendable {
        let urls: [URL]
        let minimumFileSize: Int64
        let includeHiddenFiles: Bool
        let excludedPaths: Set<String>

        static let defaultExcludedPaths: Set<String> = [
            "/System", "/Library", "/private", "/Applications",
            "/usr", "/bin", "/sbin", "/var"
        ]

        init(
            urls: [URL],
            minimumFileSize: Int64 = 4096,
            includeHiddenFiles: Bool = false,
            excludedPaths: Set<String> = defaultExcludedPaths
        ) {
            self.urls = urls
            self.minimumFileSize = minimumFileSize
            self.includeHiddenFiles = includeHiddenFiles
            self.excludedPaths = excludedPaths
        }
    }

    // MARK: - Progress

    struct Progress: Sendable {
        var phase: Phase
        var filesEnumerated: Int
        var sizeCandidates: Int
        var filesHashed: Int
        var bytesHashed: Int64
        var currentPath: String

        enum Phase: Sendable {
            case enumerating
            case hashing
        }
    }

    // MARK: - Internal types

    private struct FileEntry: Sendable {
        let url: URL
        let name: String
        let size: Int64
        let modificationDate: Date?
    }

    // MARK: - Public API

    static func scan(
        config: ScanConfig,
        onProgress: @escaping @Sendable (Progress) -> Void
    ) async -> [DuplicateGroup] {
        // Phase 1: Enumerate and group by size
        let sizeGroups = await enumerateFiles(config: config, onProgress: onProgress)

        if Task.isCancelled { return [] }

        // Phase 2: Hash candidates and group by hash
        let results = await hashCandidates(
            sizeGroups: sizeGroups,
            onProgress: onProgress
        )

        return results
    }

    // MARK: - Phase 1: Enumeration

    private static func enumerateFiles(
        config: ScanConfig,
        onProgress: @escaping @Sendable (Progress) -> Void
    ) async -> [[FileEntry]] {
        var filesBySize: [Int64: [FileEntry]] = [:]
        var enumerated = 0

        let fm = FileManager.default
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey]

        for url in config.urls {
            guard !Task.isCancelled else { return [] }

            guard let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: config.includeHiddenFiles ? [] : [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard !Task.isCancelled else { return [] }

                // Check excluded paths
                let path = fileURL.path
                if config.excludedPaths.contains(where: { path.hasPrefix($0) }) {
                    enumerator.skipDescendants()
                    continue
                }

                guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }

                // Skip symlinks and directories
                if values.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    continue
                }
                guard values.isRegularFile == true else { continue }

                let size = Int64(values.fileSize ?? 0)
                if size < config.minimumFileSize { continue }

                let entry = FileEntry(
                    url: fileURL,
                    name: fileURL.lastPathComponent,
                    size: size,
                    modificationDate: values.contentModificationDate
                )

                filesBySize[size, default: []].append(entry)

                enumerated += 1
                if enumerated % 2000 == 0 {
                    onProgress(Progress(
                        phase: .enumerating,
                        filesEnumerated: enumerated,
                        sizeCandidates: 0,
                        filesHashed: 0,
                        bytesHashed: 0,
                        currentPath: path
                    ))
                }
            }
        }

        // Filter to groups with 2+ files of the same size
        let candidates = filesBySize.values.filter { $0.count >= 2 }

        let totalCandidates = candidates.reduce(0) { $0 + $1.count }
        onProgress(Progress(
            phase: .enumerating,
            filesEnumerated: enumerated,
            sizeCandidates: totalCandidates,
            filesHashed: 0,
            bytesHashed: 0,
            currentPath: ""
        ))

        return candidates
    }

    // MARK: - Phase 2: Hashing

    private static func hashCandidates(
        sizeGroups: [[FileEntry]],
        onProgress: @escaping @Sendable (Progress) -> Void
    ) async -> [DuplicateGroup] {
        let totalCandidates = sizeGroups.reduce(0) { $0 + $1.count }
        let hashed = ManagedAtomic(0)
        let bytesHashed = ManagedAtomic64(0)

        // Flatten all candidate files
        let allEntries: [(entry: FileEntry, groupSize: Int64)] = sizeGroups.flatMap { group in
            let size = group.first?.size ?? 0
            return group.map { ($0, size) }
        }

        // Hash with throttled concurrency
        let maxConcurrency = min(8, ProcessInfo.processInfo.activeProcessorCount)
        var hashResults: [(entry: FileEntry, hash: String)] = []

        await withTaskGroup(of: (FileEntry, String?).self) { group in
            var running = 0

            for (entry, _) in allEntries {
                if Task.isCancelled { break }

                if running >= maxConcurrency {
                    if let (completedEntry, completedHash) = await group.next() {
                        running -= 1
                        if let h = completedHash {
                            hashResults.append((completedEntry, h))
                        }
                    }
                }

                group.addTask {
                    guard !Task.isCancelled else { return (entry, nil) }
                    let hash = Self.sha256(url: entry.url)
                    let count = hashed.increment()
                    let bytes = bytesHashed.add(entry.size)

                    if count % 50 == 0 || count == totalCandidates {
                        onProgress(Progress(
                            phase: .hashing,
                            filesEnumerated: 0,
                            sizeCandidates: totalCandidates,
                            filesHashed: count,
                            bytesHashed: bytes,
                            currentPath: entry.url.path
                        ))
                    }

                    return (entry, hash)
                }
                running += 1
            }

            // Collect remaining
            for await (completedEntry, completedHash) in group {
                if let h = completedHash {
                    hashResults.append((completedEntry, h))
                }
            }
        }

        // Group by hash
        var byHash: [String: [FileEntry]] = [:]
        for (entry, hash) in hashResults {
            byHash[hash, default: []].append(entry)
        }

        // Build DuplicateGroup results (only groups with 2+ files)
        var groups: [DuplicateGroup] = []
        for (hash, entries) in byHash where entries.count >= 2 {
            let files = entries.map { entry in
                DuplicateFile(
                    url: entry.url,
                    name: entry.name,
                    size: entry.size,
                    modificationDate: entry.modificationDate,
                    category: FileCategory.categorize(name: entry.name, path: entry.url.path)
                )
            }

            // Recommend keeping the newest file
            let newest = files.max(by: { ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast) })

            groups.append(DuplicateGroup(
                hash: hash,
                fileSize: entries.first?.size ?? 0,
                files: files,
                recommendedKeep: newest?.id ?? files[0].id
            ))
        }

        // Sort by wasted space descending
        groups.sort { $0.wastedSize > $1.wastedSize }

        return groups
    }

    // MARK: - SHA256 streaming hash

    private static func sha256(url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        let bufferSize = 64 * 1024 // 64 KB chunks

        while autoreleasepool(invoking: {
            guard !Task.isCancelled else { return false }
            let data = handle.readData(ofLength: bufferSize)
            if data.isEmpty { return false }
            hasher.update(data: data)
            return true
        }) {}

        if Task.isCancelled { return nil }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Lock-free atomics (minimal, no external deps)

private final class ManagedAtomic: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int

    init(_ initial: Int) { self.value = initial }

    func increment() -> Int {
        lock.lock()
        value += 1
        let v = value
        lock.unlock()
        return v
    }
}

private final class ManagedAtomic64: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int64

    init(_ initial: Int64) { self.value = initial }

    func add(_ amount: Int64) -> Int64 {
        lock.lock()
        value += amount
        let v = value
        lock.unlock()
        return v
    }
}
