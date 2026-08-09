import PassKit
import SwiftUI

struct LogDetailView: View {
    @Environment(DataStore.self) private var store
    @State var log: TripLog
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var matchingRequest: MatchingLogsRequest?
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
            }

            // 车次信息
            Section("列车信息") {
                if !log.trainNumber.isEmpty {
                    Button {
                        matchingRequest = MatchingLogsRequest(
                            title: "车次 \(log.trainNumber)",
                            logs: store.logs.filter { $0.trainNumber == log.trainNumber }
                        )
                    } label: {
                        HStack {
                            Text("车次")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(log.trainNumber)
                                .fontDesign(.monospaced)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if !log.emuNumber.isEmpty {
                    Button {
                        matchingRequest = MatchingLogsRequest(
                            title: "动车组 \(log.emuNumber)",
                            logs: store.logs.filter { $0.emuNumber == log.emuNumber }
                        )
                    } label: {
                        HStack {
                            Text("动车组")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(log.emuNumber)
                                .fontDesign(.monospaced)
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

            // 站点信息（时间轴）
            Section("站点信息") {
                stationTimeline
            }

            // 备注
            if !log.notes.isEmpty {
                Section("备注") {
                    Text(log.notes)
                        .font(.body)
                }
            }

            // 运转详情
            if !log.mileage.isEmpty || !log.maxSpeed.isEmpty || !log.bureau.isEmpty || !log.depot.isEmpty {
                Section("运转详情") {
                    DetailRow(label: "运转里程", value: log.mileage.isEmpty ? "-" : "\(log.mileage) km")
                    DetailRow(label: "最高时速", value: log.maxSpeed.isEmpty ? "-" : "\(log.maxSpeed) km/h")
                    DetailRow(label: "担当路局", value: log.bureau) { showBureauLogs(log.bureau) }
                    DetailRow(label: "担当段", value: log.depot) { showDepotLogs(log.depot) }
                }
            }

            // 钱包
            Section {
                walletButton
            }

            // 操作
            Section {
                Button("编辑此日志") { showEdit = true }
                Button("删除此日志", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
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

    // MARK: - 站点时间轴

    private struct TimelinePoint {
        let role: String      // 始发/出发/到达/终到（合并时为 始发、出发 / 到达、终到）
        let station: String
        let time: Date?
        /// 独立显示的始发/终到节点（未与出发/到达合并）——灰点、灰 badge
        let isTerminus: Bool
    }

    /// 按分钟精度比较两个时间（DatePicker 的值可能带不同的秒数）；同为 nil 视为相同
    private func sameMinute(_ a: Date?, _ b: Date?) -> Bool {
        guard let a, let b else { return a == b }
        let cal = Calendar.current
        let keys: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]
        return cal.dateComponents(keys, from: a) == cal.dateComponents(keys, from: b)
    }

    private var timelinePoints: [TimelinePoint] {
        // 始发与出发同站且同一时间 → 合并为"始发、出发"；到达与终到同理
        let mergeOrigin = !log.originStation.isEmpty
            && log.originStation == log.departureStation
            && sameMinute(log.originTime, log.departureTime)
        let mergeDestination = !log.destinationStation.isEmpty
            && log.destinationStation == log.arrivalStation
            && sameMinute(log.arrivalTime, log.destinationTime)

        var points: [TimelinePoint] = []
        if !log.originStation.isEmpty {
            points.append(TimelinePoint(
                role: mergeOrigin ? "始发、出发" : "始发",
                station: log.originStation,
                time: log.originTime,
                isTerminus: !mergeOrigin
            ))
        }
        if !mergeOrigin {
            points.append(TimelinePoint(role: "出发", station: log.departureStation, time: log.departureTime, isTerminus: false))
        }
        if !mergeDestination {
            points.append(TimelinePoint(role: "到达", station: log.arrivalStation, time: log.arrivalTime, isTerminus: false))
        }
        if !log.destinationStation.isEmpty {
            points.append(TimelinePoint(
                role: mergeDestination ? "到达、终到" : "终到",
                station: log.destinationStation,
                time: log.destinationTime,
                isTerminus: !mergeDestination
            ))
        }
        return points
    }

    /// 时间轴顶部的初始日期（第一个有时间的节点）
    private var timelineStartDate: Date? {
        timelinePoints.first { $0.time != nil }?.time
    }

    /// 节点相对初始日期的跨日偏移（0=当天，1=次日…）；无时间或早于起始日时为 0
    private func timelineDayOffset(for point: TimelinePoint) -> Int {
        guard let t = point.time, let base = timelineStartDate else { return 0 }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: base), to: cal.startOfDay(for: t)).day ?? 0
        return max(days, 0)
    }

    private var stationTimeline: some View {
        let points = timelinePoints
        return VStack(alignment: .leading, spacing: 0) {
            if let start = timelineStartDate {
                Text(start.zhDate)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 28) // 与轴右侧内容对齐
                    .padding(.bottom, 4)
            }
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                // 轴分段着色：两端都是蓝点（非端点）的连接线用蓝色
                let topBlue = index > 0 && !points[index - 1].isTerminus && !point.isTerminus
                let bottomBlue = index < points.count - 1 && !points[index + 1].isTerminus && !point.isTerminus
                timelineNodeRow(
                    point: point,
                    dayOffset: timelineDayOffset(for: point),
                    isFirst: index == 0,
                    isLast: index == points.count - 1,
                    topLineBlue: topBlue,
                    bottomLineBlue: bottomBlue
                )
            }
        }
        .padding(.vertical, 6)
    }

    private func timelineNodeRow(point: TimelinePoint, dayOffset: Int, isFirst: Bool, isLast: Bool, topLineBlue: Bool, bottomLineBlue: Bool) -> some View {
        let grayLine = Color.secondary.opacity(0.45)
        return HStack(spacing: 12) {
            // 左侧轴：竖线贯通整行，圆点压在线上方（重叠绘制，避免相切处的抗锯齿缝隙）
            ZStack {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(isFirst ? Color.clear : (topLineBlue ? Color.accentColor : grayLine))
                        .frame(width: 4)
                    Rectangle()
                        .fill(isLast ? Color.clear : (bottomLineBlue ? Color.accentColor : grayLine))
                        .frame(width: 4)
                }
                Circle()
                    .fill(point.isTerminus ? Color.gray : Color.accentColor)
                    .frame(width: 13, height: 13)
            }
            .frame(width: 16)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(point.time?.zhTime ?? "--:--")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(point.time == nil ? .tertiary : .primary)
                if dayOffset > 0 {
                    Text("+\(dayOffset)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .baselineOffset(6)
                }
            }
            .frame(width: 72, alignment: .leading)

            Button {
                showStationLogs(point.station)
            } label: {
                HStack(spacing: 6) {
                    Text(point.station)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            point.isTerminus ? Color.gray.opacity(0.18) : Color.accentColor.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                    Text(point.role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(height: 46)
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
