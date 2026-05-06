import PassKit
import SwiftUI

struct LogDetailView: View {
    @Environment(DataStore.self) private var store
    @State var log: TripLog
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var showTrainLogs = false
    @State private var showEMULogs = false
    @State private var showAddPass = false
    @State private var passData: Data?
    @State private var passError: String?
    @Environment(\.dismiss) private var dismiss

    private var walletButtonState: WalletButtonState {
        guard let addedAt = log.walletPassAddedAt else { return .add }
        return log.modifiedAt > addedAt ? .update : .added
    }

    private enum WalletButtonState {
        case add, update, added
    }

    var body: some View {
        List {
            // 车次信息
            Section("列车信息") {
                if !log.trainNumber.isEmpty {
                    Button {
                        showTrainLogs = true
                    } label: {
                        HStack {
                            Text("车次")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(log.trainNumber)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if !log.emuNumber.isEmpty {
                    Button {
                        showEMULogs = true
                    } label: {
                        HStack {
                            Text("动车组")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(log.emuNumber)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if !log.carriage.isEmpty || !log.seat.isEmpty {
                    DetailRow(label: "座位", value: "\(log.carriage)车 \(log.seat)")
                }
                DetailRow(label: "运转时长", value: log.durationFormatted)
            }

            // 站点信息
            Section("站点信息") {
                DetailRow(label: "始发站", value: log.originStation)
                if let t = log.originTime {
                    DetailRow(label: "始发时间", value: t.formatted(date: .omitted, time: .shortened))
                }
                DetailRow(label: "出发站", value: log.departureStation)
                if let t = log.departureTime {
                    DetailRow(label: "出发时间", value: t.formatted(date: .omitted, time: .shortened))
                }
                DetailRow(label: "到达站", value: log.arrivalStation)
                if let t = log.arrivalTime {
                    DetailRow(label: "到达时间", value: t.formatted(date: .omitted, time: .shortened))
                }
                DetailRow(label: "终到站", value: log.destinationStation)
                if let t = log.destinationTime {
                    DetailRow(label: "终到时间", value: t.formatted(date: .omitted, time: .shortened))
                }
            }

            // 运转详情
            if !log.mileage.isEmpty || !log.maxSpeed.isEmpty || !log.bureau.isEmpty || !log.depot.isEmpty {
                Section("运转详情") {
                    DetailRow(label: "运转里程", value: log.mileage.isEmpty ? "-" : "\(log.mileage) km")
                    DetailRow(label: "最高时速", value: log.maxSpeed.isEmpty ? "-" : "\(log.maxSpeed) km/h")
                    DetailRow(label: "担当路局", value: log.bureau)
                    DetailRow(label: "担当段", value: log.depot)
                }
            }

            // 操作
            Section {
                walletButton
                Button("编辑此日志") { showEdit = true }
                Button("删除此日志", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .navigationTitle("运转详情")
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                TripEditView(existingLog: log)
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
        .sheet(isPresented: $showTrainLogs) {
            MatchingLogsSheet(title: "车次 \(log.trainNumber)", logs: store.logs.filter { $0.trainNumber == log.trainNumber })
        }
        .sheet(isPresented: $showEMULogs) {
            MatchingLogsSheet(title: "动车组 \(log.emuNumber)", logs: store.logs.filter { $0.emuNumber == log.emuNumber })
        }
        .sheet(isPresented: $showAddPass) {
            if let data = passData {
                PassAddViewController(passData: data, onAdded: onPassAdded)
            }
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

    // MARK: - Wallet Button

    @ViewBuilder
    private var walletButton: some View {
        switch walletButtonState {
        case .add:
            Button {
                generateAndPresentPass()
            } label: {
                Label("添加到钱包", systemImage: "wallet.pass")
            }
        case .update:
            Button {
                generateAndPresentPass()
            } label: {
                Label("更新钱包卡片", systemImage: "wallet.pass")
            }
        case .added:
            HStack {
                Label("已在钱包中", systemImage: "wallet.pass.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func generateAndPresentPass() {
        let generator = PassGenerator()
        do {
            passData = try generator.generate(for: log)
            showAddPass = true
        } catch {
            passError = error.localizedDescription
        }
    }

    private func onPassAdded() {
        log.walletPassAddedAt = Date()
        store.updateLog(log)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        if !value.isEmpty && value != "-" {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
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
                    NavigationLink {
                        LogDetailView(log: log)
                    } label: {
                        LogRow(log: log, preferTrainNumber: store.preferTrainNumber)
                    }
                }
            }
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

// MARK: - PKAddPassesViewController Wrapper

struct PassAddViewController: UIViewControllerRepresentable {
    let passData: Data
    let onAdded: () -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PKAddPassesViewController {
        guard let pass = try? PKPass(data: passData) else {
            return PKAddPassesViewController()
        }
        context.coordinator.pass = pass
        let vc = PKAddPassesViewController(pass: pass)
        vc?.delegate = context.coordinator
        return vc ?? PKAddPassesViewController()
    }

    func updateUIViewController(_ uiViewController: PKAddPassesViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss, onAdded: onAdded)
    }

    final class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let dismiss: DismissAction
        let onAdded: () -> Void
        var pass: PKPass?

        init(dismiss: DismissAction, onAdded: @escaping () -> Void) {
            self.dismiss = dismiss
            self.onAdded = onAdded
        }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            let added = pass.map { PKPassLibrary().containsPass($0) } ?? false
            controller.dismiss(animated: true) { [dismiss, onAdded] in
                dismiss()
                if added { onAdded() }
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
            bureau: "北京局", depot: "北京动车段",
            departureStation: "北京南", arrivalStation: "上海虹桥"
        ))
        .environment(DataStore())
    }
}
