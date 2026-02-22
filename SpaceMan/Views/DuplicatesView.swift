import SwiftUI

struct DuplicatesView: View {
    @Bindable var viewModel: DuplicatesViewModel
    @AppStorage(AppSettings.Key.duplicatesConfirmBeforeDelete) private var confirmBeforeDelete = AppSettings.Default.duplicatesConfirmBeforeDelete
    @State private var showTrashConfirm = false
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .idle:
                scopePickerView
            case .scanning:
                scanningView
            case .results:
                resultsView
            case .error(let message):
                errorView(message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scope Picker (Idle)

    private var scopePickerView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.purple)
                        .symbolRenderingMode(.hierarchical)

                    Text("Find Duplicates")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Choose where to scan for duplicate files")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // Scope options
                VStack(spacing: 12) {
                    scopeButton(.home, recommended: true)

                    Divider()
                        .padding(.horizontal, 40)

                    Text("Quick Picks")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 40)

                    HStack(spacing: 10) {
                        quickPickButton(.downloads)
                        quickPickButton(.desktop)
                        quickPickButton(.documents)
                        quickPickButton(.pictures)
                        quickPickButton(.movies)
                    }
                    .padding(.horizontal, 40)

                    Divider()
                        .padding(.horizontal, 40)

                    HStack(spacing: 12) {
                        Button {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = true
                            panel.message = "Choose folders to scan for duplicates"
                            panel.prompt = "Select"
                            if panel.runModal() == .OK, !panel.urls.isEmpty {
                                viewModel.scanScope = .custom(panel.urls)
                            }
                        } label: {
                            Label("Choose Folders...", systemImage: "folder.badge.plus")
                        }

                        if case .custom(let urls) = viewModel.scanScope {
                            Text(urls.map(\.lastPathComponent).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            viewModel.scanScope = .entireDisk
                        } label: {
                            Label("Entire Disk", systemImage: "internaldrive.fill")
                        }
                        .foregroundStyle(viewModel.scanScope == .entireDisk ? .primary : .secondary)
                    }
                    .padding(.horizontal, 40)
                }
                .frame(maxWidth: 540)

                Button {
                    viewModel.startScan()
                } label: {
                    Text("Scan for Duplicates")
                        .font(.headline)
                        .frame(width: 220, height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }

            Spacer()
        }
    }

    private func scopeButton(_ scope: ScanScope, recommended: Bool = false) -> some View {
        Button {
            viewModel.scanScope = scope
        } label: {
            HStack(spacing: 8) {
                Image(systemName: scope.icon)
                    .frame(width: 20)
                Text(scope.label)
                if recommended {
                    Text("Recommended")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                Spacer()
                if viewModel.scanScope == scope {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.purple)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(viewModel.scanScope == scope ? Color.purple.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func quickPickButton(_ scope: ScanScope) -> some View {
        let isSelected = viewModel.scanScope == scope
        return Button {
            viewModel.scanScope = scope
        } label: {
            VStack(spacing: 6) {
                Image(systemName: scope.icon)
                    .font(.system(size: 20))
                    .frame(height: 24)
                Text(scope.label)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.purple.opacity(0.1) : Color(.controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.purple.opacity(0.4) : Color(.separatorColor).opacity(0.3), lineWidth: isSelected ? 1.5 : 1)
            )
            .foregroundStyle(isSelected ? .purple : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scanning Progress

    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            VStack(spacing: 8) {
                switch viewModel.scanPhase {
                case .enumerating:
                    Text("Discovering files...")
                        .font(.headline)
                    Text("\(SizeFormatter.formatCount(viewModel.filesEnumerated)) files found")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                case .hashing:
                    Text("Comparing candidates...")
                        .font(.headline)
                    Text("\(SizeFormatter.formatCount(viewModel.filesHashed)) of \(SizeFormatter.formatCount(viewModel.sizeCandidates)) hashed (\(SizeFormatter.format(bytes: viewModel.bytesHashed)))")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if viewModel.sizeCandidates > 0 {
                        ProgressView(value: Double(viewModel.filesHashed), total: Double(viewModel.sizeCandidates))
                            .frame(maxWidth: 300)
                    }
                }

                Text(viewModel.currentPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 400)
            }

            Button("Cancel") {
                viewModel.cancelScan()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Warning banner for inaccessible paths
            if !viewModel.inaccessiblePaths.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("\(viewModel.inaccessiblePaths.count) paths were inaccessible and skipped")
                        .font(.caption)
                    Spacer()
                    Button("Dismiss") {
                        withAnimation { viewModel.inaccessiblePaths.removeAll() }
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.yellow.opacity(0.1))

                Divider()
            }

            // Toolbar bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search duplicates...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)

                Spacer()

                if !viewModel.groups.isEmpty {
                    Text("\(SizeFormatter.formatCount(viewModel.groups.count)) groups \u{00B7} \(SizeFormatter.format(bytes: viewModel.totalWastedSize)) reclaimable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            // Category filter chips
            if !viewModel.groups.isEmpty {
                filterBar

                Divider()
            }

            if viewModel.filteredGroups.isEmpty {
                ContentUnavailableView {
                    Label(
                        viewModel.activeFilter == .all ? "No Duplicates Found" : "No \(viewModel.activeFilter.label) Duplicates",
                        systemImage: viewModel.activeFilter == .all ? "checkmark.circle" : viewModel.activeFilter.icon
                    )
                } description: {
                    Text(viewModel.activeFilter == .all
                        ? "No duplicate files were found in the scanned location"
                        : "No duplicate \(viewModel.activeFilter.label.lowercased()) files were found")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredGroups) { group in
                            DuplicateGroupRow(
                                group: group,
                                selectedForDeletion: viewModel.selectedForDeletion,
                                onToggle: { fileId in
                                    viewModel.toggleSelection(fileId, in: group)
                                }
                            )
                        }
                    }
                }
            }

            // Bottom action bar (shown when items are selected)
            if !viewModel.selectedForDeletion.isEmpty {
                Divider()

                HStack(spacing: 16) {
                    Text("\(SizeFormatter.formatCount(viewModel.selectedDeletionCount)) files selected (\(SizeFormatter.format(bytes: viewModel.selectedDeletionSize)))")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Deselect All") {
                        viewModel.deselectAll()
                    }
                    .buttonStyle(.bordered)

                    Menu {
                        Button {
                            if confirmBeforeDelete {
                                showTrashConfirm = true
                            } else {
                                Task { await viewModel.deleteSelected() }
                            }
                        } label: {
                            Label("Move to Trash", systemImage: "trash")
                        }

                        Button {
                            if confirmBeforeDelete {
                                showDeleteConfirm = true
                            } else {
                                Task { await viewModel.permanentlyDeleteSelected() }
                            }
                        } label: {
                            Label("Delete Permanently", systemImage: "xmark.bin")
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .menuStyle(.borderedButton)
                    .tint(.red)
                    .disabled(viewModel.isDeleting)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedForDeletion.isEmpty)
        .confirmationDialog("Move to Trash?", isPresented: $showTrashConfirm, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) {
                Task { await viewModel.deleteSelected() }
            }
        } message: {
            Text("Move \(SizeFormatter.formatCount(viewModel.selectedDeletionCount)) duplicate files (\(SizeFormatter.format(bytes: viewModel.selectedDeletionSize))) to the Trash?")
        }
        .confirmationDialog("Delete Permanently?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Permanently", role: .destructive) {
                Task { await viewModel.permanentlyDeleteSelected() }
            }
        } message: {
            Text("Permanently delete \(SizeFormatter.formatCount(viewModel.selectedDeletionCount)) duplicate files (\(SizeFormatter.format(bytes: viewModel.selectedDeletionSize)))? This cannot be undone.")
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        let totalSize = viewModel.totalWastedSize
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DuplicateFilter.allCases, id: \.self) { filter in
                    FilterCard(
                        filter: filter,
                        count: viewModel.groupCount(for: filter),
                        size: viewModel.wastedSize(for: filter),
                        totalSize: totalSize,
                        isActive: viewModel.activeFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.activeFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Scan Failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                viewModel.resetToIdle()
            }
        }
    }
}

// MARK: - Filter Card

private struct FilterCard: View {
    let filter: DuplicateFilter
    let count: Int
    let size: Int64
    let totalSize: Int64
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var isEmpty: Bool { filter != .all && count == 0 }

    private var proportion: Double {
        guard totalSize > 0, size > 0 else { return 0 }
        return Double(size) / Double(totalSize)
    }

    private var barColor: Color {
        switch filter {
        case .all: return .purple
        case .images: return .green
        case .videos: return .blue
        case .audio: return .pink
        case .archives: return .yellow
        case .other: return .gray
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: filter.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(isActive ? barColor : .secondary)
                        .frame(width: 18)

                    Text(filter.label)
                        .font(.caption)
                        .fontWeight(isActive ? .semibold : .medium)
                }

                HStack(spacing: 0) {
                    Text(countLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .layoutPriority(1)
                    Spacer(minLength: 4)
                    Text(SizeFormatter.format(bytes: size))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(isActive ? barColor : .secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .lineLimit(1)

                // Proportional size bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.separatorColor).opacity(0.2))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor.opacity(isActive ? 0.8 : 0.35))
                            .frame(width: max(geo.size.width * proportion, proportion > 0 ? 4 : 0))
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 120)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? barColor.opacity(0.4) : Color(.separatorColor).opacity(isHovered ? 0.5 : 0.3), lineWidth: isActive ? 1.5 : 1)
            )
            .opacity(isEmpty ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isEmpty)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    private var cardBackground: Color {
        if isActive {
            return barColor.opacity(0.08)
        }
        return isHovered ? Color(.controlBackgroundColor) : Color(.windowBackgroundColor).opacity(0.5)
    }

    private var countLabel: String {
        "\(SizeFormatter.formatCompact(count)) groups"
    }
}

// MARK: - Duplicate Group Row

struct DuplicateGroupRow: View {
    let group: DuplicateGroup
    let selectedForDeletion: Set<UUID>
    let onToggle: (UUID) -> Void

    @AppStorage(AppSettings.Key.duplicatesWarnAllSelected) private var warnAllSelected = AppSettings.Default.duplicatesWarnAllSelected
    @State private var isExpanded = false
    @State private var showAllSelectedWarning = false
    @State private var lastToggledFileId: UUID?

    private var allSelected: Bool {
        group.files.allSatisfy { selectedForDeletion.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row — tap to expand/collapse
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 14)

                    Image(systemName: group.files.first.map { $0.category.icon } ?? "doc.fill")
                        .foregroundStyle(group.files.first?.category.color ?? .gray)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.files.first?.name ?? "Unknown")
                            .fontWeight(.medium)

                        Text("\(group.files.count) copies \u{00B7} \(SizeFormatter.format(bytes: group.wastedSize)) wasted")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if allSelected {
                        Text("All selected")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.1), in: Capsule())
                    }

                    Text(SizeFormatter.format(bytes: group.fileSize))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded file list
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(group.files) { (file: DuplicateFile) in
                        fileRow(file)
                    }
                }
                .padding(.leading, 40)
                .padding(.trailing, 16)
            }

            Divider()
                .padding(.leading, 16)
        }
        .onChange(of: allSelected) { _, isAll in
            if isAll && warnAllSelected {
                showAllSelectedWarning = true
            }
        }
    }

    private func fileRow(_ file: DuplicateFile) -> some View {
        let isKeep = file.id == group.recommendedKeep
        let isSelected = selectedForDeletion.contains(file.id)
        let isPopoverAnchor = file.id == lastToggledFileId

        return HStack(spacing: 10) {
            Button {
                lastToggledFileId = file.id
                onToggle(file.id)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
            }
            .buttonStyle(.plain)
            .popover(isPresented: isPopoverAnchor ? $showAllSelectedWarning : .constant(false), arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("All copies selected")
                            .fontWeight(.semibold)
                    }
                    Text("Every copy of this file will be permanently removed from your system. No version will be kept.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(width: 280)
            }

            Image(systemName: file.category.icon)
                .foregroundStyle(file.category.color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.url.path)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    Text(SizeFormatter.format(bytes: file.size))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let date = file.modificationDate {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if isKeep {
                        Text("Newest")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                NSWorkspace.shared.open(file.url)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.square")
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.url.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            Divider()

            Button {
                onToggle(file.id)
            } label: {
                if isSelected {
                    Label("Deselect", systemImage: "circle")
                } else {
                    Label("Select for Removal", systemImage: "checkmark.circle")
                }
            }
        }
    }
}
