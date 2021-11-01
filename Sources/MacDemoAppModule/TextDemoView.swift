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

@available(macOS 11, *)
struct TextDemoView: View {
    let model: TextDemoModel
    let send: (TextDemoModel.Message) -> Void

    var body: some View {
        ZStack {
            Color(NSColor.textBackgroundColor)
            RectsShape(rects: model.rects)
                .fill(Color.purple.opacity(0.2))
                .allowsHitTesting(false)
            TextViewWrapper(rects: model.rects, send: send)
        }
    }
}

@available(macOS 11, *)
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

@available(macOS 11, *)
struct TextViewWrapper {
    let rects: [CGRect]
    let send: (TextDemoModel.Message) -> Void

    class Coordinator: NSObject {
        let textView: NSTextView
        let scrollView = NSScrollView()
        var rects: [CGRect]
        var send: (TextDemoModel.Message) -> Void

        init(
            rects: [CGRect],
            send: @escaping (TextDemoModel.Message) -> Void
        ) {
            self.rects = rects
            self.send = send

            let storage = NSTextStorage()
            let layoutManager = NSLayoutManager()
            storage.addLayoutManager(layoutManager)
            let container = NSTextContainer()
            layoutManager.addTextContainer(container)
            textView = NSTextView(frame: .zero, textContainer: container)
            container.containerSize = .init(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
            container.widthTracksTextView = true
            textView.minSize = .zero
            textView.maxSize = .init(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
            textView.isVerticallyResizable = true
            textView.isHorizontallyResizable = false
            textView.frame = .init(origin: .zero, size: scrollView.contentSize)
            textView.autoresizingMask = .width
            textView.drawsBackground = false
            scrollView.borderType = .noBorder
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            scrollView.documentView = textView
            scrollView.drawsBackground = false

            super.init()

            layoutManager.delegate = self

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            textView.typingAttributes = [
                .font: NSFont.systemFont(ofSize: 30),
                .paragraphStyle: paragraphStyle
            ]
            storage.append(.init(string: "\nRounded\ntext\ncontours\n", attributes: textView.typingAttributes))
        }
    }
}

@available(macOS 11, *)
extension TextViewWrapper: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        return .init(rects: rects, send: send)
    }

    func makeNSView(context: Context) -> NSScrollView {
        return context.coordinator.scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.rects = rects
        context.coordinator.send = send
    }
}

@available(macOS 11, *)
extension TextViewWrapper.Coordinator: NSLayoutManagerDelegate {
    func layoutManager(_ layoutManager: NSLayoutManager, didCompleteLayoutFor textContainer: NSTextContainer?, atEnd layoutFinishedFlag: Bool) {
        let range = NSRange(0 ..< layoutManager.numberOfGlyphs)
        var usedRects: [CGRect] = []
        layoutManager.enumerateLineFragments(forGlyphRange: range) { _, usedRect, _, _, _ in
            usedRects.append(usedRect)
        }
        send(.setRects(usedRects))
    }
}
