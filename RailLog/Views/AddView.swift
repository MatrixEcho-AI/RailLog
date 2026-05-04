import SwiftUI

struct AddView: View {
    @Environment(DataStore.self) private var store
    @State private var showScanner = false
    @State private var showDraftPicker = false
    @State private var navigateToEdit: TripLog? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // 大按钮：扫描铁路畅行码
                Button {
                    showScanner = true
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 60))
                        Text("扫描铁路畅行码")
                            .font(.title2.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(.blue, in: .rect(cornerRadius: 20))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)

                // 小按钮：继续填写
                if !store.drafts.isEmpty {
                    Button {
                        showDraftPicker = true
                    } label: {
                        Label("继续填写 (\(store.drafts.count) 个草稿)", systemImage: "doc.text")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Text("扫描车厢内的铁路畅行码，自动获取车次和座位信息")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .navigationTitle("新运转")
            .sheet(isPresented: $showScanner) {
                ScannerView { scanned in
                    showScanner = false
                    let draft = store.createDraft(from: scanned)
                    navigateToEdit = draft
                }
            }
            .sheet(isPresented: $showDraftPicker) {
                DraftPickerView(onSelect: { draft in
                    showDraftPicker = false
                    navigateToEdit = draft
                })
            }
            .navigationDestination(item: $navigateToEdit) { draft in
                TripEditView(draft: draft)
            }
        }
    }
}

struct DraftPickerView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onSelect: (TripLog) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.drafts) { draft in
                    Button {
                        onSelect(draft)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if !draft.trainNumber.isEmpty {
                                    Text(draft.trainNumber)
                                        .font(.headline)
                                } else {
                                    Text("空草稿")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(draft.createdAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !draft.departureStation.isEmpty {
                                Text("\(draft.departureStation) → \(draft.arrivalStation)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { offsets in
                    for idx in offsets {
                        store.deleteDraft(store.drafts[idx])
                    }
                }
            }
            .navigationTitle("选择草稿")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .overlay {
                if store.drafts.isEmpty {
                    ContentUnavailableView("暂无草稿", systemImage: "doc.text")
                }
            }
        }
    }
}

#Preview {
    AddView()
        .environment(DataStore())
}
