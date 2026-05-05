import SwiftUI

enum AppTheme {
    static var accent: Color { Color(red: 0.24, green: 0.49, blue: 0.96) }
    static var accentSoft: Color { Color(uiColor: .secondarySystemBackground) }
    static var ink: Color { Color(uiColor: .label) }
    static var subInk: Color { Color(uiColor: .secondaryLabel) }

    static var pageBackground: Color { Color(uiColor: .systemGroupedBackground) }
    static var cardBackground: Color { Color(uiColor: .secondarySystemGroupedBackground) }
    static var cardBorder: Color { Color(uiColor: .separator).opacity(0.35) }
}

struct PremiumBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.pageBackground.ignoresSafeArea())
    }
}

struct PremiumCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

struct PremiumPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension View {
    func premiumBackground() -> some View {
        modifier(PremiumBackground())
    }

    func premiumCard() -> some View {
        modifier(PremiumCard())
    }

    func premiumPanel() -> some View {
        modifier(PremiumPanel())
    }
}
