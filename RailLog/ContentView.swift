import SwiftUI

struct ContentView: View {
    @State private var store = DataStore()
    @State private var selectedTab = 0

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
                    Image(systemName: "plus.circle")
                }
                .tag(1)

            AboutView()
                .tabItem {
                    Image(systemName: "info.circle")
                    Text("关于")
                }
                .tag(2)
        }
        .environment(store)
    }
}

#Preview {
    ContentView()
}
