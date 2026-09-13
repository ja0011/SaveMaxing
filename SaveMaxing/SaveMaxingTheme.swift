import SwiftUI

enum SaveMaxingTheme {
    static let brand = Color(red: 0.04, green: 0.28, blue: 0.30)
    static let brandLight = Color(red: 0.86, green: 0.95, blue: 0.94)
    static let accent = Color(red: 0.00, green: 0.49, blue: 0.43)
    static let accentSoft = Color(red: 0.88, green: 0.96, blue: 0.94)
    static let surface = Color(.secondarySystemBackground)
    static let insetSurface = Color(.systemBackground)
    static let success = Color(red: 0.04, green: 0.45, blue: 0.30)
    static let warning = Color(red: 0.72, green: 0.38, blue: 0.04)
    static let danger = Color(red: 0.74, green: 0.15, blue: 0.16)
    static let info = Color(red: 0.10, green: 0.32, blue: 0.58)
    static let insight = Color(red: 0.62, green: 0.43, blue: 0.08)
    static let mutedIcon = Color(red: 0.28, green: 0.38, blue: 0.46)

    static var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                brandLight.opacity(0.72),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func cardGradient(tint: Color = brand) -> LinearGradient {
        LinearGradient(
            colors: [
                surface,
                tint.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
