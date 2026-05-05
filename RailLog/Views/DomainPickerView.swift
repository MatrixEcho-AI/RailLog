import SwiftUI

struct DomainPickerView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Domain.all) { domain in
                    Button {
                        store.currentDomainID = domain.id
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: domain.icon)
                                .font(.title3)
                                .frame(width: 32)
                            Text(domain.name)
                                .font(.body)
                            Spacer()
                            if domain.id == store.currentDomainID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("选择域")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DomainPickerView()
        .environment(DataStore())
}
