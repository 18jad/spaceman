import Foundation
import AppKit

struct TreemapItem: Identifiable {
    let id: UUID
    let node: FileNode
    let rect: CGRect
    let color: NSColor
    let name: String
    let formattedSize: String
}

// MARK: - Treemap Layout Engine (adapted from Yahoo's YMTreeMap)

enum TreemapLayout {

    /// Pixel alignment mode for crisp rendering.
    enum Alignment {
        case highPrecision
        case retinaSubPixel
    }

    static var alignment: Alignment = .retinaSubPixel

    // MARK: - Public API

    static func compute(nodes: [FileNode], in rect: CGRect) -> [TreemapItem] {
        guard !nodes.isEmpty, rect.width > 0, rect.height > 0 else { return [] }

        let sorted = nodes.sorted { $0.size > $1.size }

        // Give 0-byte items the smallest non-zero sibling's size so they appear.
        let smallestNonZero = Double(sorted.last(where: { $0.size > 0 })?.size ?? 1)
        let values = sorted.map { node -> Double in
            node.size > 0 ? Double(node.size) : smallestNonZero
        }

        // Compute relative weights
        let total = values.reduce(0, +)
        guard total > 0 else { return [] }
        let weights = values.map { $0 / total }

        // Tessellate
        let canvas = Rect(x: Double(rect.minX), y: Double(rect.minY),
                          width: Double(rect.width), height: Double(rect.height))
        let rects = tessellate(weights: weights, inRect: canvas)

        // Build items, filtering out cells too small to render
        let minDim: CGFloat = 6
        var items = [TreemapItem]()
        for (i, r) in rects.enumerated() {
            let cgRect = r.cgRect
            guard cgRect.width >= minDim && cgRect.height >= minDim else { continue }

            let node = sorted[i]
            let color: NSColor = node.isDirectory
                ? node.dominantCategory.nsColor
                : node.category.nsColor

            items.append(TreemapItem(
                id: node.id,
                node: node,
                rect: cgRect,
                color: color,
                name: node.name,
                formattedSize: node.formattedSize
            ))
        }
        return items
    }

    // MARK: - Internal Rect

    private struct Rect {
        var x: Double
        var y: Double
        var width: Double
        var height: Double

        var shortestEdge: Double { min(width, height) }

        var cgRect: CGRect {
            CGRect(x: x, y: y, width: width, height: height)
        }

        mutating func align() {
            if TreemapLayout.alignment == .highPrecision { return }

            let maxX = x + width
            let maxY = y + height

            x = Rect.snap(x)
            y = Rect.snap(y)
            width = Rect.snap(maxX) - x
            height = Rect.snap(maxY) - y
        }

        /// Snap to nearest half-pixel for retina crispness.
        private static func snap(_ point: Double) -> Double {
            let (integral, fractional) = modf(point)
            if fractional < 0.25 { return integral }
            if fractional < 0.75 { return integral + 0.5 }
            return integral + 1.0
        }
    }

    // MARK: - Tessellation

    private enum Direction { case horizontal, vertical }

    /// Outer loop: tessellate all weights into the canvas.
    private static func tessellate(weights: [Double], inRect rect: Rect) -> [Rect] {
        let rectArea = rect.width * rect.height
        var areas = weights.map { $0 * rectArea }

        var rects = [Rect]()
        var canvas = rect

        while !areas.isEmpty {
            var remaining = canvas
            let newRects = tessellateRow(areas: areas, inRect: canvas, remaining: &remaining)

            rects.append(contentsOf: newRects)
            canvas = remaining
            areas.removeFirst(newRects.count)
        }

        return rects
    }

    /// Inner step: find the best row of items along the short edge.
    private static func tessellateRow(areas: [Double], inRect rect: Rect, remaining: inout Rect) -> [Rect] {
        let direction: Direction
        let length: Double
        if rect.width >= rect.height {
            direction = .horizontal
            length = rect.height
        } else {
            direction = .vertical
            length = rect.width
        }

        // Greedily add items while the worst aspect ratio improves
        var bestAspect = Double.greatestFiniteMagnitude
        var groupArea: Double = 0
        var accepted = [Double]()

        for area in areas {
            let worstAspect = worstAspectRatio(
                accepted: accepted,
                groupArea: groupArea,
                proposed: area,
                length: length,
                limit: bestAspect
            )

            if worstAspect > bestAspect {
                break
            }

            accepted.append(area)
            groupArea += area
            bestAspect = worstAspect
        }

        // Layout the accepted items as a strip
        let stripThickness = groupArea / length
        var offset = direction == .horizontal ? rect.y : rect.x

        let rects = accepted.map { area -> Rect in
            let span = area / stripThickness
            let thisOffset = offset
            offset += span

            var r: Rect
            switch direction {
            case .horizontal:
                r = Rect(x: rect.x, y: thisOffset, width: stripThickness, height: span)
            case .vertical:
                r = Rect(x: thisOffset, y: rect.y, width: span, height: stripThickness)
            }
            r.align()
            return r
        }

        // Cut away the used strip from the canvas
        switch direction {
        case .horizontal:
            remaining = Rect(x: rect.x + stripThickness, y: rect.y,
                             width: rect.width - stripThickness, height: rect.height)
        case .vertical:
            remaining = Rect(x: rect.x, y: rect.y + stripThickness,
                             width: rect.width, height: rect.height - stripThickness)
        }

        return rects
    }

    // MARK: - Aspect ratio

    /// Compute the worst aspect ratio if `proposed` were added to the current row.
    /// Returns early if the ratio exceeds `limit`.
    private static func worstAspectRatio(accepted: [Double], groupArea: Double,
                                         proposed: Double, length: Double,
                                         limit: Double) -> Double {
        let totalArea = groupArea + proposed
        let width = totalArea / length

        var worst = aspectRatio(width, proposed / width)

        for area in accepted {
            let thisAspect = aspectRatio(width, area / width)
            worst = max(worst, thisAspect)
            if worst > limit { break }  // early exit optimization
        }

        return worst
    }

    private static func aspectRatio(_ a: Double, _ b: Double) -> Double {
        a > b ? a / b : b / a
    }
}
