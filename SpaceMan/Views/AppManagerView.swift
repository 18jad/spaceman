import SwiftUI

struct AppManagerView: View {
    @Bindable var viewModel: AppManagerViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Search and sort bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)

                Spacer()

                Picker("Sort", selection: $viewModel.sortOrder) {
                    ForEach(AppSortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)

                Text("\(viewModel.filteredApps.count) apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            // Grid content
            if viewModel.isScanning {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Scanning applications...")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.scanProgress) apps found — \(viewModel.scanCurrentApp)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.apps.isEmpty && viewModel.hasScanned {
                ContentUnavailableView {
                    Label("No Applications Found", systemImage: "app.dashed")
                } description: {
                    Text("Could not find any applications in /Applications")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.apps.isEmpty {
                ContentUnavailableView {
                    Label("App Manager", systemImage: "app.badge.checkmark")
                } description: {
                    Text("Scan to discover installed applications and their data usage")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.filteredApps) { app in
                            AppCardView(app: app, isSelected: viewModel.selectedApp?.id == app.id)
                                .onTapGesture {
                                    viewModel.selectedApp = app
                                }
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(16)
                    .animation(.default, value: viewModel.filteredApps.count)
                }
            }
        }
    }
}
