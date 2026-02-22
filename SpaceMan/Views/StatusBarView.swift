import SwiftUI

struct StatusBarView: View {
    let viewModel: ScanViewModel

    var body: some View {
        HStack(spacing: 12) {
            if viewModel.isScanning {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)

                Text("Scanning: \(SizeFormatter.formatCount(viewModel.scanProgress)) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(viewModel.scanCurrentPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else if let root = viewModel.rootNode {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)

                Text("\(SizeFormatter.formatCount(root.fileCount)) files scanned in \(formattedDuration(viewModel.scanDuration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(root.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Click Scan to analyze your disk")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if let hovered = viewModel.hoveredNode {
                Image(systemName: hovered.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("\(hovered.name) - \(hovered.formattedSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else if let selected = viewModel.selectedNode {
                Text(selected.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            let mins = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return "\(mins)m \(secs)s"
        }
    }
}
