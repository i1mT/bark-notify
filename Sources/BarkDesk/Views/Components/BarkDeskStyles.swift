import AppKit
import SwiftUI

extension Color {
    static let barkBlue = Color(red: 0.00, green: 0.38, blue: 1.00)
    static let barkBlueSoft = adaptive(light: 0xE8F1FF, dark: 0x173052)
    static let barkCanvas = adaptive(light: 0xF7F5F2, dark: 0x171719)
    static let barkSurface = adaptive(light: 0xFFFFFF, dark: 0x242427)
    static let barkSidebar = adaptive(light: 0xEAF2FD, dark: 0x1B2635)
    static let barkMist = adaptive(light: 0xB4D0E7, dark: 0x243E57)
    static let barkInk = adaptive(light: 0x1E1919, dark: 0xF5F2EE)
    static let barkBorder = adaptive(light: 0xDEDAD4, dark: 0x3B3B40)

    private static func adaptive(light: Int, dark: Int) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(hex: Int) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct PageHeader: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.barkBlue)
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(Color.barkInk)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SurfaceCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(22)
            .background(Color.barkSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.barkBlue.opacity(0.055), radius: 16, y: 6)
    }
}

struct StatusPill: View {
    let label: String
    let systemImage: String
    var color: Color = .secondary

    var body: some View {
        Label(label, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct BarkPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 17)
            .frame(minHeight: 42)
            .background(Color.barkBlue, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BarkPrimaryButtonStyle {
    static var barkPrimary: BarkPrimaryButtonStyle { BarkPrimaryButtonStyle() }
}

struct FieldCaption: View {
    let title: String
    var optional = false

    var body: some View {
        HStack(spacing: 5) {
            Text(title).font(.subheadline.weight(.medium))
            if optional {
                Text("选填").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}
