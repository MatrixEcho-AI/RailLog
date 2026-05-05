import SwiftUI

struct AddView: View {
    @Environment(DataStore.self) private var store
    @State private var showScanner = false
    @State private var showDraftPicker = false
    @State private var navigateToEdit: TripLog? = nil
    @State private var verifying = false

    var body: some View {
        NavigationStack {
            ZStack {
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
                        store.cleanExpiredDrafts()
                        showDraftPicker = true
                    } label: {
                        Label("继续填写 (\(store.drafts.count) 个草稿)", systemImage: "doc.text")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }

            if verifying {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView("正在验证位置...")
                    .padding(24)
                    .background(.regularMaterial, in: .rect(cornerRadius: 12))
            }
            }
            .navigationTitle("新运转")
            .sheet(isPresented: $showScanner) {
                ScannerView { scanned in
                    showScanner = false
                    verifying = true
                    var draft = store.createDraft(from: scanned)
                    Task {
                        let result = await LocationVerifier.verify()
                        draft.verifiedOnRailway = result.onRailway
                        store.updateDraft(draft)
                        verifying = false
                        navigateToEdit = draft
                    }
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
                                if !draft.trainNumber.isEmpty || !draft.emuNumber.isEmpty {
                                    Text(draft.trainNumber.isEmpty ? draft.emuNumber : draft.trainNumber)
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
