import Foundation
import SwiftUI

// MARK: - AgeBucket

enum AgeBucket: Int, CaseIterable, Comparable, Sendable {
    case recent = 0
    case sixMonths = 1
    case oneYear = 2
    case twoYears = 3
    case fiveYears = 4

    var label: String {
        switch self {
        case .recent: return "1+ Week"
        case .sixMonths: return "6+ Months"
        case .oneYear: return "1+ Year"
        case .twoYears: return "2+ Years"
        case .fiveYears: return "5+ Years"
        }
    }

    var icon: String {
        switch self {
        case .recent: return "clock"
        case .sixMonths: return "clock"
        case .oneYear: return "clock.badge.exclamationmark"
        case .twoYears: return "calendar.badge.clock"
        case .fiveYears: return "calendar.badge.exclamationmark"
        }
    }

    var color: Color {
        switch self {
        case .recent: return .blue
        case .sixMonths: return .yellow
        case .oneYear: return .orange
        case .twoYears: return .red
        case .fiveYears: return .purple
        }
    }

    var minimumDays: Int {
        switch self {
        case .recent: return 7
        case .sixMonths: return 180
        case .oneYear: return 365
        case .twoYears: return 730
        case .fiveYears: return 1825
        }
    }

    static func < (lhs: AgeBucket, rhs: AgeBucket) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Returns the highest matching bucket for the given number of days since last opened.
    static func bucket(forDays days: Int) -> AgeBucket? {
        AgeBucket.allCases.reversed().first { days >= $0.minimumDays }
    }
}

// MARK: - ForgottenFileItem

struct ForgottenFileItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let size: Int64
    let lastOpened: Date
    let lastModified: Date
    let creationDate: Date?
    let ageBucket: AgeBucket
    let category: FileCategory
    let isRecommended: Bool
    var isSelected: Bool

    static func == (lhs: ForgottenFileItem, rhs: ForgottenFileItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - ForgottenFilesSummary

struct ForgottenFilesSummary {
    let totalSize: Int64
    let filesCount: Int
    let safeRecommendedSize: Int64
    let oldestBucket: AgeBucket?

    static let empty = ForgottenFilesSummary(totalSize: 0, filesCount: 0, safeRecommendedSize: 0, oldestBucket: nil)
}
