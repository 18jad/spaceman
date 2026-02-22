import SwiftUI

struct CleanupReviewSheet: View {
    var cleanupQueue: CleanupQueue
    var scanViewModel: ScanViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.Key.confirmBeforeDelete) private var confirmBeforeDelete = AppSettings.Default.confirmBeforeDelete
    @State private var showTrashConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showPurgeConfirm = false
    @State private var isProcessing = false

    private var hasApps: Bool {
        cleanupQueue.items.contains { $0.pathExtension == "app" }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cleanup Queue")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("\(cleanupQueue.count) items \u{00B7} \(SizeFormatter.format(bytes: cleanupQueue.totalSize))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clear All") {
                    cleanupQueue.clear()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            // Item list
            List {
                ForEach(cleanupQueue.items) { node in
                    HStack(spacing: 10) {
                        Image(nsImage: node.icon)
                            .resizable()
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.name)
                                .font(.callout)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(node.path)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Text(node.formattedSize)
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Button {
                            cleanupQueue.remove(node)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Button {
                    if confirmBeforeDelete {
                        showTrashConfirm = true
                    } else {
                        Task { await performTrash() }
                    }
                } label: {
                    Label("Move All to Trash", systemImage: "trash")
                }
                .disabled(cleanupQueue.isEmpty || isProcessing)

                Button {
                    if confirmBeforeDelete {
                        showDeleteConfirm = true
                    } else {
                        Task { await performDelete() }
                    }
                } label: {
                    Label("Delete All", systemImage: "xmark.bin")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(cleanupQueue.isEmpty || isProcessing)

                if hasApps {
                    Button {
                        if confirmBeforeDelete {
                            showPurgeConfirm = true
                        } else {
                            Task { await performPurge() }
                        }
                    } label: {
                        Label("Purge Apps & Data", systemImage: "flame")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(cleanupQueue.isEmpty || isProcessing)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .confirmationDialog("Move to Trash?", isPresented: $showTrashConfirm, titleVisibility: .visible) {
            Button("Move All to Trash", role: .destructive) {
                Task { await performTrash() }
            }
        } message: {
            Text("Move \(cleanupQueue.count) items (\(SizeFormatter.format(bytes: cleanupQueue.totalSize))) to the Trash?")
        }
        .confirmationDialog("Delete Permanently?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete All Permanently", role: .destructive) {
                Task { await performDelete() }
            }
        } message: {
            Text("Permanently delete \(cleanupQueue.count) items (\(SizeFormatter.format(bytes: cleanupQueue.totalSize)))? This cannot be undone.")
        }
        .confirmationDialog("Purge Apps & Data?", isPresented: $showPurgeConfirm, titleVisibility: .visible) {
            Button("Purge Everything", role: .destructive) {
                Task { await performPurge() }
            }
        } message: {
            Text("Permanently delete \(cleanupQueue.count) items and all related app data?")
        }
    }

    private func performTrash() async {
        isProcessing = true
        let items = cleanupQueue.items
        for node in items {
            let success = await FileDeleter.moveToTrash(node: node)
            if success {
                scanViewModel.removeFromTree(node)
                cleanupQueue.remove(node)
            }
        }
        isProcessing = false
        if cleanupQueue.isEmpty { dismiss() }
    }

    private func performDelete() async {
        isProcessing = true
        let items = cleanupQueue.items
        for node in items {
            let success = await FileDeleter.permanentDelete(node: node)
            if success {
                scanViewModel.removeFromTree(node)
                cleanupQueue.remove(node)
            }
        }
        isProcessing = false
        if cleanupQueue.isEmpty { dismiss() }
    }

    private func performPurge() async {
        isProcessing = true
        let items = cleanupQueue.items
        for node in items {
            let success: Bool
            if node.pathExtension == "app" {
                success = await FileDeleter.purge(node: node)
            } else {
                success = await FileDeleter.permanentDelete(node: node)
            }
            if success {
                scanViewModel.removeFromTree(node)
                cleanupQueue.remove(node)
            }
        }
        isProcessing = false
        if cleanupQueue.isEmpty { dismiss() }
    }
}
