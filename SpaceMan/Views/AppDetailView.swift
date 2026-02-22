import SwiftUI

struct AppDetailView: View {
    @Bindable var viewModel: AppManagerViewModel
    @AppStorage(AppSettings.Key.confirmBeforeDelete) private var confirmBeforeDelete = AppSettings.Default.confirmBeforeDelete
    @State private var showTrashConfirmation = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let app = viewModel.selectedApp {
                        selectedAppView(app)
                    } else {
                        ContentUnavailableView {
                            Label("No Selection", systemImage: "square.dashed")
                        } description: {
                            Text("Select an app to see details")
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
                .padding()
            }
            .allowsHitTesting(!viewModel.isDeleting)

            // Deletion overlay
            if viewModel.isDeleting {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Deleting \(viewModel.deletingAppName)...")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Removing app and related data")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: $showTrashConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                guard let app = viewModel.selectedApp else { return }
                Task { await viewModel.deleteApp(app, permanently: false) }
            }
        } message: {
            if let app = viewModel.selectedApp {
                let selectedCount = app.relatedFiles.filter(\.isSelected).count
                Text("Move \"\(app.name)\" and \(selectedCount) related item(s) to the Trash?\n\nTotal: \(SizeFormatter.format(bytes: app.appSize + app.selectedRelatedSize))\n\nYou can recover these from Trash.")
            }
        }
        .confirmationDialog(
            "Delete Permanently?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Forever", role: .destructive) {
                guard let app = viewModel.selectedApp else { return }
                Task { await viewModel.deleteApp(app, permanently: true) }
            }
        } message: {
            if let app = viewModel.selectedApp {
                let selectedCount = app.relatedFiles.filter(\.isSelected).count
                Text("Permanently delete \"\(app.name)\" and \(selectedCount) related item(s)?\n\nTotal: \(SizeFormatter.format(bytes: app.appSize + app.selectedRelatedSize))\n\nThis cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private func selectedAppView(_ app: AppInfo) -> some View {
        // Header
        VStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 64, height: 64)

            Text(app.name)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(SizeFormatter.format(bytes: app.totalSize))
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)

        if app.isRunning {
            Label("This app is currently running", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
        }

        Divider()

        // Info rows
        VStack(alignment: .leading, spacing: 10) {
            DetailRow(label: "Bundle ID", value: app.bundleIdentifier)
            DetailRow(label: "Path", value: app.url.path)
            DetailRow(label: "App Size", value: SizeFormatter.format(bytes: app.appSize))
        }

        Divider()

        // Related files with checkboxes
        if app.relatedFiles.isEmpty {
            Text("No related data found")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Related Data")
                    .font(.subheadline)
                    .fontWeight(.medium)

                ForEach(app.relatedFiles) { file in
                    Toggle(isOn: Binding(
                        get: {
                            // Read live from apps array to stay in sync
                            guard let appIndex = viewModel.apps.firstIndex(where: { $0.id == app.id }),
                                  let fileIndex = viewModel.apps[appIndex].relatedFiles.firstIndex(where: { $0.id == file.id }) else {
                                return file.isSelected
                            }
                            return viewModel.apps[appIndex].relatedFiles[fileIndex].isSelected
                        },
                        set: { newValue in
                            viewModel.setRelatedFileSelected(appId: app.id, fileId: file.id, selected: newValue)
                        }
                    )) {
                        HStack {
                            Text(file.category)
                                .font(.callout)
                            Spacer()
                            Text(SizeFormatter.format(bytes: file.size))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }

                Divider()

                HStack {
                    Text("Selected data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(SizeFormatter.format(bytes: app.selectedRelatedSize))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }

        Divider()

        // Action buttons
        VStack(spacing: 8) {
            Button {
                NSWorkspace.shared.selectFile(
                    app.url.path,
                    inFileViewerRootedAtPath: app.url.deletingLastPathComponent().path
                )
            } label: {
                Label("Show in Finder", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                if confirmBeforeDelete {
                    showTrashConfirmation = true
                } else {
                    Task { await viewModel.deleteApp(app, permanently: false) }
                }
            } label: {
                Label("Move to Trash", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                if confirmBeforeDelete {
                    showDeleteConfirmation = true
                } else {
                    Task { await viewModel.deleteApp(app, permanently: true) }
                }
            } label: {
                Label("Delete Forever", systemImage: "xmark.bin")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
}
