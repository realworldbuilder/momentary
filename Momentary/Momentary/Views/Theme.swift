import SwiftUI

enum Theme {
    // MARK: - Backgrounds
    static let background = Color.black
    static let cardBackground = Color(white: 0.11)

    // MARK: - Accent
    static let accent = Color.green
    static let accentSubtle = Color.green.opacity(0.15)

    // MARK: - Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.35)

    // MARK: - Divider
    static let divider = Color.white.opacity(0.06)

    // MARK: - Corner Radii
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16
}

// MARK: - Theme Card Modifier

struct ThemeCardModifier: ViewModifier {
    var cornerRadius: CGFloat = Theme.radiusMedium

    func body(content: Content) -> some View {
        content
            .padding()
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func themeCard(cornerRadius: CGFloat = Theme.radiusMedium) -> some View {
        modifier(ThemeCardModifier(cornerRadius: cornerRadius))
    }
}
