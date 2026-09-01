import AppKit
import SwiftUI

extension Color {
    // A warm, paper-like palette inspired by Apple Notes and classic writing apps.
    static let barkAccent = adaptive(light: 0xB88A16, dark: 0xE2B94F)
    static let barkAccentInk = adaptive(light: 0x241D0C, dark: 0x201A0A)
    static let barkAccentSoft = adaptive(light: 0xF6EDCF, dark: 0x3A321F)
    static let barkCanvas = adaptive(light: 0xF7F6F1, dark: 0x171715)
    static let barkSurface = adaptive(light: 0xFFFDF8, dark: 0x22221F)
    static let barkField = adaptive(light: 0xF3F1EA, dark: 0x2B2A26)
    static let barkSidebar = adaptive(light: 0xEFEEE8, dark: 0x1D1D1A)
    static let barkMist = adaptive(light: 0xE7E3D8, dark: 0x2C2B26)
    static let barkInk = adaptive(light: 0x20211E, dark: 0xF2F0E8)
    static let barkBorder = adaptive(light: 0xDCD8CE, dark: 0x3D3B35)

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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.barkAccent)
            Text(title)
                .font(.system(size: 34, weight: .semibold))
                .tracking(-1.1)
                .foregroundStyle(Color.barkInk)
            Text(detail)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
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
            .padding(24)
            .background(Color.barkSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.barkBorder.opacity(0.65), lineWidth: 1)
            }
            .shadow(color: Color.barkInk.opacity(0.035), radius: 20, y: 8)
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
            .foregroundStyle(Color.barkAccentInk)
            .padding(.horizontal, 19)
            .frame(minHeight: 46)
            .background(Color.barkAccent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BarkPrimaryButtonStyle {
    static var barkPrimary: BarkPrimaryButtonStyle { BarkPrimaryButtonStyle() }
}

private struct BarkControlSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .medium))
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.barkField, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.barkBorder.opacity(0.85), lineWidth: 1)
            }
    }
}

extension View {
    func barkControlSurface() -> some View { modifier(BarkControlSurface()) }
}

struct FieldCaption: View {
    let title: String
    var optional = false

    var body: some View {
        HStack(spacing: 5) {
            Text(title).font(.system(size: 15, weight: .semibold))
            if optional { Text("选填").font(.system(size: 12)).foregroundStyle(.tertiary) }
        }
    }
}
