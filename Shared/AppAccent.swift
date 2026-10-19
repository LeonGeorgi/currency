import SwiftUI

enum AppAccent: String, CaseIterable, Codable, Identifiable, Sendable {
    case original, red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown, gray

    var id: Self { self }
    var iconName: String? { self == .original ? nil : "AppIcon-\(rawValue.capitalized)" }
    var previewName: String { "AppIconPreview-\(rawValue.capitalized)" }
    var swatchForeground: Color {
        switch self {
        case .orange, .yellow, .green, .mint, .teal, .cyan: .black
        default: .white
        }
    }

    var color: Color {
        switch self {
        case .original: Color("AccentColor")
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        case .gray: .gray
        }
    }

    var title: String {
        switch self {
        case .original: String(localized: "Standard")
        case .red: String(localized: "Rot")
        case .orange: String(localized: "Orange")
        case .yellow: String(localized: "Gelb")
        case .green: String(localized: "Grün")
        case .mint: String(localized: "Mint")
        case .teal: String(localized: "Türkis")
        case .cyan: String(localized: "Cyan")
        case .blue: String(localized: "Blau")
        case .indigo: String(localized: "Indigo")
        case .purple: String(localized: "Lila")
        case .pink: String(localized: "Pink")
        case .brown: String(localized: "Braun")
        case .gray: String(localized: "Grau")
        }
    }
}

private struct AppAccentKey: EnvironmentKey {
    static let defaultValue = AppAccent.original
}

extension EnvironmentValues {
    var appAccent: AppAccent {
        get { self[AppAccentKey.self] }
        set { self[AppAccentKey.self] = newValue }
    }
}
