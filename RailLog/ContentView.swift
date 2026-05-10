import SwiftUI

struct ContentView: View {
    @State private var store = DataStore()
    @State private var selectedTab = 0
    @State private var showPrivacyPolicy = false
    @State private var showSafetyEducation = false
    @Environment(\.scenePhase) private var scenePhase

    private func checkPrivacyThenSafety() {
        guard store.privacyPolicyAccepted else {
            showPrivacyPolicy = true
            return
        }
        showSafetyEducation = store.needsSafetyEducation(for: store.currentDomainID)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            LogListView()
                .tabItem {
                    Image(systemName: "book.pages")
                    Text("日志")
                }
                .tag(0)

            AddView()
                .tabItem {
                    Image(uiImage: UIImage(systemName: "plus.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 36, weight: .regular))!)
                }
                .tag(1)

            AboutView()
                .tabItem {
                    Image(systemName: "info.circle")
                    Text("统计")
                }
                .tag(2)
        }
        .environment(store)
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .fullScreenCover(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView(isMandatory: true) {
                store.privacyPolicyAccepted = true
                showPrivacyPolicy = false
                showSafetyEducation = store.needsSafetyEducation(for: store.currentDomainID)
            }
            .interactiveDismissDisabled()
        }
        .fullScreenCover(isPresented: $showSafetyEducation) {
            SafetyEducationView(domain: store.currentDomain) {
                store.markSafetyEducationCompleted(for: store.currentDomainID)
                showSafetyEducation = false
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            checkPrivacyThenSafety()
        }
        .onChange(of: store.currentDomainID) { _, newID in
            guard store.privacyPolicyAccepted else { return }
            showSafetyEducation = store.needsSafetyEducation(for: newID)
        }
        .onChange(of: store.safetyRelearnToken) {
            guard store.privacyPolicyAccepted else { return }
            showSafetyEducation = store.needsSafetyEducation(for: store.currentDomainID)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await store.performSync() }
            }
        }
        .task {
            await store.performSync()
        }
    }
}

#Preview {
    ContentView()
}
