import Foundation

enum SmartCleanRuleEngine {

    // MARK: - Convert DuplicateFinder results

    static func classifyDuplicates(_ groups: [DuplicateGroup]) -> [CleanableItem] {
        var items: [CleanableItem] = []
        for group in groups {
            for file in group.files {
                let isKeep = file.id == group.recommendedKeep
                if isKeep { continue } // Skip the one we recommend keeping

                items.append(CleanableItem(
                    url: file.url,
                    name: file.name,
                    size: file.size,
                    category: .duplicates,
                    reason: "Duplicate — \(group.files.count) copies",
                    risk: .safe,
                    source: .duplicateFinder,
                    modificationDate: file.modificationDate,
                    isSelected: true
                ))
            }
        }
        return items
    }

    // MARK: - Convert AppScanner results to cache/app-data items

    static func classifyAppData(_ apps: [AppInfo]) -> [CleanableItem] {
        var items: [CleanableItem] = []
        let safeCategories: Set<String> = ["Caches", "HTTP Storage", "Logs", "WebKit"]
        let reviewCategories: Set<String> = ["Application Support", "Saved State", "Containers"]

        for app in apps {
            // Skip currently running apps entirely
            if app.isRunning { continue }

            for related in app.relatedFiles {
                guard related.size > 0 else { continue }

                let isSafe = safeCategories.contains(related.category)
                let isReview = reviewCategories.contains(related.category)

                // Skip Preferences — too risky to auto-clean
                if related.category == "Preferences" { continue }

                let risk: CleanRisk = isSafe ? .safe : (isReview ? .review : .risky)

                items.append(CleanableItem(
                    url: related.url,
                    name: "\(app.name) — \(related.category)",
                    size: related.size,
                    category: isSafe ? .caches : .appData,
                    reason: "\(related.category) for \(app.name)",
                    risk: risk,
                    source: .appScanner,
                    modificationDate: nil,
                    isSelected: risk == .safe
                ))
            }
        }
        return items
    }

    // MARK: - Convert ForgottenFilesScanner results

    static func classifyForgottenFiles(_ items: [ForgottenFileItem]) -> [CleanableItem] {
        items.map { item in
            CleanableItem(
                url: item.url,
                name: item.name,
                size: item.size,
                category: .largeOld,
                reason: "Not opened in \(item.ageBucket.label.lowercased())",
                risk: item.isRecommended ? .safe : .review,
                source: .forgottenFiles,
                modificationDate: item.lastModified,
                isSelected: item.isRecommended
            )
        }
    }
}
