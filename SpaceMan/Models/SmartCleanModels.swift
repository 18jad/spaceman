import Foundation
import SwiftUI

// MARK: - Enums

enum CleanableCategory: String, CaseIterable, Codable {
    case duplicates
    case caches
    case downloads
    case appData
    case largeOld

    var label: String {
        switch self {
        case .duplicates: return "Duplicates"
        case .caches: return "Caches & Junk"
        case .downloads: return "Downloads"
        case .appData: return "App Data"
        case .largeOld: return "Large Old Files"
        }
    }

    var icon: String {
        switch self {
        case .duplicates: return "doc.on.doc.fill"
        case .caches: return "xmark.bin.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .appData: return "app.badge.fill"
        case .largeOld: return "archivebox.fill"
        }
    }

    var color: Color {
        switch self {
        case .duplicates: return .purple
        case .caches: return .orange
        case .downloads: return .blue
        case .appData: return .green
        case .largeOld: return .red
        }
    }
}

enum CleanRisk: String, Codable, Comparable {
    case safe
    case review
    case risky

    private var sortOrder: Int {
        switch self {
        case .safe: return 0
        case .review: return 1
        case .risky: return 2
        }
    }

    static func < (lhs: CleanRisk, rhs: CleanRisk) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

enum CleanSource: String, Codable {
    case duplicateFinder
    case appScanner
    case downloadsScanner
    case forgottenFiles
}

// MARK: - CleanableItem

struct CleanableItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let category: CleanableCategory
    let reason: String
    let risk: CleanRisk
    let source: CleanSource
    let modificationDate: Date?
    var isSelected: Bool

    static func == (lhs: CleanableItem, rhs: CleanableItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - CleanableGroup

struct CleanableGroup: Identifiable {
    let id = UUID()
    let category: CleanableCategory
    var items: [CleanableItem]

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var selectedSize: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.size } }
    var selectedCount: Int { items.filter(\.isSelected).count }
    var safeSize: Int64 { items.filter { $0.risk == .safe }.reduce(0) { $0 + $1.size } }
}

// MARK: - SmartCleanPlan

struct SmartCleanPlan {
    var groups: [CleanableGroup]
    let scanDate: Date
    let scanScope: ScanScope

    var totalSize: Int64 { groups.reduce(0) { $0 + $1.totalSize } }
    var totalSelectedSize: Int64 { groups.reduce(0) { $0 + $1.selectedSize } }
    var totalSelectedCount: Int { groups.reduce(0) { $0 + $1.selectedCount } }
    var totalSafeSize: Int64 { groups.reduce(0) { $0 + $1.safeSize } }
}

// MARK: - CleanLogEntry

struct CleanLogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let itemsCleaned: Int
    let bytesFreed: Int64
    let categories: [String]

    init(itemsCleaned: Int, bytesFreed: Int64, categories: [CleanableCategory]) {
        self.id = UUID()
        self.timestamp = Date()
        self.itemsCleaned = itemsCleaned
        self.bytesFreed = bytesFreed
        self.categories = categories.map(\.rawValue)
    }
}

// MARK: - SmartCleanProgress

struct SmartCleanProgress {
    enum Phase: String {
        case downloads = "Scanning Downloads..."
        case appCaches = "Scanning App Caches..."
        case duplicates = "Finding Duplicates..."
        case forgottenFiles = "Finding Forgotten Files..."
    }

    let phase: Phase
    let detail: String
    let itemsFound: Int
}
