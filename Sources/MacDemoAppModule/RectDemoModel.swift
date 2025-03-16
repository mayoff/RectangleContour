import CoreGraphics
import Foundation
import RectangleContour

enum Corner: Equatable, CaseIterable, Hashable, Identifiable {
    case x0y0
    case x0y1
    case x1y0
    case x1y1

    var id: Self { self }
}

fileprivate func + (lhs: CGPoint, rhs: CGVector) -> CGPoint {
    return .init(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
}

struct Rect: Equatable {
    typealias Id = UUID

    // Unit-space coordinates, 0 ... 1.
    var x0: CGFloat
    var y0: CGFloat
    var x1: CGFloat
    var y1: CGFloat

    subscript(corner: Corner) -> CGPoint {
        get {
            switch corner {
            case .x0y0: return .init(x: x0, y: y0)
            case .x1y0: return .init(x: x1, y: y0)
            case .x0y1: return .init(x: x0, y: y1)
            case .x1y1: return .init(x: x1, y: y1)
            }
        }

        set(p) {
            switch corner {
            case .x0y0: (x0, y0) = (p.x, p.y)
            case .x1y0: (x1, y0) = (p.x, p.y)
            case .x0y1: (x0, y1) = (p.x, p.y)
            case .x1y1: (x1, y1) = (p.x, p.y)
            }
        }
    }

    var unitRect: CGRect { .init(x: x0, y: y0, width: x1 - x0, height: y1 - y0) }

    mutating func makeZeroWidth() {
        x0 = 0.5 * x0 + 0.5 * x1
        x1 = x0
    }
}

struct RectState {
    var rect: Rect
    var z: CGFloat
    var dragState: DragState? = nil
    var cornerDrags: [Corner: CornerDragState] = [:]

    struct DragState {
        var original: Rect
    }

    struct CornerDragState {
        var original: CGPoint
    }

    enum Message {
        case corner(Corner, CornerMessage)
        case delete
        case drag(CGVector)
        case endDrag
        case makeZeroWidth
        case select
    }

    enum CornerMessage {
        case drag(CGVector)
        case endDrag
    }

    enum Request {
        case delete
        case select
    }

    mutating func apply(_ message: Message) -> Request? {
        switch message {
        case .corner(let corner, .drag(let translation)):
            if let state = cornerDrags[corner] {
                rect[corner] = state.original + translation
            } else {
                cornerDrags[corner] = .init(original: rect[corner])
                rect[corner] = rect[corner] + translation
            }
            return nil

        case .corner(let corner, .endDrag):
            cornerDrags.removeValue(forKey: corner)
            return nil

        case .delete:
            return .delete

        case .drag(let translation):
            let original: Rect
            if let state = dragState {
                original = state.original
            } else {
                original = rect
                dragState = .init(original: original)
            }
            rect[.x0y0] = original[.x0y0] + translation
            rect[.x1y1] = original[.x1y1] + translation
            return nil

        case .endDrag:
            dragState = nil
            return nil

        case .makeZeroWidth:
            rect.makeZeroWidth()
            return nil

        case .select:
            return .select
        }
    }
}

struct RectDemoModel {
    var rectStates: [Rect.Id: RectState]
    var zMax: CGFloat = 0
    var selection: Rect.Id? = nil
    var newRect: Rect.Id? = nil
    var cornerRadius: CGFloat = 10

    init() {
        let id = Rect.Id()
        rectStates = [
            id: .init(
                rect: .init(
                    x0: 1/3.0,
                    y0: 1/3.0,
                    x1: 2/3.0,
                    y1: 2/3.0
                ),
                z: zMax
            )
        ]
    }
}

extension RectDemoModel {
    enum Message {
        case deselect
        case drag(CGVector)
        case endDrag
        case rect(Rect.Id, RectState.Message)
        case setCornerRadius(CGFloat)
    }
}

extension RectDemoModel {
    mutating func apply(_ message: Message) {
        switch message {
        case .deselect:
            selection = nil

        case .drag(let translation):
            if let id = newRect {
                rectStates[id]?.rect[.x1y1] = .init(x: translation.dx, y: translation.dy)
            } else {
                let id = UUID()
                newRect = id
                zMax += 1
                rectStates[id] = .init(
                    rect: .init(
                        x0: translation.dx,
                        y0: translation.dy,
                        x1: translation.dx,
                        y1: translation.dy
                    ),
                    z: zMax
                )
            }

        case .endDrag:
            newRect = nil

        case .rect(let id, let sub):
            bringToFront(id)
            switch rectStates[id]?.apply(sub) {
            case nil:
                break
            case .delete:
                rectStates.removeValue(forKey: id)
                if selection == id {
                    selection = nil
                }
            case .select:
                selection = id
            }
            print(rectStates)

        case .setCornerRadius(let r):
            cornerRadius = r
        }
    }

    private mutating func bringToFront(_ id: Rect.Id) {
        if var rectState = rectStates[id], rectState.z < zMax {
            zMax += 1
            rectState.z = zMax
            rectStates[id] = rectState
        }
    }
}
