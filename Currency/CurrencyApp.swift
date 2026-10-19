import SwiftUI

@main
struct CurrencyApp: App {
    init() { ScreenshotSupport.prepare() }

    var body: some Scene {
        WindowGroup {
            ThemedContentView()
                .defaultAppStorage(ScreenshotSupport.defaults)
                .preferredColorScheme(ScreenshotSupport.colorScheme)
        }
    }
}

private struct ThemedContentView: View {
    @AppStorage("accentColor") private var storedAccent = AppAccent.original.rawValue

    var body: some View {
        let accent = AppAccent(rawValue: storedAccent) ?? .original
        ContentView()
            .environment(\.appAccent, accent)
            .tint(accent.color)
    }
}
