import SwiftUI

struct BreadcrumbView: View {
    @Bindable var viewModel: ScanViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                Button {
                    viewModel.navigateBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canGoBack)
                .padding(.trailing, 4)

                Button {
                    viewModel.navigateToRoot()
                } label: {
                    Image(systemName: "house.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                ForEach(Array(viewModel.breadcrumbPath.enumerated()), id: \.element.id) { index, node in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)

                    Button {
                        viewModel.navigateToBreadcrumb(node)
                    } label: {
                        Text(node.name)
                            .font(.callout)
                            .foregroundStyle(
                                index == viewModel.breadcrumbPath.count - 1
                                    ? .primary
                                    : .secondary
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(.bar.opacity(0.5))
    }
}
