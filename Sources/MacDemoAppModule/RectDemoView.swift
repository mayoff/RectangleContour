import SwiftUI
import RectangleContour

fileprivate let geometry = ObjectIdentifier(RectDemoModel.self)

@available(macOS 11, *)
struct RectDemoView: View {
    let model: RectDemoModel
    let send: (RectDemoModel.Message) -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ContourView(
                rects: model.rectStates.values.map(\.rect),
                cornerRadius: model.cornerRadius
            )

            GeometryReader { geo in
                let canvasSize = geo.size

                ZStack {
                    ForEach(Array(model.rectStates.keys), id: \.self) { id in
                        RectView(
                            rectState: model.rectStates[id]!,
                            canvasSize: canvasSize,
                            cornerRadius: model.cornerRadius,
                            isSelected: model.selection == id,
                            send: { [send] in send(.rect(id, $0)) }
                        )
                            .frame(width: canvasSize.width, height: canvasSize.height)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(deselectGesture.exclusively(before: makeRectGesture(canvasSize: canvasSize)))
            }
            .coordinateSpace(name: geometry)

            HStack {
                Slider(
                    value: Binding(
                        get: { model.cornerRadius },
                        set: { send(.setCornerRadius($0)) }
                    ),
                    in: 0 ... 100
                )
                    .padding(.leading, 20)

                // For testing that the algorithm handles empty rectangles.
                Button {
                    if let id = model.selection {
                    send(.rect(id, .makeZeroWidth))
                    }
                } label: {
                    Image(systemName: "arrowtriangle.right.and.line.vertical.and.arrowtriangle.left.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .shadow(radius: 2)
                        .frame(width: 40, height: 40)
                        .padding(8)
                        .foregroundColor(model.selection != nil ? .accentColor : nil)
                }
                .buttonStyle(.borderless)
                .disabled(model.selection == nil)

                Button {
                    if let id = model.selection {
                        send(.rect(id, .delete))
                    }
                } label: {
                    Image(systemName: "trash")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .shadow(radius: 2)
                        .frame(width: 40, height: 40)
                        .padding(8)
                        .foregroundColor(model.selection != nil ? .accentColor : nil)
                }
                .buttonStyle(.borderless)
                .disabled(model.selection == nil)
            }
            .zIndex(model.zMax + 2)
        }
    }

    private var deselectGesture: some Gesture {
        TapGesture()
            .onEnded { [send] in send(.deselect) }
    }

    private func makeRectGesture(canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(geometry))
            .onChanged { [send] in send(.drag($0.location / canvasSize)) }
            .onEnded { [send] _ in send(.endDrag) }
    }
}

fileprivate func / (lhs: CGSize, rhs: CGSize) -> CGVector {
    return .init(dx: lhs.width / rhs.width, dy: lhs.height / rhs.height)
}

fileprivate func / (lhs: CGPoint, rhs: CGSize) -> CGVector {
    return .init(dx: lhs.x / rhs.width, dy: lhs.y / rhs.height)
}

@available(macOS 11, *)
fileprivate struct RectView: View {
    let rectState: RectState
    let canvasSize: CGSize
    let cornerRadius: CGFloat
    let isSelected: Bool
    let send: (RectState.Message) -> Void

    var body: some View {
        let shape = RectShape(unitRect: rectState.rect.unitRect)
        shape
            .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.2))
            .zIndex(rectState.z)
            .contentShape(RectContentShape(unitRect: rectState.rect.unitRect, cornerRadius: cornerRadius))
            .gesture(selectGesture.exclusively(before: dragGesture))

        if isSelected {
            ForEach(Corner.allCases) { corner in
                HandleView(
                    unitPoint: rectState.rect[corner],
                    canvasSize: canvasSize,
                    z: rectState.z + 1,
                    send: { [send] in send(.corner(corner, $0)) }
                )
            }
        }
    }

    private var selectGesture: some Gesture {
        return TapGesture()
            .onEnded { [send] in send(.select) }
    }

    private var dragGesture: some Gesture {
        return DragGesture(minimumDistance: 0, coordinateSpace: .named(geometry))
            .onChanged { [send, canvasSize] in send(.drag($0.translation / canvasSize)) }
            .onEnded { [send] _ in send(.endDrag) }
    }
}

@available(macOS 11, *)
fileprivate struct HandleView: View {
    let unitPoint: CGPoint
    let canvasSize: CGSize
    let z: CGFloat
    let send: (RectState.CornerMessage) -> Void

    var body: some View {
        let shape = HandleShape(unitPoint: unitPoint)
        ZStack {
            shape
                .fill(Color.white)
            shape
                .stroke(Color.secondary)
        }
        .shadow(radius: 2)
        .zIndex(z)
        .contentShape(shape)
        .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        return DragGesture(minimumDistance: 0, coordinateSpace: .named(geometry))
            .onChanged { send(.drag($0.translation / canvasSize)) }
            .onEnded { _ in send(.endDrag) }
    }
}

@available(macOS 11, *)
extension DragGesture.Value {
    fileprivate func unitTranslation(in size: CGSize) -> CGVector {
        return .init(
            dx: translation.width / size.width,
            dy: translation.height / size.height
        )
    }
}

@available(macOS 11, *)
fileprivate struct RectShape: InsettableShape {
    let unitRect: CGRect
    let inset: CGFloat

    init(unitRect: CGRect, inset: CGFloat = 0) {
        self.unitRect = unitRect
        self.inset = inset
    }

    func path(in rect: CGRect) -> Path {
        let origin = rect.fromUnitPoint(unitRect.origin)
        let scaled = CGRect(
            x: origin.x,
            y: origin.y,
            width: unitRect.size.width * rect.size.width,
            height: unitRect.size.height * rect.size.height
        ).insetBy(dx: inset, dy: inset)
        return Path(scaled)
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        return Self(unitRect: unitRect, inset: amount)
    }
}

@available(macOS 11, *)
fileprivate struct RectContentShape: Shape {
    let unitRect: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let origin = rect.fromUnitPoint(unitRect.origin)
        let scaled = CGRect(
            x: origin.x,
            y: origin.y,
            width: unitRect.size.width * rect.size.width,
            height: unitRect.size.height * rect.size.height
        ).insetBy(dx: -cornerRadius, dy: -cornerRadius)
        return Path(roundedRect: scaled, cornerRadius: cornerRadius)
    }
}

@available(macOS 11, *)
fileprivate struct HandleShape: InsettableShape {
    let unitPoint: CGPoint
    let radius: CGFloat

    init(unitPoint: CGPoint, radius: CGFloat = 8) {
        self.unitPoint = unitPoint
        self.radius = radius
    }

    func path(in rect: CGRect) -> Path {
        let center = rect.fromUnitPoint(unitPoint)
        return Path(ellipseIn: CGRect(origin: center, size: .zero).insetBy(dx: -radius, dy: -radius))
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        return Self(unitPoint: unitPoint, radius: radius - amount)
    }
}

@available(macOS 11, *)
fileprivate struct ContourView: View {
    let rects: [Rect]
    let cornerRadius: CGFloat

    var body: some View {
        let shape = ContourShape(
            rects: rects,
            cornerRadius: cornerRadius
        )
        ZStack {
            shape
                .fill(Color.purple.opacity(0.5))
            shape
                .stroke(
                    Color.purple,
                        style: .init(
                        lineWidth: 5,
                        lineCap: .square,
                        lineJoin: .miter,
                        miterLimit: 20
                    )
                )
        }
        .compositingGroup()
        .opacity(0.5)
    }
}

@available(macOS 11, *)
fileprivate struct ContourShape: Shape {
    let rects: [Rect]
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let transform = CGAffineTransform.identity
            .translatedBy(x: rect.origin.x, y: rect.origin.y)
            .scaledBy(x: rect.size.width, y: rect.size.height)
        let cgRects: [CGRect] = rects
            .lazy
            .map { $0.unitRect.applying(transform).insetBy(dx: -cornerRadius, dy: -cornerRadius) }

        let cgPath = cgRects.contour()
            .cgPath(cornerRadius: cornerRadius)
        return Path(cgPath)
    }
}

extension CGRect {
    fileprivate func fromUnitPoint(_ p: CGPoint) -> CGPoint {
        return .init(
            x: origin.x + size.width * p.x,
            y: origin.y + size.height * p.y
        )
    }
}

@available(macOS 11, *)
struct ContentView_Previews: PreviewProvider, View {
    @State var model: RectDemoModel = .init()

    var body: some View {
        RectDemoView(
            model: model,
            send: { model.apply($0) }
        )
    }

    static var previews: some View {
        Self()
    }
}
