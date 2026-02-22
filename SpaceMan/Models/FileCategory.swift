import SwiftUI

enum FileCategory: String, CaseIterable, Sendable {
    case app
    case image
    case video
    case audio
    case document
    case archive
    case developer
    case system
    case other

    var color: Color {
        switch self {
        case .app: return .blue
        case .image: return .green
        case .video: return .purple
        case .audio: return .pink
        case .document: return .orange
        case .archive: return .yellow
        case .developer: return .teal
        case .system: return .indigo
        case .other: return .gray
        }
    }

    var label: String {
        switch self {
        case .app: return "Applications"
        case .image: return "Images"
        case .video: return "Videos"
        case .audio: return "Audio"
        case .document: return "Documents"
        case .archive: return "Archives"
        case .developer: return "Developer"
        case .system: return "System"
        case .other: return "Other"
        }
    }

    var nsColor: NSColor {
        switch self {
        case .app: return .systemBlue
        case .image: return .systemGreen
        case .video: return .systemPurple
        case .audio: return .systemPink
        case .document: return .systemOrange
        case .archive: return .systemYellow
        case .developer: return .systemTeal
        case .system: return .systemIndigo
        case .other: return .systemGray
        }
    }

    var icon: String {
        switch self {
        case .app: return "app.fill"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .audio: return "music.note"
        case .document: return "doc.fill"
        case .archive: return "archivebox.fill"
        case .developer: return "hammer.fill"
        case .system: return "gearshape.fill"
        case .other: return "questionmark.folder.fill"
        }
    }

    static func categorize(name: String, path: String) -> FileCategory {
        let ext: String
        if let dotIdx = name.lastIndex(of: ".") {
            ext = String(name[name.index(after: dotIdx)...]).lowercased()
        } else {
            ext = ""
        }

        switch ext {
        case "app", "prefPane":
            return .app
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "svg", "ico", "raw", "cr2", "nef", "arw":
            return .image
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "3gp":
            return .video
        case "mp3", "wav", "flac", "aac", "ogg", "wma", "m4a", "aiff", "aif":
            return .audio
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "csv", "pages", "numbers", "keynote", "md":
            return .document
        case "zip", "tar", "gz", "bz2", "7z", "rar", "dmg", "iso", "pkg", "xz":
            return .archive
        case "swift", "h", "m", "c", "cpp", "py", "js", "ts", "html", "css", "json", "xml", "yaml", "yml", "rb", "java", "kt", "rs", "go":
            return .developer
        case "plist", "dylib", "so", "framework", "kext":
            return .system
        default:
            if path.contains("/Library/") || path.contains("/System/") {
                return .system
            }
            if path.contains("node_modules") || path.contains(".git/") || path.contains("DerivedData") {
                return .developer
            }
            return .other
        }
    }
}
