import SwiftUI
import AppKit

// MARK: - SwiftUI Wrapper (thin — layout lives in the NSView)

struct TreemapView: View {
    @Bindable var viewModel: ScanViewModel
    var cleanupQueue: CleanupQueue
    @AppStorage(AppSettings.Key.treemapMaxItems) private var maxItems = AppSettings.Default.treemapMaxItems
    @AppStorage(AppSettings.Key.showEmptyItems) private var showEmptyItems = AppSettings.Default.showEmptyItems

    private var displayNodes: [FileNode] {
        let filtered = showEmptyItems
            ? viewModel.currentChildren
            : viewModel.currentChildren.filter { $0.size > 0 }
        return Array(filtered.prefix(maxItems))
    }

    var body: some View {
        if viewModel.currentChildren.isEmpty {
            emptyState
        } else {
            TreemapNSViewWrapper(
                nodes: displayNodes,
                selectedIds: viewModel.selectedNodes,
                queuedIds: Set(cleanupQueue.items.map(\.id)),
                onSelect: { node, isCmd, isShift in
                    viewModel.handleClick(node, isCommandDown: isCmd, isShiftDown: isShift)
                },
                onNavigate: { viewModel.navigateInto($0) },
                onHover: { viewModel.hoveredNode = $0 },
                onQueueToggle: { cleanupQueue.toggle($0) },
                onTrash: { nodes in
                    if nodes.count == 1 {
                        viewModel.selectedNode = nodes[0]
                        Task { await viewModel.deleteSelected() }
                    } else {
                        Task { await viewModel.deleteSelectedNodes() }
                    }
                },
                onDelete: { nodes in
                    if nodes.count == 1 {
                        viewModel.selectedNode = nodes[0]
                        Task { await viewModel.permanentlyDeleteSelected() }
                    } else {
                        Task { await viewModel.permanentlyDeleteSelectedNodes() }
                    }
                },
                onPurge: { nodes in
                    if nodes.count == 1 {
                        viewModel.selectedNode = nodes[0]
                        Task { await viewModel.purgeSelected() }
                    } else {
                        Task { await viewModel.purgeSelectedNodes() }
                    }
                }
            )
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.isScanning {
            VStack(spacing: 12) {
                ProgressView().scaleEffect(1.5)
                Text("Scanning...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView {
                Label("Empty Folder", systemImage: "folder")
            } description: {
                Text("This folder has no contents to display")
            }
        }
    }
}

// MARK: - NSViewRepresentable Bridge

struct TreemapNSViewWrapper: NSViewRepresentable {
    let nodes: [FileNode]
    let selectedIds: Set<UUID>
    let queuedIds: Set<UUID>
    let onSelect: (FileNode, Bool, Bool) -> Void  // (node, isCmd, isShift)
    let onNavigate: (FileNode) -> Void
    let onHover: (FileNode?) -> Void
    let onQueueToggle: (FileNode) -> Void
    let onTrash: ([FileNode]) -> Void
    let onDelete: ([FileNode]) -> Void
    let onPurge: ([FileNode]) -> Void

    func makeNSView(context: Context) -> TreemapDrawingView {
        let view = TreemapDrawingView()
        view.autoresizingMask = [.width, .height]
        view.onSelect = onSelect
        view.onNavigate = onNavigate
        view.onHover = onHover
        view.onQueueToggle = onQueueToggle
        view.onTrash = onTrash
        view.onDelete = onDelete
        view.onPurge = onPurge
        view.nodes = nodes
        view.selectedIds = selectedIds
        view.queuedIds = queuedIds
        return view
    }

    func updateNSView(_ nsView: TreemapDrawingView, context: Context) {
        nsView.onSelect = onSelect
        nsView.onNavigate = onNavigate
        nsView.onHover = onHover
        nsView.onQueueToggle = onQueueToggle
        nsView.onTrash = onTrash
        nsView.onDelete = onDelete
        nsView.onPurge = onPurge

        // Update queued IDs
        if nsView.queuedIds != queuedIds {
            let oldIds = nsView.queuedIds
            nsView.queuedIds = queuedIds
            for id in oldIds.symmetricDifference(queuedIds) {
                nsView.invalidateCell(id: id)
            }
        }

        let nodesChanged = nsView.nodes.count != nodes.count
            || nsView.nodes.first?.id != nodes.first?.id
            || nsView.nodes.last?.id != nodes.last?.id

        if nodesChanged {
            nsView.nodes = nodes
            nsView.selectedIds = selectedIds
            return
        }

        if nsView.selectedIds != selectedIds {
            let oldIds = nsView.selectedIds
            nsView.selectedIds = selectedIds
            for id in oldIds.symmetricDifference(selectedIds) {
                nsView.invalidateCell(id: id)
            }
        }
    }
}

// MARK: - Raw AppKit Drawing View

final class TreemapDrawingView: NSView {

    // Data — setting nodes triggers layout recompute
    var nodes: [FileNode] = [] {
        didSet { recomputeLayout() }
    }

    private(set) var items: [TreemapItem] = []
    var selectedIds: Set<UUID> = []
    var queuedIds: Set<UUID> = []
    var hoveredId: UUID?

    var onSelect: ((FileNode, Bool, Bool) -> Void)?  // (node, isCmd, isShift)
    var onNavigate: ((FileNode) -> Void)?
    var onHover: ((FileNode?) -> Void)?
    var onQueueToggle: ((FileNode) -> Void)?
    var onTrash: (([FileNode]) -> Void)?
    var onDelete: (([FileNode]) -> Void)?
    var onPurge: (([FileNode]) -> Void)?

    override var isFlipped: Bool { true }

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    // MARK: - Frame changes → recompute layout

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        recomputeLayout()
    }

    private func recomputeLayout() {
        guard bounds.width > 0, bounds.height > 0, !nodes.isEmpty else {
            items = []
            needsDisplay = true
            return
        }
        items = TreemapLayout.compute(nodes: nodes, in: bounds)
        hoveredId = nil
        needsDisplay = true
    }

    // MARK: - Tracking Area

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        ))
    }

    // MARK: - Drawing (Core Graphics — only redraws dirtyRect)

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        ctx.setFillColor(NSColor.windowBackgroundColor.cgColor)
        ctx.fill(dirtyRect)

        for item in items {
            let inset = item.rect.insetBy(dx: 1.5, dy: 1.5)
            guard inset.width > 1, inset.height > 1 else { continue }
            guard inset.intersects(dirtyRect) else { continue }

            let isHovered = hoveredId == item.id
            let isSelected = selectedIds.contains(item.id)

            let maxRadius = min(inset.width, inset.height) / 4
            let radius = min(4, maxRadius)
            let path = CGPath(roundedRect: inset, cornerWidth: radius, cornerHeight: radius, transform: nil)

            let alpha: CGFloat = isHovered ? 0.95 : 0.78
            ctx.setFillColor(item.color.withAlphaComponent(alpha).cgColor)
            ctx.addPath(path)
            ctx.fillPath()

            if isSelected {
                ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
                ctx.setLineWidth(2.5)
                ctx.addPath(path)
                ctx.strokePath()
            } else if isHovered {
                ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.35).cgColor)
                ctx.setLineWidth(1)
                ctx.addPath(path)
                ctx.strokePath()
            }

            guard inset.width > 50, inset.height > 24 else { continue }

            let padding: CGFloat = 6
            let textRect = inset.insetBy(dx: padding, dy: padding)
            let fontSize = Self.fontSize(for: inset.size)

            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: NSColor.white,
            ]
            (item.name as NSString).draw(
                with: CGRect(x: textRect.minX, y: textRect.minY,
                             width: textRect.width, height: fontSize + 4),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: nameAttrs
            )

            guard inset.height > 42 else { continue }

            let sizeAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: max(8, fontSize - 2)),
                .foregroundColor: NSColor.white.withAlphaComponent(0.8),
            ]
            (item.formattedSize as NSString).draw(
                with: CGRect(x: textRect.minX, y: textRect.minY + fontSize + 3,
                             width: textRect.width, height: fontSize),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: sizeAttrs
            )

            // Queue button — only on hovered cell, if cell is big enough
            if isHovered && inset.width > 30 && inset.height > 30 {
                let btnSize: CGFloat = 22
                let btnRect = CGRect(
                    x: inset.maxX - btnSize - 4,
                    y: inset.minY + 4,
                    width: btnSize,
                    height: btnSize
                )

                let isQueued = queuedIds.contains(item.id)

                ctx.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor)
                ctx.fillEllipse(in: btnRect)

                if isQueued {
                    ctx.setStrokeColor(NSColor.systemGreen.cgColor)
                    ctx.setLineWidth(2)
                    ctx.setLineCap(.round)
                    ctx.setLineJoin(.round)
                    ctx.move(to: CGPoint(x: btnRect.minX + 6, y: btnRect.midY))
                    ctx.addLine(to: CGPoint(x: btnRect.minX + 9.5, y: btnRect.midY + 3.5))
                    ctx.addLine(to: CGPoint(x: btnRect.maxX - 5.5, y: btnRect.midY - 3))
                    ctx.strokePath()
                } else {
                    ctx.setStrokeColor(NSColor.white.cgColor)
                    ctx.setLineWidth(2)
                    ctx.setLineCap(.round)
                    let center = CGPoint(x: btnRect.midX, y: btnRect.midY)
                    let arm: CGFloat = 5
                    ctx.move(to: CGPoint(x: center.x - arm, y: center.y))
                    ctx.addLine(to: CGPoint(x: center.x + arm, y: center.y))
                    ctx.move(to: CGPoint(x: center.x, y: center.y - arm))
                    ctx.addLine(to: CGPoint(x: center.x, y: center.y + arm))
                    ctx.strokePath()
                }
            }
        }
    }

    private static func fontSize(for size: CGSize) -> CGFloat {
        let area = size.width * size.height
        if area > 40000 { return 13 }
        if area > 15000 { return 11 }
        if area > 5000 { return 10 }
        return 9
    }

    // MARK: - Mouse Events

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let hit = items.first { $0.rect.contains(point) }

        guard hit?.id != hoveredId else { return }

        let oldId = hoveredId
        hoveredId = hit?.id
        onHover?(hit?.node)

        invalidateCell(id: oldId)
        invalidateCell(id: hit?.id)
    }

    override func mouseExited(with event: NSEvent) {
        guard hoveredId != nil else { return }
        let oldId = hoveredId
        hoveredId = nil
        onHover?(nil)
        invalidateCell(id: oldId)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let item = items.first(where: { $0.rect.contains(point) }) else { return }

        if event.clickCount >= 2 {
            if item.node.isDirectory {
                onNavigate?(item.node)
            }
            return
        }

        // Check if click is on the queue "+" button
        let inset = item.rect.insetBy(dx: 1.5, dy: 1.5)
        if hoveredId == item.id && inset.width > 30 && inset.height > 30 {
            let btnSize: CGFloat = 22
            let btnRect = CGRect(
                x: inset.maxX - btnSize - 4,
                y: inset.minY + 4,
                width: btnSize,
                height: btnSize
            )
            if btnRect.contains(point) {
                onQueueToggle?(item.node)
                invalidateCell(id: item.id)
                return
            }
        }

        let isCmd = event.modifierFlags.contains(.command)
        let isShift = event.modifierFlags.contains(.shift)
        onSelect?(item.node, isCmd, isShift)
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let item = items.first(where: { $0.rect.contains(point) }) else { return }

        if !selectedIds.contains(item.id) {
            onSelect?(item.node, false, false)
        }

        let selectedItems = items.filter { selectedIds.contains($0.id) }
        let selectedNodesList = selectedItems.map { $0.node }
        let isMulti = selectedNodesList.count > 1

        let menu = NSMenu()

        if !isMulti {
            menu.addItem(makeMenuItem("Show in Finder", action: #selector(actShowInFinder(_:)), node: item.node))
            menu.addItem(makeMenuItem("Copy Path", action: #selector(actCopyPath(_:)), node: item.node))
            menu.addItem(.separator())

            if item.node.isDirectory {
                menu.addItem(makeMenuItem("Open", action: #selector(actOpen(_:)), node: item.node))
            }

            menu.addItem(makeMenuItem("Move to Trash", action: #selector(actTrash(_:)), node: item.node))
            menu.addItem(makeMenuItem("Delete Permanently", action: #selector(actDelete(_:)), node: item.node))

            if item.node.pathExtension == "app" {
                menu.addItem(.separator())
                menu.addItem(makeMenuItem("Purge App & Data", action: #selector(actPurge(_:)), node: item.node))
            }

            menu.addItem(.separator())
            let queueTitle = queuedIds.contains(item.id) ? "Remove from Cleanup Queue" : "Add to Cleanup Queue"
            menu.addItem(makeMenuItem(queueTitle, action: #selector(actQueueToggle(_:)), node: item.node))
        } else {
            let trashItem = NSMenuItem(title: "Move \(selectedNodesList.count) Items to Trash", action: #selector(actBulkTrash(_:)), keyEquivalent: "")
            trashItem.representedObject = selectedNodesList
            trashItem.target = self
            menu.addItem(trashItem)

            let deleteItem = NSMenuItem(title: "Delete \(selectedNodesList.count) Items Permanently", action: #selector(actBulkDelete(_:)), keyEquivalent: "")
            deleteItem.representedObject = selectedNodesList
            deleteItem.target = self
            menu.addItem(deleteItem)

            let hasApps = selectedNodesList.contains { $0.pathExtension == "app" }
            if hasApps {
                menu.addItem(.separator())
                let purgeItem = NSMenuItem(title: "Purge \(selectedNodesList.count) Items & Data", action: #selector(actBulkPurge(_:)), keyEquivalent: "")
                purgeItem.representedObject = selectedNodesList
                purgeItem.target = self
                menu.addItem(purgeItem)
            }
        }

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    // MARK: - Menu Helpers

    private func makeMenuItem(_ title: String, action: Selector, node: FileNode) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.representedObject = node
        item.target = self
        return item
    }

    @objc private func actShowInFinder(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? FileNode else { return }
        NSWorkspace.shared.selectFile(
            node.path,
            inFileViewerRootedAtPath: node.parentPath
        )
    }

    @objc private func actCopyPath(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? FileNode else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(node.path, forType: .string)
    }

    @objc private func actOpen(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? FileNode else { return }
        onNavigate?(node)
    }

    @objc private func actTrash(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? FileNode else { return }
        onTrash?([node])
    }

    @objc private func actDelete(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? FileNode else { return }
        onDelete?([node])
    }

    @objc private func actPurge(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? FileNode else { return }
        onPurge?([node])
    }

    @objc private func actQueueToggle(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? FileNode else { return }
        onQueueToggle?(node)
    }

    @objc private func actBulkTrash(_ sender: NSMenuItem) {
        guard let nodes = sender.representedObject as? [FileNode] else { return }
        onTrash?(nodes)
    }

    @objc private func actBulkDelete(_ sender: NSMenuItem) {
        guard let nodes = sender.representedObject as? [FileNode] else { return }
        onDelete?(nodes)
    }

    @objc private func actBulkPurge(_ sender: NSMenuItem) {
        guard let nodes = sender.representedObject as? [FileNode] else { return }
        onPurge?(nodes)
    }

    // MARK: - Partial Redraw

    func invalidateCell(id: UUID?) {
        guard let id, let item = items.first(where: { $0.id == id }) else { return }
        setNeedsDisplay(item.rect.insetBy(dx: -4, dy: -4))
    }
}
