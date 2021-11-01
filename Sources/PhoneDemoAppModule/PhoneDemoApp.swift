import SwiftUI

@available(iOS 14, *)
public struct PhoneDemoApp: App {
    @State var model: TextDemoModel = .init()

    public init() { }

    public var body: some Scene {
        WindowGroup {
            TextDemoView(
                model: model,
                send: { model.apply($0) }
            )
        }
    }
}
