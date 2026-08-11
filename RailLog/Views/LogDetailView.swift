import PassKit
import SwiftUI

struct LogDetailView: View {
    @Environment(DataStore.self) private var store
    @State var log: TripLog
    /// 教程演示用：按分区索引依次显示；默认全部显示
    var revealCount: Int = .max
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var matchingRequest: MatchingLogsRequest?
    @State private var passError: String?
    @Environment(\.dismiss) private var dismiss

    private var walletButtonMode: WalletButton.Mode {
        guard let addedAt = log.walletPassAddedAt else { return .add }
        return log.modifiedAt > addedAt ? .update : .added
    }

    var body: some View {
        List {
            // 地图
            if !log.departureStation.isEmpty, !log.arrivalStation.isEmpty {
                Section {
                    TripMapView(
                        departureStation: log.departureStation,
                        arrivalStation: log.arrivalStation,
                        originStation: log.originStation,
                        destinationStation: log.destinationStation
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                .opacity(revealCount > 0 ? 1 : 0)
            }

            // 行程信息（时间轴）
            Section("行程信息") {
                TripTimelineView(
                    log: log,
                    onSelectStation: showStationLogs,
                    onSelectTrain: {
                        matchingRequest = MatchingLogsRequest(
                            title: "车次 \(log.trainNumber)",
                            logs: store.logs.filter { $0.trainNumber == log.trainNumber }
                        )
                    },
                    onSelectEMU: {
                        matchingRequest = MatchingLogsRequest(
                            title: "动车组 \(log.emuNumber)",
                            logs: store.logs.filter { $0.emuNumber == log.emuNumber }
                        )
                    }
                )
            }
            .opacity(revealCount > 1 ? 1 : 0)

            // 备注
            if !log.notes.isEmpty {
                Section("备注") {
                    Text(log.notes)
                        .font(.body)
                }
                .opacity(revealCount > 2 ? 1 : 0)
            }

            // 运转详情
            if !log.mileage.isEmpty || !log.maxSpeed.isEmpty || !log.bureau.isEmpty || !log.depot.isEmpty {
                Section("运转详情") {
                    DetailRow(label: "运转里程", value: log.mileage.isEmpty ? "-" : "\(log.mileage) km")
                    DetailRow(label: "最高时速", value: log.maxSpeed.isEmpty ? "-" : "\(log.maxSpeed) km/h")
                    DetailRow(label: "担当路局", value: log.bureau) { showBureauLogs(log.bureau) }
                    DetailRow(label: "担当段", value: log.depot) { showDepotLogs(log.depot) }
                }
                .opacity(revealCount > 3 ? 1 : 0)
            }

            // 钱包
            Section {
                walletButton
            }
            .opacity(revealCount > 4 ? 1 : 0)

            // 操作
            Section {
                Button("编辑此日志") { showEdit = true }
                Button("删除此日志", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
            .opacity(revealCount > 5 ? 1 : 0)
        }
        .navigationTitle("运转详情")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    log.isFavorite.toggle()
                    store.updateLog(log)
                } label: {
                    Image(systemName: log.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(log.isFavorite ? .red : .secondary)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                TripEditView(existingLog: log)
            }
        }
        .onChange(of: showEdit) { _, newValue in
            if !newValue, let updated = store.logs.first(where: { $0.id == log.id }) {
                log = updated
            }
        }
        .alert("删除运转日志", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("确定删除", role: .destructive) {
                store.deleteLog(log)
                dismiss()
            }
        } message: {
            let title = log.trainNumber.isEmpty ? log.emuNumber : log.trainNumber
            Text("「\(title)」将被永久删除，不可恢复。")
        }
        .sheet(item: $matchingRequest) { request in
            MatchingLogsSheet(title: request.title, logs: request.logs)
        }
        .alert("无法添加到钱包", isPresented: .init(
            get: { passError != nil },
            set: { if !$0 { passError = nil } }
        )) {
            Button("确定") { passError = nil }
        } message: {
            if let error = passError { Text(error) }
        }
    }

    // MARK: - Navigation Helpers

    /// 筛选弹窗请求：用 .sheet(item:) 呈现，内容随呈现一次性定型，
    /// 避免 isPresented + 外部状态驱动时首次呈现空白的问题
    private struct MatchingLogsRequest: Identifiable {
        let id = UUID()
        let title: String
        let logs: [TripLog]
    }

    private func showStationLogs(_ name: String) {
        guard !name.isEmpty else { return }
        matchingRequest = MatchingLogsRequest(
            title: "站点 \(name)",
            logs: store.logs.filter { log in
                log.originStation == name || log.departureStation == name ||
                log.arrivalStation == name || log.destinationStation == name
            }
        )
    }

    private func showBureauLogs(_ bureau: String) {
        guard !bureau.isEmpty else { return }
        matchingRequest = MatchingLogsRequest(
            title: "路局 \(bureau)",
            logs: store.logs.filter { $0.bureau == bureau }
        )
    }

    private func showDepotLogs(_ depot: String) {
        guard !depot.isEmpty else { return }
        matchingRequest = MatchingLogsRequest(
            title: "客运段 \(depot)",
            logs: store.logs.filter { $0.depot == depot }
        )
    }

    // MARK: - Wallet Button

    private var walletButton: some View {
        WalletButton(mode: walletButtonMode) { generateAndPresentPass() }
    }

    private func generateAndPresentPass() {
        do {
            let data = try PassGenerator().generate(for: log)
            // 先本地校验，避免弹出空白的 Wallet 页面
            let pass = try PKPass(data: data)
            WalletPassPresenter.present(pass) { added in
                if added { onPassAdded() }
            }
        } catch {
            print("[Wallet] generate/validate failed: \(error)")
            passError = error.localizedDescription
        }
    }

    private func onPassAdded() {
        log.walletPassAddedAt = Date()
        store.markWalletPassAdded(log)
    }
}

/// 钱包按钮（详情页与教程演示共用）
struct WalletButton: View {
    enum Mode { case add, update, added }

    let mode: Mode
    let action: () -> Void

    var body: some View {
        switch mode {
        case .add:
            Button(action: action) {
                Label("添加到钱包", systemImage: "wallet.pass")
            }
        case .update:
            Button(action: action) {
                Label("更新钱包卡片", systemImage: "wallet.pass")
            }
        case .added:
            HStack {
                Label("已在钱包中", systemImage: "wallet.pass.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    var action: (() -> Void)?

    init(label: String, value: String, action: (() -> Void)? = nil) {
        self.label = label
        self.value = value
        self.action = action
    }

    var body: some View {
        if !value.isEmpty && value != "-" {
            if let action {
                Button(action: action) {
                    HStack {
                        Text(label)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(value)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Text(label)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(value)
                }
            }
        }
    }
}

private struct MatchingLogsSheet: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let title: String
    let logs: [TripLog]

    var body: some View {
        NavigationStack {
            List {
                ForEach(logs) { log in
                    ZStack {
                        NavigationLink {
                            LogDetailView(log: log)
                        } label: {
                            EmptyView()
                        }
                        .opacity(0)

                        LogRow(log: log, preferTrainNumber: store.preferTrainNumber, hdrEnabled: store.hdrEnabled)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LogDetailView(log: TripLog(
            trainNumber: "G81",
            emuNumber: "CR400AF-2186",
            carriage: "04", seat: "05C",
            bureau: "北京局", depot: "北京客运段",
            departureStation: "北京南", arrivalStation: "上海虹桥",
            departureTime: Date(), arrivalTime: Date().addingTimeInterval(4.5 * 3600)
        ))
        .environment(DataStore())
    }
}
