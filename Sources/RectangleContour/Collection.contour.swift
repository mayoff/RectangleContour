import CoreGraphics

extension Collection where Element == CGRect {
    /// Compute the contour of my elements.
    ///
    /// The contour is the polygonal union of my rectangles. Every point in the contour is in at least one of my rectangles, and every point in one (or more) of my rectangles is in the contour.
    ///
    /// Note that the contour is, in general, different than what you get by combining the rectangles with the `union` method of `CGRect`. The `union` method returns the smallest rectangle that encloses all the points of both rectangles. But since `union` returns a rectangle, it may return a rectangle that contains points outside either of its inputs.
    ///
    /// For example, consider these two overlapping input rectangles `a` and `b`:
    ///
    ///     ┌────┐
    ///     │  ┌─┼─┐
    ///     └──┼─┘ │
    ///        └───┘
    ///
    /// The result of `a.union(b)` is a rectangle:
    ///
    ///     ┌──────┐
    ///     │      │
    ///     │      │
    ///     └──────┘
    ///
    /// But the result of `[a, b].contour()` is a non-rectangular shape:
    ///
    ///     ┌─◅──┐
    ///     │    └─┐
    ///     └──┐   │
    ///        └───┘
    ///
    /// The arrow indicates the order in which the vertices are returned: counter-clockwise.
    ///
    /// If the input is disjoint, the contour contains multiple disjoint shapes too. For example, given these input rectangles:
    ///
    ///     ┌────┐     ┌──┐
    ///     │  ┌─┼─┐ ┌─┼─┐│
    ///     └──┼─┘ │ │ └─┼┘
    ///        └───┘ └───┘
    ///
    /// I return a contour containing two shapes:
    ///
    ///     ┌─◅──┐     ┌◅─┐
    ///     │    └─┐ ┌─┘  │
    ///     └──┐   │ │   ┌┘
    ///        └───┘ └───┘
    ///
    /// The input rectangles may form a loop with a hole:
    ///
    ///      ┌┐  ┌┐
    ///     ┌┼┼──┼┼┐
    ///     └┼┼──┼┼┘
    ///     ┌┼┼──┼┼┐
    ///     └┼┼──┼┼┘
    ///      └┘  └┘
    ///
    /// Then the output contains two cycles, one for the outer boundary and one for the hole:
    ///
    ///      ┌┐  ┌┐
    ///     ┌┘└◅─┘└┐
    ///     └┐┌─▻┐┌┘
    ///     ┌┘└──┘└┐
    ///     └┐┌──┐┌┘
    ///      └┘  └┘
    ///
    /// Note that the hole's vertices are given in clockwise order.
    ///
    /// The input rectangles may even form a loop with rectangles inside the hole:
    ///
    ///     ┌┬────┬┐
    ///     ├┼────┼┤
    ///     ││┌─┐ ││
    ///     │││┌┼┐││
    ///     ││└┼┘│││
    ///     ││ └─┘││
    ///     ├┼────┼┤
    ///     └┴────┴┘
    ///
    /// Then the output contains three cycles:
    ///
    ///     ┌──◅───┐
    ///     │┌──▻─┐│
    ///     ││┌◅┐ ││
    ///     │││ └┐││
    ///     ││└┐ │││
    ///     ││ └─┘││
    ///     │└────┘│
    ///     └──────┘
    ///
    /// Cycles may thus be nested arbitrarily deep.
    ///
    /// - returns: The contour of my input.
    public func contour() -> IsoOrientedContour {
        let edges = contourEdges()

        let vertices: [ContourVertex] = edges.indices.reduce(into: []) { vertices, i in
            vertices.append(edges[i].startVertex(index: i))
            vertices.append(edges[i].endVertex(index: i))
        }.sorted()

        var links: [Int: Int] = stride(from: 0, to: vertices.count, by: 2)
            .reduce(into: [:]) { links, v in
                precondition(vertices[v].isEnd != vertices[v+1].isEnd)
                if vertices[v].isEnd {
                    links[vertices[v].edgeIndex] = vertices[v+1].edgeIndex
                } else {
                    links[vertices[v+1].edgeIndex] = vertices[v].edgeIndex
                }
            }

        var cycles: [IsoOrientedContour.Cycle] = []
        while let first = links.popFirst() {
            var cycle: [CGPoint] = []
            cycle.append(edges[first.key].end)
            var prior = first.value
            cycle.append(edges[prior].start)
            while let next = links.removeValue(forKey: prior) {
                cycle.append(edges[prior].end)
                prior = next
                cycle.append(edges[prior].start)
            }

            cycles.append(.init(cycle))
        }

        return .init(cycles: cycles)
    }
    
    func contourEdges() -> [ContourEdge] {
        let nonEmpties = self.lazy.filter { !$0.isEmpty }

        // All unique y coordinates (“ordinates” in the paper), sorted lowest-first. The indices of this array are the bounds of segment spans in the segment tree.
        let ys = nonEmpties.reduce(into: Set<CGFloat>()) {
            $0.insert($1.origin.y)
            $0.insert($1.origin.y + $1.size.height)
        }.sorted()

        // I need this because SegmentTree can't handle size 0.
        guard !ys.isEmpty else { return [] }

        let iForY: [CGFloat: Int] = ys.reduce(into: [:]) { $0[$1] = $0.count }
        let verts = nonEmpties.reduce(into: [Vert]()) {
            $0.append($1.enteringVert(iForY: iForY))
            $0.append($1.exitingVert(iForY: iForY))
        }.sorted()

        var tree = SegmentTree(size: ys.count)

        var contourEndpoints: [Int] = []
        func addContourVertices(_ span: Span) {
            if contourEndpoints.last == span.lowerBound {
                contourEndpoints.removeLast()
            } else {
                contourEndpoints.append(span.lowerBound)
            }
            contourEndpoints.append(span.upperBound)
        }
        
        var edges: [ContourEdge] = []
        
        for vert in verts {
            contourEndpoints.removeAll(keepingCapacity: true)

            switch vert.crossingType {
            case .entering:
                tree.insert(vert.span, addContourVertices: addContourVertices(_:))
            case .exiting:
                tree.remove(vert.span, addContourVertices: addContourVertices(_:))
            }
            
            precondition(contourEndpoints.count.isMultiple(of: 2))
            
            for i in stride(from: 0, to: contourEndpoints.count, by: 2) {
                edges.append(.init(
                    x: vert.x,
                    y0: ys[contourEndpoints[i]],
                    y1: ys[contourEndpoints[i+1]],
                    crossingType: vert.crossingType
                ))
            }
        }
        
        return edges
    }
}

enum CrossingType: Comparable {
    case entering
    case exiting

    var opposite: Self { self == .entering ? .exiting : .entering }
}

/// A vertical edge of an input rectangle, with the y coordinates converted to indices in ys.
fileprivate struct Vert: Comparable {
    var x: CGFloat
    var start: Int // index in ys
    var end: Int // index in ys
    var crossingType: CrossingType

    var span: Span { start ..< end }
    
    var tuple: (CGFloat, CrossingType, Int, Int) { (x, crossingType, start, end) }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.tuple < rhs.tuple }
}

extension CGRect {
    fileprivate func enteringVert(iForY: [CGFloat: Int]) -> Vert {
        return .init(x: minX, start: iForY[minY]!, end: iForY[maxY]!, crossingType: .entering)
    }
    
    fileprivate func exitingVert(iForY: [CGFloat: Int]) -> Vert {
        return .init(x: maxX, start: iForY[minY]!, end: iForY[maxY]!, crossingType: .exiting)
    }
}

/// A vertical edge of the contour.
struct ContourEdge {
    var x: CGFloat
    var y0: CGFloat
    var y1: CGFloat
    var crossingType: CrossingType

    func startVertex(index: Int) -> ContourVertex {
        return .init(x: x, y: crossingType == .entering ? y1 : y0, edgeIndex: index, isEnd: false)
    }

    func endVertex(index: Int) -> ContourVertex {
        return .init(x: x, y: crossingType == .entering ? y0 : y1, edgeIndex: index, isEnd: true)
    }

    var start: CGPoint { .init(x: x, y: crossingType == .entering ? y1 : y0) }
    var end: CGPoint { .init(x: x, y: crossingType == .entering ? y0 : y1) }
}

struct ContourVertex: Comparable {
    var x: CGFloat
    var y: CGFloat
    var edgeIndex: Int
    var isEnd: Bool

    var tuple: (CGFloat, CGFloat) { (y, x) }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.tuple < rhs.tuple }
}

fileprivate typealias Span = Range<Int>

extension Range where Bound == Int {
    /// If I'm the span of a `Segment`, this is the size of the segment's left child.
    fileprivate var leftChildSize: Int { (count - 1).floorP2 }
    
    fileprivate func fullyContains(_ other: Self) -> Bool {
        return lowerBound <= other.lowerBound && other.upperBound <= upperBound
    }
}

/// A segment tree. The paper describes the use of the segment tree in section 3.
fileprivate struct SegmentTree {
    /*
     I store the segment tree very differently than the paper does. In my implementation, I don't need to start the beginning or ending segment indices of any segment, nor any child pointers. Thus I do not the `B`, `E`, `LSON`, and `RSON` arrays the paper uses. I only need the `C` (insertion count) and `STATUS` arrays, and the segment size of the root.

     Conceptually, a segment tree T (in my implementation) is a recursive data structure with either zero or two children. Let N = the segment size of T.

     - If N = 1, then the tree is a leaf (no children).
     - If N > 1 and N = 2ⁱ for some i, then the tree has two children, each with a segment size of N/2.
     - If N > 1 and N is not a power of 2, then let C be the largest power of two such that C < N. T's left child is a tree with segment size C, and T's right child is a tree with segment size N - C.
     
     Thus if T has a left child, it also has a right child, and the left child is a perfect binary tree. The effect is that T is balanced: T's deepest descendant is ⌈log₂ N⌉ links away from T.
     
     Furthermore, if T contains any imperfect subtrees, then those imperfect trees are T, T's right child, T's right-right grandchild, T's right-right-right great-grandchild, and so on. That is, the roots of the imperfect trees are some prefix of the right spine of T. The result is that I can store all nodes of the tree consecutively in an array `nodes` without parent or child pointers. To store `T` starting at index `t` in `nodes`, I store T's own node at `nodes[t]`, then I store T's left child (and its descendants) starting at `nodes[t+1]`, then I store T's right child (and its descendants) starting immediately after the left child's nodes.
     */
    
    let size: Int
    var segments: [Segment]
    
    /// The “address” of a segment is its index in `segments` and its span. I have to track the span because otherwise I cannot compute the indices of its children.
    struct Address {
        let i: Int
        let span: Span
        
        var children: (left: Address, right: Address)? {
            guard span.count > 1 else { return nil }
            
            let l = span.leftChildSize
            // The left child is always a perfect tree with l leaves, so it has 2*l - 1 nodes total.
            let lCount = 2 * l - 1
            let mid = span.lowerBound + l
            return (
                left: .init(i: i + 1, span: span.lowerBound ..< mid),
                right: .init(i: i + 1 + lCount, span: mid ..< span.upperBound)
            )
        }
    }
    
    init(size: Int) {
        precondition(size > 0)
        self.size = size
        segments = []
        segments.reserveCapacity(2 * size - 1)
        appendSubtree(span: 0 ..< size-1)
    }
    
    private var root: Address { .init(i: 0, span: 0 ..< size-1) }
    
    private mutating func appendSubtree(span: Span) {
        precondition(!span.isEmpty)
        segments.append(.init())
        guard span.count > 1 else { return }
        let mid = span.lowerBound + span.leftChildSize
        appendSubtree(span: span.lowerBound ..< mid)
        appendSubtree(span: mid ..< span.upperBound)
    }
    
    mutating func insert(_ span: Span, addContourVertices: (Span) -> Void) {
        precondition(!span.isEmpty)
        precondition((0 ..< size).contains(span.lowerBound))
        precondition((1 ... size).contains(span.upperBound))
        
        let root = self.root
        insert(span, into: root, addContourVertices: addContourVertices, shouldNotify: true)
    }
    
    private mutating func insert(_ span: Span, into address: Address, addContourVertices: (Span) -> Void, shouldNotify: Bool) {
        precondition(span.overlaps(address.span))
    
        guard !span.fullyContains(address.span) else {
            if shouldNotify {
                notify(forSpanOf: address, using: addContourVertices)
            }
            segments[address.i].insertions += 1
            segments[address.i].status = .full
            return
        }

        guard let (left: left, right: right) = address.children else {
            preconditionFailure("span doesn't fully contain leaf node, which should be impossible")
        }
        
        let mid = left.span.upperBound

        if span.lowerBound < mid {
            insert(
                span, into: left,
                addContourVertices: addContourVertices,
                // If the current segment is full, none of its descendants should contribute vertices, but they still need to be updated.
                shouldNotify: shouldNotify && segments[address.i].status != .full
            )
        }
        if mid < span.upperBound {
            insert(
                span, into: right,
                addContourVertices: addContourVertices,
                // If the current segment is full, none of its descendants should contribute vertices, but they still need to be updated.
                shouldNotify: shouldNotify && segments[address.i].status != .full
            )
        }
        
        // Since `span.overlaps(address.span)` but `!span.fullyContains(address.span)`, it must be that `span.fullyContains(d.span)` for some descendant `d` of `address`. Therefore:
        segments[address.i].status = max(segments[address.i].status, .partial)
    }

    // In the paper, this method is called `COMPL` and accesses a global called `STACK`. In my implementation, the `note` function encapsulates access to `STACK`.
    //
    // The paper's `INSERT` (and `DELETE`) calls `COMPL` more than it should. If the triggering segment has a `.full` ancestor, then neither the triggering segment nor any of its descendants actually contribute to the contour (at the current x value). I correct this bug in my `insert` and `remove` methods by passing down a `shouldNotify` flag which starts out `true` and becomes `false` for all descendants of `.full` segments.
    private func notify(forSpanOf address: Address, using note: (Span) -> Void) {
        switch segments[address.i].status {
        case .empty:
            note(address.span)
            
        case .partial:
            guard let children = address.children else { break }
            notify(forSpanOf: children.left, using: note)
            notify(forSpanOf: children.right, using: note)
            
        case .full:
            break
        }
    }
    
    mutating func remove(_ span: Span, addContourVertices: (Span) -> Void) {
        precondition(!span.isEmpty)
        precondition((0 ..< size).contains(span.lowerBound))
        precondition((1 ... size).contains(span.upperBound))
        
        let root = self.root
        remove(span, from: root, addContourVertices: addContourVertices, shouldNotify: true)
    }
    
    private mutating func remove(_ span: Span, from address: Address, addContourVertices: (Span) -> Void, shouldNotify: Bool) {
        precondition(span.overlaps(address.span))
        
        let children = address.children

        func updateStatus() {
            if segments[address.i].insertions > 0 {
                segments[address.i].status = .full
            } else if let (left: left, right: right) = children {
                segments[address.i].status = max(segments[left.i].status, segments[right.i].status) == .empty ? .empty : .partial
            } else {
                segments[address.i].status = .empty
            }
        }

        guard !span.fullyContains(address.span) else {
            // I have to update the current segment's status before calling notify (if I'm due to call notify). The paper does not mention this need.
            segments[address.i].insertions -= 1
            updateStatus()
            if shouldNotify {
                notify(forSpanOf: address, using: addContourVertices)
            }
            return
        }

        guard let (left: left, right: right) = children else {
            preconditionFailure("span doesn't fully contain leaf node, which should be impossible")
        }

        let mid = left.span.upperBound
        if span.lowerBound < mid {
            remove(
                span, from: left,
                addContourVertices: addContourVertices,
                // If the current segment is full, none of its descendants should contribute vertices, but they still need to be updated.
                shouldNotify: shouldNotify && segments[address.i].status != .full
            )
        }
        if mid < span.upperBound {
            remove(
                span, from: right,
                addContourVertices: addContourVertices,
                // If the current segment is full, none of its descendants should contribute vertices, but they still need to be updated.
                shouldNotify: shouldNotify && segments[address.i].status != .full
            )
        }

        updateStatus()
    }
}

fileprivate struct Segment {
    var insertions: Int = 0
    var status: Status = .empty
    
    enum Status: Comparable {
        case empty
        case partial
        case full
    }
}

extension Int {
    /// Return the largest power of 2 that is not larger than `self`.
    fileprivate var floorP2: Self { 1 << (bitWidth - 1 - leadingZeroBitCount) }
}

extension Sequence where Element: Hashable {
    fileprivate func makeSet() -> Set<Element> { Set(self) }
}
