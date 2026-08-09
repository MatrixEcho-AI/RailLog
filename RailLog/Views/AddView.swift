import SwiftUI

struct AddView: View {
    @Environment(DataStore.self) private var store
    @State private var showScanner = false
    @State private var showEMUScanner = false
    @State private var showManualEntry = false
    @State private var showDraftPicker = false
    @State private var navigateToEdit: TripLog? = nil
    @State private var verifying = false
    @State private var showDomainPicker = false
    @State private var showDomainSettings = false
    @State private var openManualAfterScanner = false

    var body: some View {
        NavigationStack {
            ZStack {
            VStack(spacing: 16) {
                Spacer()

                // 域切换 + 设置
                HStack(spacing: 12) {
                    Button {
                        showDomainPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: store.currentDomain.icon)
                            Text(store.currentDomain.name)
                                .font(.subheadline.weight(.medium))
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(.regularMaterial, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showDomainSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)

                // 大按钮：扫描车身编号
                Button {
                    showEMUScanner = true
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                        Text("扫描车身编号")
                            .font(.title2.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(.blue, in: .rect(cornerRadius: 20))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)

                // 大按钮：手动输入
                Button {
                    showManualEntry = true
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 60))
                        Text("手动输入")
                            .font(.title2.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(.blue, in: .rect(cornerRadius: 20))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)

                // 扫描铁路畅行码 + 草稿
                HStack(spacing: 12) {
                    Button {
                        showScanner = true
                    } label: {
                        Label("扫描铁路畅行码", systemImage: "qrcode.viewfinder")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    if !store.drafts.isEmpty {
                        Button {
                            store.cleanExpiredDrafts()
                            showDraftPicker = true
                        } label: {
                            Label("\(store.drafts.count) 个草稿", systemImage: "doc.text")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 32)

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
            .sheet(isPresented: $showScanner, onDismiss: {
                if openManualAfterScanner {
                    openManualAfterScanner = false
                    showManualEntry = true
                }
            }) {
                ScannerView(onScan: { scanned in
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
                }, onEncrypted: {
                    openManualAfterScanner = true
                })
            }
            .sheet(isPresented: $showEMUScanner) {
                EMUScannerView { numbers in
                    showEMUScanner = false
                    guard let emuNumber = numbers.first else { return }
                    startDraft(emuNumber: emuNumber)
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualEMUEntryView { emuNumber in
                    showManualEntry = false
                    startDraft(emuNumber: emuNumber)
                }
            }
            .sheet(isPresented: $showDraftPicker) {
                DraftPickerView(onSelect: { draft in
                    showDraftPicker = false
                    navigateToEdit = draft
                })
            }
            .sheet(isPresented: $showDomainPicker) {
                DomainPickerView()
            }
            .sheet(isPresented: $showDomainSettings) {
                DomainSettingsView()
            }
            .navigationDestination(item: $navigateToEdit) { draft in
                TripEditView(draft: draft)
            }
        }
    }

    /// 与扫码完成一致的流程：建草稿 → 位置验证 → 进入填写
    private func startDraft(emuNumber: String) {
        verifying = true
        let scanned = ScannedTripData(emuNumber: emuNumber, carriage: "", seat: "")
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

/// 手动输入车身编号：选择车型 + 输入四位数字
struct ManualEMUEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let onConfirm: (String) -> Void

    @State private var selectedCode = ""
    @State private var number = ""

    private var isValid: Bool {
        !selectedCode.isEmpty && number.count == 4
    }

    var body: some View {
        NavigationStack {
            Form {
                HStack(spacing: 8) {
                    Menu {
                        ForEach(trainModels) { model in
                            Button(model.name) {
                                selectedCode = model.code
                            }
                        }
                    } label: {
                        Text(selectedCode.isEmpty ? "请选择" : selectedCode)
                            .fontDesign(.monospaced)
                            .foregroundStyle(selectedCode.isEmpty ? Color.secondary : Color.primary)
                    }

                    Text("-")
                        .foregroundStyle(.secondary)

                    TextField("四位数字编号", text: $number)
                        .keyboardType(.numberPad)
                        .fontDesign(.monospaced)
                        .multilineTextAlignment(.leading)
                        .onChange(of: number) { _, newValue in
                            number = String(newValue.filter(\.isNumber).prefix(4))
                        }
                }
            }
            .navigationTitle("手动输入车身编号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        onConfirm("\(selectedCode)-\(number)")
                    }
                    .disabled(!isValid)
                }
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
                                        .fontDesign(.monospaced)
                                } else {
                                    Text("空草稿")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(draft.createdAt.zhRelative)
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
