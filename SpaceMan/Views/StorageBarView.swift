import SwiftUI

struct StorageBarView: View {
    let viewModel: ScanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Storage")
                    .font(.headline)

                Spacer()

                Text("\(SizeFormatter.format(bytes: viewModel.usedDiskSpace)) used of \(SizeFormatter.format(bytes: viewModel.totalDiskSpace))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Storage bar — outer container is rounded, inner segments are flat
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    ForEach(viewModel.categoryBreakdown) { cat in
                        let fraction = CGFloat(cat.size) / CGFloat(max(1, viewModel.totalDiskSpace))
                        let width = max(4, geometry.size.width * fraction)
                        Rectangle()
                            .fill(cat.category.color.gradient)
                            .frame(width: width)
                            .help("\(cat.category.label): \(SizeFormatter.format(bytes: cat.size))")
                    }

                    // Free space
                    Rectangle()
                        .fill(Color(.separatorColor).opacity(0.2))
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .frame(height: 20)

            // Legend — wraps to multiple lines on small screens
            FlowLayout(spacing: CGSize(width: 14, height: 6)) {
                ForEach(viewModel.categoryBreakdown) { cat in
                    legendItem(color: cat.category.color, label: cat.category.label,
                               value: SizeFormatter.format(bytes: cat.size))
                }

                legendItem(color: Color(.separatorColor).opacity(0.3), label: "Available",
                           value: SizeFormatter.format(bytes: viewModel.freeDiskSpace))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func legendItem(color: some ShapeStyle, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Flow Layout (wrapping HStack)

private struct FlowLayout: Layout {
    var spacing: CGSize

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(subviews: subviews, width: proposal.width ?? .infinity)
        guard !rows.isEmpty else { return .zero }

        let height = rows.enumerated().reduce(CGFloat(0)) { total, pair in
            let rowHeight = pair.element.map { $0.size.height }.max() ?? 0
            return total + rowHeight + (pair.offset > 0 ? spacing.height : 0)
        }
        return CGSize(width: proposal.width ?? .infinity, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(subviews: subviews, width: bounds.width)

        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.size.height }.max() ?? 0
            var x = bounds.minX

            for item in row {
                item.subview.place(at: CGPoint(x: x, y: y),
                                   proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing.width
            }
            y += rowHeight + spacing.height
        }
    }

    private struct LayoutItem {
        let subview: LayoutSubview
        let size: CGSize
    }

    private func computeRows(subviews: Subviews, width: CGFloat) -> [[LayoutItem]] {
        var rows = [[LayoutItem]]()
        var currentRow = [LayoutItem]()
        var rowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needed = rowWidth + (currentRow.isEmpty ? 0 : spacing.width) + size.width

            if !currentRow.isEmpty && needed > width {
                rows.append(currentRow)
                currentRow = []
                rowWidth = 0
            }

            currentRow.append(LayoutItem(subview: subview, size: size))
            rowWidth += (currentRow.count > 1 ? spacing.width : 0) + size.width
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        return rows
    }
}
