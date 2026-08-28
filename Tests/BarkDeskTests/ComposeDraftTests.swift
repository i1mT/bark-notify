import Testing
@testable import BarkDesk

@Test("每种通知类型只校验必要字段")
func notificationKindValidation() {
    var draft = ComposeDraft()
    #expect(!draft.isValid)
    draft.message = "构建完成"
    #expect(draft.isValid)

    draft.select(.image)
    draft.message = ""
    draft.image = "not-a-url"
    #expect(!draft.isValid)
    draft.image = "https://example.com/preview.png"
    #expect(draft.isValid)

    draft.select(.link)
    draft.message = "查看报告"
    #expect(!draft.isValid)
    draft.url = "https://example.com/report"
    #expect(draft.isValid)

    draft.select(.copy)
    draft.copy = ""
    #expect(!draft.isValid)
    draft.copy = "123456"
    #expect(draft.isValid)
}

@Test("通知类型会生成对应的 Bark 参数")
func notificationKindRequestMapping() {
    var draft = ComposeDraft()
    draft.message = "服务异常"
    draft.select(.critical)
    draft.volume = 8
    draft.call = true
    let critical = draft.request(deviceKey: "device")
    #expect(critical.level == .critical)
    #expect(critical.volume == 8)
    #expect(critical.call == "1")

    draft.select(.image)
    draft.message = ""
    draft.image = "https://example.com/image.png"
    let image = draft.request(deviceKey: "device")
    #expect(image.body == "图片通知")
    #expect(image.image == draft.image)
    #expect(image.level != .critical)

    draft.select(.copy)
    draft.message = "验证码"
    draft.copy = "654321"
    let copy = draft.request(deviceKey: "device")
    #expect(copy.copy == "654321")
    #expect(copy.autoCopy == "1")
}
