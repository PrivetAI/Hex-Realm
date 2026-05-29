import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: HexRealmStore
    @State private var showPrivacy = false
    @State private var showResetAlert = false

    var body: some View {
        ZStack {
            HexBackground()
            ScrollView {
                VStack(spacing: 14) {
                    toggleCard(title: "Sound Effects",
                               subtitle: "In-game audio cues",
                               isOn: Binding(get: { store.progress.soundOn },
                                             set: { store.progress.soundOn = $0; store.saveProgress() }))
                    toggleCard(title: "Haptics",
                               subtitle: "Vibration feedback on actions",
                               isOn: Binding(get: { store.progress.hapticsOn },
                                             set: { store.progress.hapticsOn = $0; store.saveProgress() }))

                    Button(action: { showPrivacy = true }) {
                        rowCard(title: "Privacy Policy",
                                subtitle: "View our privacy policy",
                                tint: HexPalette.research)
                    }.buttonStyle(.plain)

                    Button(action: { showResetAlert = true }) {
                        rowCard(title: "Reset Progress",
                                subtitle: "Erase all campaigns, awards, and saves",
                                tint: HexPalette.danger)
                    }.buttonStyle(.plain)

                    Spacer(minLength: 12)
                }
                .padding(16)
            }
        }
        .navigationBarTitle("Settings", displayMode: .inline)
        .sheet(isPresented: $showPrivacy) {
            HexRealmWebPanel(hexRealmURLString: "https://example.com")
        }
        .alert(isPresented: $showResetAlert) {
            Alert(title: Text("Reset Progress?"),
                  message: Text("This permanently erases all campaign progress, achievements, statistics, and any saved match. This cannot be undone."),
                  primaryButton: .destructive(Text("Reset Everything")) {
                      store.resetAll()
                  },
                  secondaryButton: .cancel())
        }
    }

    private func toggleCard(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(HexPalette.textPrimary)
                Text(subtitle).font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(HexPalette.textSecondary)
            }
            Spacer()
            // custom toggle
            Button(action: { isOn.wrappedValue.toggle() }) {
                ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn.wrappedValue ? HexPalette.success : HexPalette.track)
                        .frame(width: 50, height: 30)
                    Circle().fill(.white).frame(width: 24, height: 24).padding(3)
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .hexCard()
    }

    private func rowCard(title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(tint)
                Text(subtitle).font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(HexPalette.textSecondary)
            }
            Spacer()
            ChevronGlyph(color: HexPalette.textMuted, size: 16)
        }
        .padding(14)
        .hexCard()
    }
}
