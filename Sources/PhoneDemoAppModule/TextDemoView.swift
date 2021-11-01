import RectangleContour
import SwiftUI

struct TextDemoModel {
    var rects: [CGRect] = []

    enum Message {
        case setRects([CGRect])
    }

    mutating func apply(_ message: Message) {
        switch message {
        case .setRects(let rects):
            self.rects = rects
        }
    }
}

@available(iOS 13, *)
struct TextDemoView: View {
    let model: TextDemoModel
    let send: (TextDemoModel.Message) -> Void

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
            RectsShape(rects: model.rects)
                .fill(Color.purple.opacity(0.2))
                .allowsHitTesting(false)
            TextViewWrapper(rects: model.rects, send: send)
        }
    }
}

@available(iOS 13, *)
fileprivate struct RectsShape: Shape {
    var rects: [CGRect]

    func path(in _: CGRect) -> Path {
        let cgPath = rects
            .map { $0.insetBy(dx: -2, dy: -2) }
            .contour()
            .cgPath(cornerRadius: 6)
        return Path(cgPath)
    }
}

@available(iOS 13, *)
struct TextViewWrapper {
    let rects: [CGRect]
    let send: (TextDemoModel.Message) -> Void

    class Coordinator: NSObject {
        let textView: UITextView = .init()
        var rects: [CGRect]
        var send: (TextDemoModel.Message) -> Void

        init(
            rects: [CGRect],
            send: @escaping (TextDemoModel.Message) -> Void
        ) {
            self.rects = rects
            self.send = send

            textView.isEditable = true
            textView.backgroundColor = nil

            super.init()

            textView.layoutManager.delegate = self

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            textView.typingAttributes = [
                .font: UIFont.systemFont(ofSize: 30),
                .paragraphStyle: paragraphStyle
            ]
            textView.textStorage.append(.init(string: "\nRounded\ntext\ncontours\n", attributes: textView.typingAttributes))
        }
    }
}

@available(iOS 13, *)
extension TextViewWrapper: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        return .init(rects: rects, send: send)
    }

    func makeUIView(context: Context) -> UITextView {
        return context.coordinator.textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.rects = rects
        context.coordinator.send = send
    }
}

@available(iOS 13, *)
extension TextViewWrapper.Coordinator: NSLayoutManagerDelegate {
    func layoutManager(_ layoutManager: NSLayoutManager, didCompleteLayoutFor textContainer: NSTextContainer?, atEnd layoutFinishedFlag: Bool) {
        let range = NSRange(0 ..< layoutManager.numberOfGlyphs)
        let insets = textView.textContainerInset
        var usedRects: [CGRect] = []
        layoutManager.enumerateLineFragments(forGlyphRange: range) { _, usedRect, _, _, _ in
            var usedRect = usedRect
            usedRect.origin.x += insets.left
            usedRect.origin.y += insets.top
            usedRects.append(usedRect)
        }
        send(.setRects(usedRects))
    }
}

