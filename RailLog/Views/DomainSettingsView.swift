import SwiftUI

struct DomainSettingsView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("主项", selection: Binding(
                        get: { store.preferTrainNumber },
                        set: { store.preferTrainNumber = $0 }
                    )) {
                        Text("车次").tag(true)
                        Text("动车组编号").tag(false)
                    }
                } header: {
                    Text(store.currentDomain.name)
                }

                Section {
                    Button {
                        store.triggerSafetyRelearn(for: store.currentDomainID)
                        dismiss()
                    } label: {
                        Label("重新学习安全教育", systemImage: "hand.raised.fill")
                    }
                }
            }
            .navigationTitle("域设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DomainSettingsView()
        .environment(DataStore())
}
