import SwiftUI
import OSLog

struct AppearanceSettingsView: View {
    @AppStorage("accentColor") private var storedAccent = AppAccent.original.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var isApplying = false
    @State private var showingError = false

    private var selectedAccent: AppAccent { AppAccent(rawValue: storedAccent) ?? .original }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        Image(selectedAccent.previewName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .accessibilityLabel("App-Icon")
                            .accessibilityValue(selectedAccent.title)
                            .accessibilityIdentifier("current-icon-preview")
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Devisen")
                            .font(.title3.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .listRowBackground(Color.clear)

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 12)], spacing: 14) {
                        ForEach(AppAccent.allCases) { accent in
                            Button {
                                Task { await select(accent) }
                            } label: {
                                Group {
                                    if selectedAccent == accent {
                                        Image(systemName: "checkmark.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(accent.swatchForeground, accent.color)
                                    } else {
                                        Image(systemName: "circle.fill")
                                            .foregroundStyle(accent.color)
                                    }
                                }
                                .font(.system(size: 38))
                                .frame(minWidth: 48, minHeight: 48)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isApplying)
                            .accessibilityLabel(accent.title)
                            .accessibilityAddTraits(selectedAccent == accent ? [.isSelected] : [])
                            .accessibilityIdentifier("accent-\(accent.rawValue)")
                        }
                    }
                    .padding(.vertical, 12)
                } header: {
                    Text("Akzentfarbe")
                } footer: {
                    Text("Die Farbe gilt für App, Widget und App-Icon.")
                }
                Section {
                    NavigationLink("Über Devisen") { InfoView() }
                        .accessibilityIdentifier("appearance-about")
                }
            }
            .navigationTitle("Erscheinungsbild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.disabled(isApplying)
                }
            }
            .alert("Die Farbe konnte nicht geändert werden.", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Das App-Icon konnte nicht geändert werden. Bitte versuche es erneut.")
            }
        }
    }

    @MainActor
    private func select(_ accent: AppAccent) async {
        guard !isApplying, storedAccent != accent.rawValue else { return }
        isApplying = true
        defer { isApplying = false }
        let previous = storedAccent
        let changeIcon = !ScreenshotSupport.isEnabled || ProcessInfo.processInfo.arguments.contains("--test-app-icons")
        guard !changeIcon || UIApplication.shared.supportsAlternateIcons else {
            showingError = true
            return
        }
        storedAccent = accent.rawValue
        do {
            // Gallery captures leave the simulator's Home Screen icon untouched.
            if changeIcon {
                if UIApplication.shared.alternateIconName != accent.iconName {
                    try await UIApplication.shared.setAlternateIconName(accent.iconName)
                }
            }
        } catch {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "Currency", category: "Appearance")
                .error("Changing the app icon failed: \(String(describing: error), privacy: .public)")
            storedAccent = previous
            showingError = true
        }
    }
}
