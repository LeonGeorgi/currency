import SwiftUI

@main
struct CurrencyApp: App {
    init() { ScreenshotSupport.prepare() }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .defaultAppStorage(ScreenshotSupport.defaults)
                .preferredColorScheme(ScreenshotSupport.colorScheme)
                .tint(.teal)
        }
    }
}
