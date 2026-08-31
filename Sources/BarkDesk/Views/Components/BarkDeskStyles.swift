import AppKit
import SwiftUI

extension Color {
    static let barkRed = Color(red: 0.78, green: 0.17, blue: 0.23)
    static let barkRedSoft = Color(red: 0.78, green: 0.17, blue: 0.23).opacity(0.11)
}

struct PageHeader: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.barkRed)
            Text(title)
                .font(.system(size: 29, weight: .semibold, design: .rounded))
                .tracking(-0.5)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
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
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.72))
            }
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
            .background(color.opacity(0.1), in: Capsule())
    }
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
