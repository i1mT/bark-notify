import AppKit
import SwiftUI

struct LargeTextFieldStyle: TextFieldStyle {
    @Environment(\.isFocused) private var isFocused

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(.body)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.barkSurface, in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isFocused ? Color.barkBlue : Color.barkBorder,
                            lineWidth: isFocused ? 2 : 1)
            }
            .shadow(color: isFocused ? Color.barkBlue.opacity(0.12) : .clear, radius: 5)
            .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}

extension TextFieldStyle where Self == LargeTextFieldStyle {
    static var barkDeskLarge: LargeTextFieldStyle { LargeTextFieldStyle() }
}
