import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: HexRealmStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showOnboarding = false

    var body: some View {
        ZStack {
            RootTabView()

            if showOnboarding {
                OnboardingView {
                    store.progress.onboardingDone = true
                    store.saveProgress()
                    withAnimation(.easeInOut(duration: 0.3)) { showOnboarding = false }
                }
                .transition(.opacity)
                .zIndex(40)
            }
        }
        .onAppear {
            if !store.progress.onboardingDone {
                showOnboarding = true
            }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                store.handleBackground()
            case .inactive:
                // transitional; persist nothing time-sensitive here
                break
            case .active:
                break
            @unknown default:
                break
            }
        }
    }
}
