import Foundation

enum SmartCleanService {

    static func scan(
        scope: ScanScope,
        onProgress: @escaping @Sendable (SmartCleanProgress) -> Void
    ) async -> SmartCleanPlan {
        var allItems: [CleanableItem] = []

        // Phase 1: Downloads scanner (fast, ~1s)
        onProgress(SmartCleanProgress(phase: .downloads, detail: "Starting...", itemsFound: 0))
        let downloadItems = await DownloadsScanner.scan { count, path in
            onProgress(SmartCleanProgress(phase: .downloads, detail: path, itemsFound: count))
        }
        allItems.append(contentsOf: downloadItems)

        if Task.isCancelled {
            return SmartCleanPlan(groups: [], scanDate: Date(), scanScope: scope)
        }

        // Phase 2: App caches scanner (~2-3s)
        onProgress(SmartCleanProgress(phase: .appCaches, detail: "Starting...", itemsFound: 0))
        let apps = await AppScanner.scan { index, name in
            onProgress(SmartCleanProgress(phase: .appCaches, detail: name, itemsFound: index))
        }
        let appItems = SmartCleanRuleEngine.classifyAppData(apps)
        allItems.append(contentsOf: appItems)

        if Task.isCancelled {
            return SmartCleanPlan(groups: [], scanDate: Date(), scanScope: scope)
        }

        // Phase 3: Duplicates finder (slowest)
        onProgress(SmartCleanProgress(phase: .duplicates, detail: "Starting...", itemsFound: 0))
        let dupConfig = DuplicateFinder.ScanConfig(
            urls: scope.urls,
            includeHiddenFiles: false,
            excludedPaths: DuplicateFinder.ScanConfig.defaultExcludedPaths
        )
        let dupGroups = await DuplicateFinder.scan(config: dupConfig) { progress in
            let detail: String
            switch progress.phase {
            case .enumerating:
                detail = "\(progress.filesEnumerated) files found"
            case .hashing:
                detail = "\(progress.filesHashed)/\(progress.sizeCandidates) hashed"
            }
            onProgress(SmartCleanProgress(phase: .duplicates, detail: detail, itemsFound: progress.filesEnumerated))
        }
        let dupItems = SmartCleanRuleEngine.classifyDuplicates(dupGroups)
        allItems.append(contentsOf: dupItems)

        if Task.isCancelled {
            return SmartCleanPlan(groups: [], scanDate: Date(), scanScope: scope)
        }

        // Phase 4: Forgotten files (age-based)
        onProgress(SmartCleanProgress(phase: .forgottenFiles, detail: "Starting...", itemsFound: 0))
        let rawForgotten = await ForgottenFilesScanner.scan(
            scope: scope,
            minimumAge: 365,
            minimumSize: 0
        ) { count, path in
            onProgress(SmartCleanProgress(phase: .forgottenFiles, detail: path, itemsFound: count))
        }
        let classifiedForgotten = ForgottenFilesRuleEngine.classify(rawForgotten)
        let forgottenItems = SmartCleanRuleEngine.classifyForgottenFiles(classifiedForgotten)
        allItems.append(contentsOf: forgottenItems)

        // Group items by category
        let grouped = Dictionary(grouping: allItems, by: \.category)
        let groups = CleanableCategory.allCases.compactMap { cat -> CleanableGroup? in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return CleanableGroup(category: cat, items: items.sorted { $0.size > $1.size })
        }

        return SmartCleanPlan(groups: groups, scanDate: Date(), scanScope: scope)
    }
}
