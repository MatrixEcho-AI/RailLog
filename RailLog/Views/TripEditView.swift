import SwiftUI

struct TripEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    init(draft: TripLog) {
        _log = State(initialValue: draft)
        _isDraftMode = State(initialValue: draft.isDraft)
    }

    init(existingLog: TripLog) {
        _log = State(initialValue: existingLog)
        _isDraftMode = State(initialValue: existingLog.isDraft)
    }

    @State private var log: TripLog
    @State private var isDraftMode: Bool
    @State private var selectedBureau: String = ""
    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var showExtraStations = false
    @State private var reVerifying = false

    private var now: Date { Date() }
    private let maxTripDuration: TimeInterval = 48 * 3600

    private var canEditStationTime: Bool { isDraftMode }

    private var canSaveAsDraft: Bool {
        !log.departureStation.isEmpty && !log.arrivalStation.isEmpty && log.verifiedOnRailway == true
    }

    private var canFinalize: Bool {
        guard canSaveAsDraft else { return false }
        guard log.departureTime != nil, log.arrivalTime != nil else { return false }
        guard let dep = log.departureTime, dep <= now else { return false }
        return true
    }

    private func reVerify() {
        reVerifying = true
        Task {
            let result = await LocationVerifier.verify()
            log.verifiedOnRailway = result.onRailway
            reVerifying = false
        }
    }

    private var saveDisabledMessage: String {
        if log.departureStation.isEmpty || log.arrivalStation.isEmpty { return "请至少填写出发站和到达站" }
        if log.verifiedOnRailway != true { return "请先验证位置" }
        return ""
    }

    // 始发 <= 出发 < now
    private var originRange: ClosedRange<Date> {
        let upper = log.departureTime ?? now
        return Date.distantPast ... upper
    }

    private var departureRange: ClosedRange<Date> {
        let lower = log.originTime ?? Date.distantPast
        return lower ... now
    }

    // 出发 <= 到达 <= 终到; 到达 <= 出发 + 48h
    private var arrivalRange: ClosedRange<Date> {
        let lower = log.departureTime ?? Date.distantPast
        var upper = log.destinationTime ?? Date.distantFuture
        if let dep = log.departureTime {
            upper = min(upper, dep.addingTimeInterval(maxTripDuration))
        }
        return lower ... max(lower, upper)
    }

    private var destinationRange: ClosedRange<Date> {
        let lower = log.arrivalTime ?? log.departureTime ?? Date.distantPast
        var upper = Date.distantFuture
        if let dep = log.departureTime {
            upper = dep.addingTimeInterval(maxTripDuration)
        }
        return lower ... max(lower, upper)
    }

    private var depotsForSelectedBureau: [String] {
        let bureaus = DataBundleService.shared.branches
        if bureaus.isEmpty { return railwayBureaus.first(where: { $0.name == selectedBureau })?.depots ?? [] }
        return bureaus.first(where: { $0.name == selectedBureau })?.depots ?? []
    }

    var body: some View {
        Form {
            // MARK: - 车次信息
            Section {
                LabeledContent("车次") {
                    TrainNumberTextField(text: $log.trainNumber)
                }
                LabeledContent("动车组编号") {
                    TextField("e.g. CR400AF-2186", text: $log.emuNumber)
                        .multilineTextAlignment(.trailing)
                        .fontDesign(.monospaced)
                        .disabled(true)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("车厢") {
                    TextField("e.g. 04", text: $log.carriage)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
                LabeledContent("座位") {
                    TextField("e.g. 05C", text: $log.seat)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("车次信息")
            } footer: {
                VStack(spacing: 4) {
                    if reVerifying {
                        HStack {
                            Spacer()
                            ProgressView("正在验证...")
                                .font(.subheadline)
                            Spacer()
                        }
                    } else if let verified = log.verifiedOnRailway {
                        HStack {
                            Spacer()
                            if verified {
                                Label("已确认在铁路上", systemImage: "checkmark.shield.fill")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.green)
                            } else {
                                Button {
                                    reVerify()
                                } label: {
                                    Label("未能确认铁路位置，点击重试", systemImage: "exclamationmark.triangle.fill")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.orange)
                                }
                            }
                            Spacer()
                        }
                    } else {
                        Button {
                            reVerify()
                        } label: {
                            Label("点击验证位置", systemImage: "location.circle")
                                .font(.subheadline.bold())
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // MARK: - 运转信息
            Section("运转信息") {
                LabeledContent("运转里程 (km)") {
                    TextField("选填", text: $log.mileage)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }
                LabeledContent("最高时速 (km/h)") {
                    TextField("选填", text: $log.maxSpeed)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }

                Picker("担当路局", selection: $selectedBureau) {
                    Text("未选择").tag("")
                    let bureaus = DataBundleService.shared.branches.isEmpty ? railwayBureaus : DataBundleService.shared.branches
                    ForEach(bureaus) { bureau in
                        Text(bureau.name).tag(bureau.name)
                    }
                }
                .onChange(of: selectedBureau) { _, newValue in
                    log.bureau = newValue
                    if !depotsForSelectedBureau.contains(log.depot) {
                        log.depot = ""
                    }
                }

                if !depotsForSelectedBureau.isEmpty {
                    Picker("担当段", selection: $log.depot) {
                        Text("未选择").tag("")
                        ForEach(depotsForSelectedBureau, id: \.self) { depot in
                            Text(depot).tag(depot)
                        }
                    }
                }
            }

            // MARK: - 站点与时间
            Section {
                if showExtraStations {
                    StationTimeRow(
                        label: "始发站",
                        station: $log.originStation,
                        time: $log.originTime,
                        dateRange: originRange,
                        editable: canEditStationTime
                    )
                }

                StationTimeRow(
                    label: "出发站",
                    station: $log.departureStation,
                    time: $log.departureTime,
                    dateRange: departureRange,
                    editable: canEditStationTime
                )

                StationTimeRow(
                    label: "到达站",
                    station: $log.arrivalStation,
                    time: $log.arrivalTime,
                    dateRange: arrivalRange,
                    editable: canEditStationTime
                )

                if showExtraStations {
                    StationTimeRow(
                        label: "终到站",
                        station: $log.destinationStation,
                        time: $log.destinationTime,
                        dateRange: destinationRange,
                        editable: canEditStationTime
                    )
                }

                if canEditStationTime {
                    Button {
                        if showExtraStations {
                            log.originStation = ""
                            log.originTime = nil
                            log.destinationStation = ""
                            log.destinationTime = nil
                        }
                        withAnimation { showExtraStations.toggle() }
                    } label: {
                        Label(showExtraStations ? "收起始发/终到" : "添加始发/终到", systemImage: showExtraStations ? "minus.circle" : "plus.circle")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderless)
                }
            } header: {
                Text("站点与时间")
            } footer: {
                let duration = log.durationFormatted
                if !duration.isEmpty {
                    HStack {
                        Spacer()
                        Label("运转时长：\(duration)", systemImage: "clock")
                            .font(.subheadline.bold())
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: - 保存
            Section {
                if isDraftMode {
                    Button {
                        if canSaveAsDraft {
                            store.updateDraft(log)
                            dismiss()
                        } else {
                            saveAlertMessage = saveDisabledMessage
                            showSaveAlert = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.ellipsis")
                            Text("保存草稿")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(canSaveAsDraft ? .blue : .secondary)
                    }
                    .disabled(!canSaveAsDraft)

                    Button {
                        if canFinalize {
                            store.finalizeDraft(log)
                            dismiss()
                        } else {
                            saveAlertMessage = saveDisabledMessage
                            showSaveAlert = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("完成运转")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(canFinalize ? .blue : .secondary)
                    }
                    .disabled(!canFinalize)
                } else {
                    Button {
                        if canSaveAsDraft {
                            store.updateLog(log)
                            dismiss()
                        } else {
                            saveAlertMessage = saveDisabledMessage
                            showSaveAlert = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("保存修改")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(canSaveAsDraft ? .blue : .secondary)
                    }
                    .disabled(!canSaveAsDraft)
                }
            }
        }
        .navigationTitle(isDraftMode ? "填写运转" : "编辑运转")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
        .alert("提示", isPresented: $showSaveAlert) {
            Button("确定") {}
        } message: {
            Text(saveAlertMessage)
        }
        .onAppear {
            selectedBureau = log.bureau
            showExtraStations = !log.originStation.isEmpty || !log.destinationStation.isEmpty || log.originTime != nil || log.destinationTime != nil
        }
    }
}

// MARK: - 站点+时间行

private struct StationTimeRow: View {
    let label: String
    @Binding var station: String
    @Binding var time: Date?
    let dateRange: ClosedRange<Date>
    let editable: Bool

    @State private var showStationPicker = false
    @State private var pickerDate: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline.bold())

                Spacer()

                Button {
                    if editable { showStationPicker = true }
                } label: {
                    HStack {
                        Text(station.isEmpty ? "选择车站" : station)
                            .foregroundStyle(station.isEmpty ? .secondary : .primary)
                        if editable {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(!editable)
            }

            DatePicker("时间", selection: $pickerDate, in: dateRange, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .disabled(!editable || station.isEmpty)
                .onAppear {
                    if let t = time {
                        pickerDate = t
                    } else {
                        // 确保初始值在范围内
                        pickerDate = min(max(pickerDate, dateRange.lowerBound), dateRange.upperBound)
                    }
                }
                .onChange(of: pickerDate) { _, newValue in
                    time = newValue
                }
                .onChange(of: time) { _, newValue in
                    if let t = newValue { pickerDate = t }
                }
                .onChange(of: station) { _, newValue in
                    // 用户选择了车站但尚未设时间时，自动填入当前选择器值
                    if !newValue.isEmpty && time == nil {
                        let clamped = min(max(pickerDate, dateRange.lowerBound), dateRange.upperBound)
                        pickerDate = clamped
                        time = clamped
                    }
                }
        }
        .sheet(isPresented: $showStationPicker) {
            StationPickerView(
                title: "选择\(label)",
                onSelect: { s in
                    station = s.name
                    showStationPicker = false
                }
            )
        }
    }
}

// MARK: - 车站选择器

private struct StationPickerView: View {
    let title: String
    let onSelect: (RailwayStation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var allStations: [RailwayStation] {
        let sorted = railwayStations.sorted { $0.name < $1.name }
        if searchText.isEmpty { return sorted }
        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.bureau.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(allStations) { station in
                Button {
                    onSelect(station)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(station.name)
                            Text("\(station.bureau) · \(station.code)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if station.isHighSpeed {
                            Text("G/D")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.1), in: .capsule)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索车站")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TripEditView(draft: TripLog(
            trainNumber: "G81",
            emuNumber: "CR400AF-2186",
            carriage: "04", seat: "05C"
        ))
        .environment(DataStore())
    }
}
