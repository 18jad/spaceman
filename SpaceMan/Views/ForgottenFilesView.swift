import SwiftUI

struct ForgottenFilesView: View {
    @Bindable var viewModel: ForgottenFilesViewModel
    @State private var showTrashConfirm = false

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                idleView
            case .scanning:
                scanningView
            case .results:
                resultsView
            case .empty:
                emptyView
            case .error(let message):
                errorView(message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color(.separatorColor).opacity(0.2), lineWidth: 12)
                    .frame(width: 180, height: 180)

                VStack(spacing: 4) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.indigo)

                    Text("Ready")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                Text("Forgotten Files")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Find files you haven't opened in months or years")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Scope picker
            HStack(spacing: 8) {
                Text("Scan:")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Picker("Scope", selection: $viewModel.scope) {
                    Text("Home Folder").tag(ScanScope.home)
                    Text("Downloads").tag(ScanScope.downloads)
                    Text("Desktop").tag(ScanScope.desktop)
                    Text("Documents").tag(ScanScope.documents)
                    Text("Pictures").tag(ScanScope.pictures)
                    Text("Movies").tag(ScanScope.movies)
                }
                .pickerStyle(.menu)
                .frame(width: 160)
            }

            Button {
                viewModel.startScan()
            } label: {
                Label("Start Scan", systemImage: "magnifyingglass")
                    .frame(height: 28)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)

            Spacer()
        }
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: 28) {
            Spacer()

            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let angle = timeline.date.timeIntervalSinceReferenceDate.remainder(dividingBy: 1.5) / 1.5 * 360.0

                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color(.separatorColor).opacity(0.15), lineWidth: 10)
                        .frame(width: 160, height: 160)

                    // Spinning arc
                    Circle()
                        .trim(from: 0, to: 0.25)
                        .stroke(
                            AngularGradient(
                                colors: [.indigo.opacity(0), .indigo.opacity(0.6), .indigo],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .butt)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(angle))

                    // Center icon
                    VStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(.indigo)
                            .symbolEffect(.pulse)

                        if viewModel.scanProgress > 0 {
                            Text(SizeFormatter.formatCount(viewModel.scanProgress))
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)

                            Text("files checked")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("Scanning")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            VStack(spacing: 6) {
                Text("Finding forgotten files...")
                    .font(.callout)
                    .fontWeight(.medium)

                Text(viewModel.scanCurrentPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 350)
            }

            Button("Cancel") {
                viewModel.cancelScan()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsView: some View {
        VStack(spacing: 0) {
            // 1. Age Breakdown Bar
            AgeBreakdownBar(
                bucketSummaries: viewModel.bucketSummaries,
                totalSize: viewModel.totalReclaimableSize,
                fileCount: viewModel.items.count,
                activeBucket: viewModel.filterBucket
            ) { bucket in
                withAnimation(.easeInOut(duration: 0.2)) {
                    if viewModel.filterBucket == bucket {
                        viewModel.filterBucket = nil
                    } else {
                        viewModel.filterBucket = bucket
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // 2. Toolbar Row
            ForgottenToolbar(
                searchText: $viewModel.searchText,
                filterCategory: $viewModel.filterCategory,
                sortOrder: $viewModel.sortOrder,
                categories: viewModel.presentCategories
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // 3. Selection Strip
            if !viewModel.selectedItems.isEmpty {
                SelectionStrip(
                    count: viewModel.selectedCount,
                    size: viewModel.selectedSize,
                    onSelectRecommended: { viewModel.selectAllRecommended() },
                    onDeselectAll: { viewModel.deselectAll() }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))

                Divider()
            }

            // 4. File Table
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.filteredItems) { item in
                        ForgottenFileTableRow(
                            item: item,
                            isSelected: viewModel.selectedItems.contains(item.id),
                            onToggle: { viewModel.toggleSelection(item.id) }
                        )
                    }
                }
            }

            // 5. Bottom Action Bar
            Divider()

            HStack {
                Label("Scope: \(viewModel.scope.label)", systemImage: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showTrashConfirm = true
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.regular)
                .disabled(viewModel.selectedItems.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedItems.isEmpty)
        .confirmationDialog("Move to Trash?", isPresented: $showTrashConfirm, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) {
                Task { await viewModel.moveSelectedToTrash() }
            }
        } message: {
            Text("Move \(SizeFormatter.formatCount(viewModel.selectedCount)) files (\(SizeFormatter.format(bytes: viewModel.selectedSize))) to the Trash?")
        }
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(.green.opacity(0.2), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(.green, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.green)

                    Text("All Clear")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                Text("No forgotten files found")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("All files in \(viewModel.scope.label) have been accessed within the last \(viewModel.minimumAgeDays / 30) months")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            HStack(spacing: 12) {
                Button("Scan Again") {
                    viewModel.startScan()
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
            }

            Spacer()
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
                viewModel.startScan()
            }
        }
    }
}

// MARK: - Age Breakdown Bar

private struct AgeBreakdownBar: View {
    let bucketSummaries: [(bucket: AgeBucket, count: Int, size: Int64)]
    let totalSize: Int64
    let fileCount: Int
    let activeBucket: AgeBucket?
    let onBucketTap: (AgeBucket) -> Void

    @State private var appeared = false
    @State private var hoveredBucket: AgeBucket?

    var body: some View {
        VStack(spacing: 10) {
            // Header line
            HStack {
                Text(SizeFormatter.format(bytes: totalSize))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                + Text(" reclaimable")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(SizeFormatter.formatCount(fileCount)) files found")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(bucketSummaries, id: \.bucket) { summary in
                        let proportion = totalSize > 0 ? Double(summary.size) / Double(totalSize) : 0
                        let width = max(proportion * (geo.size.width - CGFloat(bucketSummaries.count - 1) * 2), 4)

                        let isActive = activeBucket == summary.bucket
                        let isHovered = hoveredBucket == summary.bucket
                        let isDimmed = activeBucket != nil && !isActive

                        RoundedRectangle(cornerRadius: 4)
                            .fill(summary.bucket.color.opacity(isDimmed ? 0.25 : 1.0))
                            .frame(width: appeared ? width : 0)
                            .frame(height: isActive || isHovered ? 28 : 22)
                            .overlay(alignment: .center) {
                                if width > 50 {
                                    Text(SizeFormatter.format(bytes: summary.size))
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                                }
                            }
                            .onHover { isHovered in
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    hoveredBucket = isHovered ? summary.bucket : nil
                                }
                            }
                            .onTapGesture {
                                onBucketTap(summary.bucket)
                            }
                            .help("\(summary.bucket.label): \(summary.count) files, \(SizeFormatter.format(bytes: summary.size))")
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 32)
            .animation(.spring(duration: 0.6, bounce: 0.15), value: appeared)

            // Legend
            HStack(spacing: 14) {
                ForEach(bucketSummaries, id: \.bucket) { summary in
                    let isActive = activeBucket == summary.bucket

                    Button {
                        onBucketTap(summary.bucket)
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(summary.bucket.color)
                                .frame(width: 7, height: 7)

                            Text(summary.bucket.label)
                                .font(.caption2)
                                .fontWeight(isActive ? .bold : .regular)
                                .foregroundStyle(isActive ? .primary : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if activeBucket != nil {
                    Button {
                        onBucketTap(activeBucket!)
                    } label: {
                        Text("Clear")
                            .font(.caption2)
                            .foregroundStyle(.indigo)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Toolbar

private struct ForgottenToolbar: View {
    @Binding var searchText: String
    @Binding var filterCategory: FileCategory?
    @Binding var sortOrder: ForgottenFilesViewModel.SortOrder
    let categories: [FileCategory]

    var body: some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                TextField("Search files...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: 240)

            Divider()
                .frame(height: 18)

            // Category dropdown
            Menu {
                Button {
                    filterCategory = nil
                } label: {
                    Label("All Categories", systemImage: "square.grid.2x2")
                }

                Divider()

                ForEach(categories, id: \.self) { cat in
                    Button {
                        filterCategory = cat
                    } label: {
                        Label(cat.label, systemImage: cat.icon)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if let cat = filterCategory {
                        Image(systemName: cat.icon)
                            .font(.caption)
                            .foregroundStyle(cat.color)
                        Text(cat.label)
                            .font(.callout)
                    } else {
                        Image(systemName: "square.grid.2x2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Category")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Divider()
                .frame(height: 18)

            // Sort picker
            Picker("Sort", selection: $sortOrder) {
                Text("Size").tag(ForgottenFilesViewModel.SortOrder.size)
                Text("Age").tag(ForgottenFilesViewModel.SortOrder.age)
                Text("Name").tag(ForgottenFilesViewModel.SortOrder.name)
            }
            .pickerStyle(.segmented)
            .fixedSize()

            Spacer()
        }
    }
}

// MARK: - Selection Strip

private struct SelectionStrip: View {
    let count: Int
    let size: Int64
    let onSelectRecommended: () -> Void
    let onDeselectAll: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.indigo)

            Text("\(SizeFormatter.formatCount(count)) selected")
                .font(.callout)
                .fontWeight(.medium)
            +
            Text(" (\(SizeFormatter.format(bytes: size)))")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Select Recommended") {
                onSelectRecommended()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Deselect All") {
                onDeselectAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.indigo.opacity(0.06))
    }
}

// MARK: - File Table Row

private struct ForgottenFileTableRow: View {
    let item: ForgottenFileItem
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    private var parentPath: String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path()
        let dir = item.url.deletingLastPathComponent().path()
        if dir.hasPrefix(homePath) {
            return "~" + dir.dropFirst(homePath.count)
        }
        return dir
    }

    var body: some View {
        HStack(spacing: 0) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.indigo) : AnyShapeStyle(.secondary.opacity(0.6)))
            }
            .buttonStyle(.plain)
            .frame(width: 32)

            // Name + path
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(parentPath)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(minWidth: 100, alignment: .leading)

            Spacer(minLength: 12)

            // Category
            HStack(spacing: 4) {
                Image(systemName: item.category.icon)
                    .font(.caption2)
                    .foregroundStyle(item.category.color)
                Text(item.category.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 90, alignment: .leading)

            // Size
            Text(SizeFormatter.format(bytes: item.size))
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(width: 70, alignment: .trailing)

            // Age badge
            Text(item.ageBucket.label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(item.ageBucket.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(item.ageBucket.color.opacity(0.12), in: Capsule())
                .frame(width: 76, alignment: .center)

            // Last opened
            Text(item.lastOpened.formatted(.dateTime.month(.abbreviated).year(.twoDigits)))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 60, alignment: .trailing)

            // Recommended badge
            Group {
                if item.isRecommended {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .help("Recommended for cleanup")
                } else {
                    Color.clear
                }
            }
            .frame(width: 24, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(isHovered ? Color(.controlBackgroundColor).opacity(0.5) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in isHovered = hovering }
        .onTapGesture { onToggle() }
        .contextMenu {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
        }
    }
}
