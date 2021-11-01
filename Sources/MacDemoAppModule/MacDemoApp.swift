import SwiftUI

@available(macOS 11, *)
public struct MacDemoApp: App {
    @State var model: DemoModel = .init()

    public init() { }

    public var body: some Scene {
        WindowGroup {
            TabView {
                TextDemoView(
                    model: model.textModel,
                    send: { model.apply(.text($0)) }
                ).tabItem { Label("Text", systemImage: "text.aligncenter") }

                RectDemoView(
                    model: model.rectModel,
                    send: { model.apply(.rect($0)) }
                ).tabItem { Label("Rects", systemImage: "rectangle.on.rectangle") }
            }
            .padding()
            .preferredColorScheme(.light)
        }
    }
}
