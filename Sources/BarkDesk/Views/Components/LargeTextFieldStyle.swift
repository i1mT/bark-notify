import AppKit
import SwiftUI

struct LargeTextFieldStyle: TextFieldStyle {
    @Environment(\.isFocused) private var isFocused

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(.system(size: 15, weight: .regular))
            .padding(.horizontal, 15)
            .frame(minHeight: 50)
            .background(Color.barkField, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFocused ? Color.barkAccent : Color.barkBorder.opacity(0.85),
                            lineWidth: isFocused ? 2 : 1)
            }
            .shadow(color: isFocused ? Color.barkAccent.opacity(0.14) : .clear, radius: 7)
            .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}

extension TextFieldStyle where Self == LargeTextFieldStyle {
    static var barkDeskLarge: LargeTextFieldStyle { LargeTextFieldStyle() }
}
