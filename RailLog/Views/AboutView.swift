import SwiftUI

struct AboutView: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section("软件信息") {
                    HStack {
                        Image(systemName: "tram.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                            .frame(width: 60, height: 60)
                            .background(.blue.opacity(0.1), in: .rect(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("RailLog 铁路运转日志")
                                .font(.headline)
                            Text("版本 1.0.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                }

            }
            .navigationTitle("关于")
        }
    }
}

#Preview {
    AboutView()
        .environment(DataStore())
}
