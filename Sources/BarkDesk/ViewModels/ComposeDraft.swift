import BarkCore
import Foundation

struct ComposeDraft {
    var title = ""
    var subtitle = ""
    var message = ""
    var markdown = false
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

    mutating func applyDefaults(_ settings: AppConfiguration) {
        group = settings.defaultGroup
        level = settings.defaultLevel
        sound = settings.defaultSound
        archive = settings.archiveMessages
    }

    func request(deviceKey: String) -> BarkPushRequest {
        BarkPushRequest(
            deviceKey: deviceKey,
            title: title.nilIfEmpty, subtitle: subtitle.nilIfEmpty,
            body: markdown ? "" : message,
            markdown: markdown ? message : nil,
            level: level,
            volume: level == .critical ? Int(volume) : nil,
            badge: Int(badge),
            call: call ? "1" : nil,
            autoCopy: autoCopy ? "1" : nil,
            copy: copy.nilIfEmpty,
            sound: sound.nilIfEmpty,
            icon: icon.nilIfEmpty,
            image: image.nilIfEmpty,
            group: group.nilIfEmpty,
            isArchive: archive ? "1" : nil,
            ttl: Int(ttl),
            url: url.nilIfEmpty,
            action: noAction ? "none" : nil
        )
    }
}

extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
