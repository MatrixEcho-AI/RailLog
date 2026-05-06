import SwiftUI

struct ContentView: View {
    @State private var store = DataStore()
    @State private var selectedTab = 0
    @State private var showSafetyEducation = false
    @Environment(\.scenePhase) private var scenePhase

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
        .fullScreenCover(isPresented: $showSafetyEducation) {
            SafetyEducationView(domain: store.currentDomain) {
                store.markSafetyEducationCompleted(for: store.currentDomainID)
                showSafetyEducation = false
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            showSafetyEducation = store.needsSafetyEducation(for: store.currentDomainID)
        }
        .onChange(of: store.currentDomainID) { _, newID in
            showSafetyEducation = store.needsSafetyEducation(for: newID)
        }
        .onChange(of: store.safetyRelearnToken) {
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
