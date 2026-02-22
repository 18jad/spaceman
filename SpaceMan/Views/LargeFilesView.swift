import SwiftUI

// MARK: - Main Content (detail area)

struct LargeFilesView: View {
    var scanViewModel: ScanViewModel
    var cleanupQueue: CleanupQueue

    private var filteredFiles: [FileNode] {
        scanViewModel.largeFilesFiltered(by: scanViewModel.selectedLargeFileCategory)
    }

    private var filteredTotalSize: Int64 {
        filteredFiles.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            // File list
            if filteredFiles.isEmpty {
                ContentUnavailableView {
                    Label("No Large Files", systemImage: "doc.fill")
                } description: {
                    if let category = scanViewModel.selectedLargeFileCategory {
                        Text("No \(category.label.lowercased()) files over 100 MB found.")
                    } else {
                        Text("No files over 100 MB found in the scanned directory.")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredFiles) { node in
                            LargeFileRow(
                                node: node,
                                isSelected: scanViewModel.selectedNode?.id == node.id,
                                isQueued: cleanupQueue.contains(node),
                                onSelect: {
                                    scanViewModel.selectedNode = node
                                    scanViewModel.selectedNodes = [node.id]
                                },
                                onQueueToggle: { cleanupQueue.toggle(node) }
                            )
                            Divider()
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            Divider()

            // Footer bar
            HStack(spacing: 12) {
                Image(systemName: "doc.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(filteredFiles.count) files")
                    .font(.callout)
                    .fontWeight(.medium)

                Text("(\(SizeFormatter.format(bytes: filteredTotalSize)))")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    for file in filteredFiles {
                        cleanupQueue.add(file)
                    }
                } label: {
                    Label("Add All to Queue", systemImage: "plus.circle")
                        .font(.callout)
                }
                .disabled(filteredFiles.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}

// MARK: - Sidebar (category filter)

struct LargeFilesSidebar: View {
    var scanViewModel: ScanViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 2) {
                    Text("Filter by Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                    let allFiles = scanViewModel.largeFiles
                    let stats = scanViewModel.largeFileCategoryStats

                    CategoryButton(
                        label: "All Files",
                        icon: "doc.fill",
                        color: .secondary,
                        count: allFiles.count,
                        size: allFiles.reduce(0) { $0 + $1.size },
                        isSelected: scanViewModel.selectedLargeFileCategory == nil
                    ) {
                        scanViewModel.selectedLargeFileCategory = nil
                    }

                    ForEach(stats) { item in
                        CategoryButton(
                            label: item.category.label,
                            icon: item.category.icon,
                            color: item.category.color,
                            count: item.count,
                            size: item.size,
                            isSelected: scanViewModel.selectedLargeFileCategory == item.category
                        ) {
                            scanViewModel.selectedLargeFileCategory = item.category
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }
}

private struct CategoryButton: View {
    let label: String
    let icon: String
    let color: Color
    let count: Int
    let size: Int64
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.callout)
                        .fontWeight(isSelected ? .semibold : .regular)
                    HStack(spacing: 6) {
                        Text("\(count) files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(SizeFormatter.format(bytes: size))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.12)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - File Row

private struct LargeFileRow: View {
    let node: FileNode
    let isSelected: Bool
    let isQueued: Bool
    let onSelect: () -> Void
    let onQueueToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: node.icon)
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(node.parentPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Circle()
                .fill(node.category.color)
                .frame(width: 8, height: 8)
                .help(node.category.label)

            Text(node.formattedSize)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)

            Button {
                onQueueToggle()
            } label: {
                Image(systemName: isQueued ? "checkmark.circle.fill" : "plus.circle")
                    .font(.body)
                    .foregroundStyle(isQueued ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
            }
            .buttonStyle(.plain)
            .help(isQueued ? "Remove from Cleanup Queue" : "Add to Cleanup Queue")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.12)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}
