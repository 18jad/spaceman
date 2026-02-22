import SwiftUI

struct SmartCleanView: View {
    @Bindable var viewModel: SmartCleanViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                idleView
            case .scanning:
                scanningView
            case .results:
                resultsDashboard
            case .executing:
                executingView
            case .done(let entry):
                doneView(entry)
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
                    Image(systemName: "sparkles")
                        .font(.system(size: 28))
                        .foregroundStyle(.teal)

                    Text("Ready")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                Text("Smart Clean")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("One-click cleanup of caches, downloads, and duplicates")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button {
                viewModel.startScan()
            } label: {
                Label("Start Scan", systemImage: "magnifyingglass")
                    .frame(height: 28)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)

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
                                colors: [.teal.opacity(0), .teal.opacity(0.6), .teal],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .butt)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(angle))

                    // Center content
                    VStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(.teal)
                            .symbolEffect(.pulse)

                        if viewModel.scanItemsFound > 0 {
                            Text(SizeFormatter.formatCount(viewModel.scanItemsFound))
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)

                            Text("items found")
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
                Text(viewModel.scanPhase.rawValue)
                    .font(.callout)
                    .fontWeight(.medium)

                Text(viewModel.scanDetail)
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

    // MARK: - Results Dashboard

    @ViewBuilder
    private var resultsDashboard: some View {
        if let plan = viewModel.plan {
            VStack(spacing: 0) {
                // Top section: gauge + summary
                VStack(spacing: 20) {
                    // Circular gauge showing safe size
                    GaugeView(
                        safeSize: plan.totalSafeSize,
                        selectedSize: plan.totalSelectedSize,
                        totalSize: plan.totalSize
                    )
                    .frame(height: 180)
                    .padding(.top, 20)

                    // Summary text
                    VStack(spacing: 4) {
                        if plan.totalSelectedSize != plan.totalSafeSize {
                            Text("\(SizeFormatter.format(bytes: plan.totalSelectedSize)) selected")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Text("\(plan.groups.count) categories \u{00B7} \(SizeFormatter.formatCount(plan.groups.reduce(0) { $0 + $1.items.count })) items found")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer().frame(height: 16)

                Divider()

                // Category cards — horizontal scroll of compact cards
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(plan.groups) { (group: CleanableGroup) in
                            SmartCleanCategoryCard(
                                group: group,
                                totalPlanSize: plan.totalSize,
                                onToggleItem: { viewModel.toggleItem($0) },
                                onSelectAll: { viewModel.selectAll(in: group.category) },
                                onDeselectAll: { viewModel.deselectAll(in: group.category) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }

                // Bottom action bar
                Divider()

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(SizeFormatter.formatCount(plan.totalSelectedCount)) items selected")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text(SizeFormatter.format(bytes: plan.totalSelectedSize))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Button("Safe Only") {
                        viewModel.selectAllSafe()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button {
                        viewModel.executeClean()
                    } label: {
                        Label("Smart Clean", systemImage: "sparkles")
                            .frame(height: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .disabled(plan.totalSelectedCount == 0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
    }

    // MARK: - Executing

    private var executingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color(.separatorColor).opacity(0.2), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: viewModel.executionTotal > 0 ? Double(viewModel.executionCurrent) / Double(viewModel.executionTotal) : 0)
                    .stroke(.teal, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.executionCurrent)

                VStack(spacing: 2) {
                    Text("\(viewModel.executionCurrent)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text("of \(viewModel.executionTotal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 6) {
                Text("Cleaning up...")
                    .font(.callout)
                    .fontWeight(.medium)

                Text(viewModel.executionCurrentItem)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 350)
            }

            Button("Cancel") {
                viewModel.cancelClean()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()
        }
    }

    // MARK: - Done

    private func doneView(_ entry: CleanLogEntry) -> some View {
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

                VStack(spacing: 2) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.green)

                    Text("Done")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 6) {
                Text(SizeFormatter.format(bytes: entry.bytesFreed))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.teal)

                Text("\(entry.itemsCleaned) items moved to Trash")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Button("Scan Again") {
                    viewModel.startScan()
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
            }

            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Analysis Failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                viewModel.startScan()
            }
        }
    }
}

// MARK: - Circular Gauge

private struct GaugeView: View {
    let safeSize: Int64
    let selectedSize: Int64
    let totalSize: Int64

    @State private var appeared = false

    private var safeProportion: Double {
        guard totalSize > 0 else { return 0 }
        return Double(safeSize) / Double(totalSize)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color(.separatorColor).opacity(0.15), lineWidth: 14)
                .frame(width: 170, height: 170)

            // Safe portion (teal)
            Circle()
                .trim(from: 0, to: appeared ? safeProportion : 0)
                .stroke(
                    .teal,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 170, height: 170)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: appeared)

            // Center text
            VStack(spacing: 2) {
                Text(SizeFormatter.format(bytes: safeSize))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.teal)

                Text("safe to clean")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            appeared = true
        }
    }
}

// MARK: - Category Card (full-width stacked)

private struct SmartCleanCategoryCard: View {
    let group: CleanableGroup
    let totalPlanSize: Int64
    let onToggleItem: (UUID) -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    @State private var isExpanded = false
    @State private var isHovered = false

    private var proportion: Double {
        guard totalPlanSize > 0 else { return 0 }
        return Double(group.totalSize) / Double(totalPlanSize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header — full width
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        // Category icon in a colored circle
                        ZStack {
                            Circle()
                                .fill(group.category.color.opacity(0.15))
                                .frame(width: 40, height: 40)

                            Image(systemName: group.category.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(group.category.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.category.label)
                                .font(.body)
                                .fontWeight(.semibold)

                            Text("\(SizeFormatter.formatCompact(group.items.count)) items \u{00B7} \(group.selectedCount) selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(SizeFormatter.format(bytes: group.totalSize))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(group.category.color)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }

                    // Proportion bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.separatorColor).opacity(0.15))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(group.category.color.opacity(0.6))
                                .frame(width: max(geo.size.width * proportion, proportion > 0 ? 4 : 0))
                        }
                    }
                    .frame(height: 5)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded item list
            if isExpanded {
                Divider().padding(.horizontal, 16)

                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Button("Select All") { onSelectAll() }
                        Button("Deselect All") { onDeselectAll() }
                        Spacer()
                        Text("\(group.selectedCount) of \(group.items.count) selected")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    Divider().padding(.horizontal, 16)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(group.items) { (item: CleanableItem) in
                                SmartCleanItemRow(item: item, onToggle: { onToggleItem(item.id) })
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isHovered ? Color(.controlBackgroundColor) : Color(.windowBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isHovered ? group.category.color.opacity(0.3) : Color(.separatorColor).opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.06 : 0.02), radius: isHovered ? 8 : 2, y: isHovered ? 3 : 1)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Item Row

private struct SmartCleanItemRow: View {
    let item: CleanableItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isSelected ? AnyShapeStyle(.teal) : AnyShapeStyle(.secondary))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    Text(SizeFormatter.format(bytes: item.size))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    riskBadge

                    if let reason = reasonText {
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                NSWorkspace.shared.open(item.url)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.square")
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
        }
    }

    private var reasonText: String? {
        item.reason.isEmpty ? nil : item.reason
    }

    @ViewBuilder
    private var riskBadge: some View {
        switch item.risk {
        case .safe:
            Text("Safe")
                .font(.caption2)
                .foregroundStyle(.green)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.green.opacity(0.1), in: Capsule())
        case .review:
            Text("Review")
                .font(.caption2)
                .foregroundStyle(.orange)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.orange.opacity(0.1), in: Capsule())
        case .risky:
            Text("Risky")
                .font(.caption2)
                .foregroundStyle(.red)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.red.opacity(0.1), in: Capsule())
        }
    }
}

// MARK: - Clean Log Sheet

struct CleanLogSheet: View {
    let entries: [CleanLogEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Clean History")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            if entries.isEmpty {
                ContentUnavailableView {
                    Label("No History", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Cleanup history will appear here after your first Smart Clean.")
                }
                .frame(maxHeight: .infinity)
            } else {
                List(entries) { (entry: CleanLogEntry) in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.callout)
                                .fontWeight(.medium)
                            Text("\(entry.itemsCleaned) items cleaned")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(SizeFormatter.format(bytes: entry.bytesFreed))
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.teal)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(width: 400, height: 350)
    }
}
