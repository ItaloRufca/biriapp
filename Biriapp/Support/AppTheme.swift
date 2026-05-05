import SwiftUI

enum AppTheme {
    static var accent: Color { Color(red: 0.1, green: 0.42, blue: 0.87) }
    static var accentSoft: Color { Color(red: 0.9, green: 0.94, blue: 1.0) }
    static var ink: Color { Color(red: 0.12, green: 0.15, blue: 0.22) }
    static var subInk: Color { Color(red: 0.4, green: 0.45, blue: 0.56) }

    static var pageBackground: Color { Color(red: 0.97, green: 0.98, blue: 1.0) }
    static var cardBackground: Color { .white }
    static var cardBorder: Color { Color.black.opacity(0.05) }
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
            .background(Color.white.opacity(0.9))
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
