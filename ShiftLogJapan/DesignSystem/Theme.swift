import SwiftUI

enum AppTheme {
    static let palette = ["5B7DB1", "8A6FB0", "3D8B7D", "C77855", "B05D72", "6B7D52"]
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x5B7DB1
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xff) / 255,
                  green: Double((value >> 8) & 0xff) / 255,
                  blue: Double(value & 0xff) / 255,
                  opacity: 1)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(16).background(.background.secondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension View {
    func appCard() -> some View { modifier(CardModifier()) }

    @ViewBuilder func platformGlass() -> some View {
        if #available(iOS 26.0, *) { self.glassEffect() }
        else { self.background(.ultraThinMaterial, in: Capsule()) }
    }
}
