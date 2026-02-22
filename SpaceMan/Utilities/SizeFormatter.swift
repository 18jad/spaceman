import Foundation

enum SizeFormatter {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    static func format(bytes: Int64) -> String {
        formatter.string(fromByteCount: bytes)
    }

    static func formatCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    static func formatCompact(_ count: Int) -> String {
        switch count {
        case ..<1_000:
            return "\(count)"
        case ..<10_000:
            let k = Double(count) / 1_000
            let formatted = String(format: "%.1f", k)
            let trimmed = formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
            return "\(trimmed)K"
        case ..<1_000_000:
            return "\(count / 1_000)K"
        default:
            let m = Double(count) / 1_000_000
            let formatted = String(format: "%.1f", m)
            let trimmed = formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
            return "\(trimmed)M"
        }
    }
}
