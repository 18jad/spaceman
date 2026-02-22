import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: ScanViewModel
    var cleanupQueue: CleanupQueue

    var body: some View {
        VStack(spacing: 0) {

            if viewModel.isScanning && viewModel.currentChildren.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Scanning...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("\(SizeFormatter.formatCount(viewModel.scanProgress)) files")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Navigation header when inside a subfolder
                if viewModel.canGoBack {
                    HStack(spacing: 0) {
                        Button {
                            viewModel.navigateBack()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                if let current = viewModel.currentNode {
                                    Image(nsImage: current.icon)
                                        .resizable()
                                        .frame(width: 16, height: 16)

                                    Text(current.name)
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Go Back")

                        Spacer()

                        Button {
                            viewModel.navigateToRoot()
                        } label: {
                            Image(systemName: "arrow.up.to.line")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Go to Root")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

                    Divider()
                }

                List(selection: $viewModel.selectedNodes) {
                    ForEach(viewModel.currentChildren) { node in
                        SidebarRow(
                            node: node,
                            parentSize: viewModel.currentNode?.size ?? 1,
                            isQueued: cleanupQueue.contains(node),
                            onQueueToggle: { cleanupQueue.toggle(node) }
                        )
                        .tag(node.id)
                    }
                }
                .listStyle(.sidebar)
                .background {
                    SidebarDoubleClickDetector {
                        if let id = viewModel.selectedNodes.first,
                           let node = viewModel.currentChildren.first(where: { $0.id == id }),
                           node.isDirectory {
                            viewModel.navigateInto(node)
                        }
                    }
                }
                .onChange(of: viewModel.selectedNodes) { oldValue, newValue in
                    let added = newValue.subtracting(oldValue)
                    if let newId = added.first,
                       let node = viewModel.currentNode?.children.first(where: { $0.id == newId }) {
                        viewModel.selectedNode = node
                    } else if newValue.count == 1,
                              let id = newValue.first,
                              let node = viewModel.currentNode?.children.first(where: { $0.id == id }) {
                        viewModel.selectedNode = node
                    } else if newValue.isEmpty {
                        viewModel.selectedNode = nil
                    }
                }
            }
        }
    }
}

// MARK: - Double Click Detector (NSView-based event monitor)

/// Placed as .background on the List. Uses NSEvent local monitor
/// to detect double-clicks within its bounds without intercepting any events.
private struct SidebarDoubleClickDetector: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> SidebarDoubleClickNSView {
        let view = SidebarDoubleClickNSView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: SidebarDoubleClickNSView, context: Context) {
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        func handleDoubleClick() { action() }
    }
}

private class SidebarDoubleClickNSView: NSView {
    weak var coordinator: SidebarDoubleClickDetector.Coordinator?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                self?.handleEvent(event)
                return event  // Always pass through so List selection works
            }
        } else if window == nil {
            removeMonitor()
        }
    }

    private func handleEvent(_ event: NSEvent) {
        guard event.clickCount >= 2,
              let window = self.window,
              event.window === window else { return }

        // Check if the double-click is within our bounds (= the List's bounds)
        let pointInView = self.convert(event.locationInWindow, from: nil)
        guard self.bounds.contains(pointInView) else { return }

        coordinator?.handleDoubleClick()
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - Sidebar Row

struct SidebarRow: View {
    let node: FileNode
    let parentSize: Int64
    let isQueued: Bool
    let onQueueToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: node.icon)
                .resizable()
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.callout)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(node.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if node.isDirectory && node.fileCount > 0 {
                        Text("\(SizeFormatter.formatCount(node.fileCount)) items")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            sizeBar

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
        .padding(.vertical, 3)
    }

    private var sizeBar: some View {
        let percentage = parentSize > 0
            ? CGFloat(node.size) / CGFloat(parentSize)
            : 0

        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color(.separatorColor).opacity(0.15))
                .frame(width: 40, height: 4)

            Capsule()
                .fill(node.displayColor.opacity(0.6))
                .frame(width: max(2, 40 * percentage), height: 4)
        }
    }
}
