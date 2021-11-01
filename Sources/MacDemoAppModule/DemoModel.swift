
struct DemoModel {
    var rectModel: RectDemoModel = .init()
    var textModel: TextDemoModel = .init()

    enum Message {
        case rect(RectDemoModel.Message)
        case text(TextDemoModel.Message)
    }

    mutating func apply(_ message: Message) {
        switch message {
        case .rect(let sub):
            rectModel.apply(sub)
        case .text(let sub):
            textModel.apply(sub)
        }
    }
}
