import CoreGraphics

/// An `IsoOrientedContour` is a set of mutually non-intersecting iso-oriented cycles. A cycle is the sequence of vertices of an iso-oriented simple polygon.
///
/// Iso-oriented means all edges are either horizontal or vertical.
///
/// A simple polygon is one without self-intersections.
///
/// A `Cycle` may lie in the interior of another `Cycle`. The inner `Cycle` represents a hole in the contour, and its vertices are in clockwise order. A non-hole `Cycle`'s vertices are in counter-clockwise order.
///
/// A clockwise `Cycle` is a hole. A non-clockwise `Cycle` is a fill.
///
/// `IsoOrientedContour` doesn't enforce the invariants described above. However, any `IsoOrientedContour` returned by `Collection::contour` satisfies them.
public struct IsoOrientedContour: Equatable {
    public var cycles: [Cycle]

    public init(cycles: [Cycle]) {
        self.cycles = cycles
    }

    /// A `Cycle` is the sequence of vertices of an iso-oriented simple polygon. To create a closed path from my vertices, you must connect the last vertex back to the first.
    public struct Cycle: Equatable {
        public var vertices: [CGPoint]

        public init(_ vertices: [CGPoint]) {
            precondition(!vertices.isEmpty)
            self.vertices = vertices
        }

        /// Rotate my vertices so that the leftest, lowest point is first.
        public mutating func normalize() {
            guard
                let i = vertices.indices.min(by: { vertices[$0].tuple < vertices[$1].tuple })
            else { return }
            vertices[..<i].reverse()
            vertices[i...].reverse()
            vertices.reverse()
        }

        /// Apply `transform` to each of my vertices.
        ///
        /// - parameter transform: An affine transform.
        /// - returns: A `Cycle` whose vertices are my transformed vertices.
        public func applying(_ transform: CGAffineTransform) -> Self {
            return .init(vertices.map { $0.applying(transform) })
        }
    }

    /// Normalize each of my cycles, then sort my cycles so the cycle with the leftest, lowest first point is first.
    public mutating func normalize() {
        for i in cycles.indices {
            cycles[i].normalize()
        }

        cycles.sort {
            for (l, r) in zip($0.vertices, $1.vertices) {
                if l.tuple < r.tuple { return true }
                if l.tuple > r.tuple { return false }
            }
            return $0.vertices.count < $1.vertices.count
        }
    }

    /// - returns: A copy of me that has had its `normalize` method called.
    public func normalized() -> Self {
        var copy = self
        copy.normalize()
        return copy
    }

    /// Apply `transform` to each vertex of each of my cycles.
    ///
    /// - parameter transform: An affine transform.
    /// - returns: An `IsoOrientedContour` whose cycles are my transformed cycles.
    public func applying(_ transform: CGAffineTransform) -> Self {
        return .init(cycles: cycles.map { $0.applying(transform) })
    }

    /// Create a `CGPath` from my cycles.
    ///
    /// - returns: A `CGPath`.
    public func cgPath() -> CGPath {
        let path = CGMutablePath()

        for cycle in cycles {
            cycle.add(to: path)
        }

        return path.copy()!
    }

    /// Create a `CGPath` from my cycles, with rounded corners.
    ///
    /// - parameter cornerRadius: The radius to use to round the corners of the returned path. If an edge of the path is shorter than `2 * cornerRadius`, I shorten the corners attached to that edge to half of the edge's length.
    public func cgPath(cornerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for cycle in cycles {
            cycle.add(to: path, cornerRadius: cornerRadius)
        }
        return path
    }
}

extension IsoOrientedContour.Cycle {
    fileprivate func add(to path: CGMutablePath) {
        guard let start = vertices.first else { return }
        path.move(to: start)
        for p in vertices.dropFirst() {
            path.addLine(to: p)
        }
        path.closeSubpath()
    }

    fileprivate func add(to path: CGMutablePath, cornerRadius: CGFloat) {
        guard
            let last = vertices.last,
            let first = vertices.first
        else {
            add(to: path)
            return
        }

        var p = 0.5 * (last + first)
        path.move(to: p)

        var corner = first

        func addArc(next: CGPoint) {
            let q = 0.5 * (corner + next)
            let radius = min(
                cornerRadius,
                min(
                    abs(p.x - corner.x) + abs(p.y - corner.y),
                    abs(q.x - corner.x) + abs(q.y - corner.y)
                )
            )
            path.addArc(tangent1End: corner, tangent2End: q, radius: radius)
            p = q
            corner = next
        }

        for next in vertices.dropFirst() {
            addArc(next: next)
        }

        addArc(next: first)
        path.closeSubpath()
    }
}

fileprivate func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}

fileprivate func * (lhs: CGFloat, rhs: CGPoint) -> CGPoint {
    return .init(x: lhs * rhs.x, y: lhs * rhs.y)
}

extension CGPoint {
    fileprivate var tuple: (CGFloat, CGFloat) { (x, y) }
}
