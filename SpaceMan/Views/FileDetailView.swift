import SwiftUI

struct FileDetailView: View {
    @Bindable var viewModel: ScanViewModel
    @AppStorage(AppSettings.Key.confirmBeforeDelete) private var confirmBeforeDelete = AppSettings.Default.confirmBeforeDelete
    @State private var showDeleteConfirmation = false
    @State private var showPermanentDeleteConfirmation = false
    @State private var showPurgeConfirmation = false
    @State private var relatedFiles: [URL] = []
    @State private var relatedSize: Int64 = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let node = viewModel.selectedNode {
                    selectedNodeView(node)
                } else {
                    ContentUnavailableView {
                        Label("No Selection", systemImage: "square.dashed")
                    } description: {
                        Text("Select a file or folder to see details")
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .padding()
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                Task { await viewModel.deleteSelected() }
            }
        } message: {
            Text("Move \"\(viewModel.selectedNode?.name ?? "")\" to the Trash?")
        }
        .confirmationDialog(
            "Delete Permanently?",
            isPresented: $showPermanentDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                Task { await viewModel.permanentlyDeleteSelected() }
            }
        } message: {
            Text("This will permanently delete \"\(viewModel.selectedNode?.name ?? "")\" and cannot be undone. The data will be removed from your disk immediately.")
        }
        .confirmationDialog(
            "Purge App & Data?",
            isPresented: $showPurgeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Purge Everything", role: .destructive) {
                Task { await viewModel.purgeSelected() }
            }
        } message: {
            let name = viewModel.selectedNode?.name ?? ""
            Text("Permanently delete \"\(name)\" and \(relatedFiles.count) related items (\(SizeFormatter.format(bytes: relatedSize)) total)?")
        }
    }

    @ViewBuilder
    private func selectedNodeView(_ node: FileNode) -> some View {
        VStack(spacing: 10) {
            Image(nsImage: node.icon)
                .resizable()
                .frame(width: 64, height: 64)

            Text(node.name)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(node.formattedSize)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)

        Divider()

        VStack(alignment: .leading, spacing: 10) {
            DetailRow(label: "Kind", value: node.isDirectory ? "Folder" : node.category.label)
            DetailRow(label: "Path", value: node.path)

            if node.isDirectory {
                DetailRow(label: "Items", value: SizeFormatter.formatCount(node.fileCount))
            }

            if let date = node.modificationDate {
                DetailRow(label: "Modified", value: date.formatted(date: .abbreviated, time: .shortened))
            }

            if !node.isAccessible {
                Label("No access permission", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }

        Divider()

        VStack(spacing: 8) {
            Button {
                NSWorkspace.shared.selectFile(
                    node.path,
                    inFileViewerRootedAtPath: node.parentPath
                )
            } label: {
                Label("Show in Finder", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if node.isDirectory {
                Button {
                    NSWorkspace.shared.open(node.url)
                } label: {
                    Label("Open Folder", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button(role: .destructive) {
                if confirmBeforeDelete {
                    showDeleteConfirmation = true
                } else {
                    Task { await viewModel.deleteSelected() }
                }
            } label: {
                Label("Move to Trash", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                if confirmBeforeDelete {
                    showPermanentDeleteConfirmation = true
                } else {
                    Task { await viewModel.permanentlyDeleteSelected() }
                }
            } label: {
                Label("Delete Permanently", systemImage: "xmark.bin")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            if node.pathExtension == "app" {
                Button(role: .destructive) {
                    if confirmBeforeDelete {
                        relatedFiles = FileDeleter.findRelatedFiles(for: node)
                        relatedSize = FileDeleter.totalRelatedSize(for: node) + node.size
                        showPurgeConfirmation = true
                    } else {
                        Task { await viewModel.purgeSelected() }
                    }
                } label: {
                    Label("Purge App & Data", systemImage: "flame")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }

}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }
}
