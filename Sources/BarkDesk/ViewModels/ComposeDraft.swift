import BarkCore
import Foundation

enum NotificationKind: String, CaseIterable, Identifiable {
    case text
    case image
    case link
    case critical
    case copy
    case markdown

    var id: String { rawValue }
    var title: String {
        switch self {
        case .text: "普通通知"
        case .image: "图片通知"
        case .link: "链接通知"
        case .critical: "重要警告"
        case .copy: "快捷复制"
        case .markdown: "Markdown"
        }
    }
    var subtitle: String {
        switch self {
        case .text: "标题与正文"
        case .image: "展示在线图片"
        case .link: "点击后打开网页"
        case .critical: "突破静音与专注模式"
        case .copy: "长按即可复制内容"
        case .markdown: "发送排版丰富的正文"
        }
    }
    var icon: String {
        switch self {
        case .text: "text.bubble"
        case .image: "photo"
        case .link: "link"
        case .critical: "exclamationmark.bell"
        case .copy: "doc.on.doc"
        case .markdown: "text.badge.checkmark"
        }
    }
}

struct ComposeDraft {
    var kind = NotificationKind.text
    var title = ""
    var subtitle = ""
    var message = ""
    var group = ""
    var level = BarkLevel.active
    var sound = ""
    var url = ""
    var icon = ""
    var image = ""
    var copy = ""
    var archive = true
    var ttl = ""
    var badge = ""
    var call = false
    var autoCopy = false
    var noAction = false
    var volume = 5.0

    var isValid: Bool {
        switch kind {
        case .text, .critical, .markdown:
            return message.nilIfEmpty != nil
        case .image:
            return image.webURL != nil
        case .link:
            return message.nilIfEmpty != nil && url.webURL != nil
        case .copy:
            return message.nilIfEmpty != nil && copy.nilIfEmpty != nil
        }
    }

    var validationHint: String? {
        switch kind {
        case .text, .critical, .markdown:
            return message.nilIfEmpty == nil ? "请填写通知内容" : nil
        case .image where image.webURL == nil:
            return "请填写可以公开访问的图片链接"
        case .link where message.nilIfEmpty == nil:
            return "请填写通知内容"
        case .link where url.webURL == nil:
            return "请填写有效的跳转链接"
        case .copy where message.nilIfEmpty == nil:
            return "请填写通知内容"
        case .copy where copy.nilIfEmpty == nil:
            return "请填写需要复制的文字"
        default:
            return nil
        }
    }

    mutating func select(_ newKind: NotificationKind) {
        kind = newKind
        if newKind == .critical {
            level = .critical
        } else if level == .critical {
            level = .active
        }
    }

    mutating func applyDefaults(_ settings: AppConfiguration) {
        group = settings.defaultGroup
        level = settings.defaultLevel
        sound = settings.defaultSound
        archive = settings.archiveMessages
    }

    func request(deviceKey: String) -> BarkPushRequest {
        let isMarkdown = kind == .markdown
        return BarkPushRequest(
            deviceKey: deviceKey,
            title: title.nilIfEmpty, subtitle: subtitle.nilIfEmpty,
            body: isMarkdown ? "" : (message.nilIfEmpty ?? "图片通知"),
            markdown: isMarkdown ? message : nil,
            level: kind == .critical ? .critical : level,
            volume: kind == .critical ? Int(volume) : nil,
            badge: Int(badge),
            call: kind == .critical && call ? "1" : nil,
            autoCopy: kind == .copy ? "1" : (autoCopy ? "1" : nil),
            copy: kind == .copy ? copy.nilIfEmpty : nil,
            sound: sound.nilIfEmpty,
            icon: icon.nilIfEmpty,
            image: kind == .image ? image.nilIfEmpty : nil,
            group: group.nilIfEmpty,
            isArchive: archive ? "1" : nil,
            ttl: Int(ttl),
            url: kind == .link ? url.nilIfEmpty : nil,
            action: noAction ? "none" : nil
        )
    }
}

extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }

    var webURL: URL? {
        guard let url = URL(string: self),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else { return nil }
        return url
    }
}
