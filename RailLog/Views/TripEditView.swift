import SwiftUI

struct TripEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    // 可通过草稿或已有日志初始化
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

    private var canSaveAsDraft: Bool {
        !log.departureStation.isEmpty && !log.arrivalStation.isEmpty
    }

    private var canFinalize: Bool {
        canSaveAsDraft && log.departureTime != nil && log.arrivalTime != nil
    }

    private var depotsForSelectedBureau: [String] {
        railwayBureaus.first(where: { $0.name == selectedBureau })?.depots ?? []
    }

    var body: some View {
        Form {
            // MARK: - 车次信息
            Section("车次信息") {
                LabeledContent("车次") {
                    TextField("e.g. G81", text: $log.trainNumber)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("动车组编号") {
                    TextField("e.g. CR400AF-2186", text: $log.emuNumber)
                        .multilineTextAlignment(.trailing)
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
                    ForEach(railwayBureaus) { bureau in
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
                StationTimeRow(
                    label: "始发站",
                    station: $log.originStation,
                    time: $log.originTime,
                    required: false
                )
                .listRowBackground(Color.clear)

                StationTimeRow(
                    label: "出发站",
                    station: $log.departureStation,
                    time: $log.departureTime,
                    required: true
                )

                StationTimeRow(
                    label: "到达站",
                    station: $log.arrivalStation,
                    time: $log.arrivalTime,
                    required: true
                )

                StationTimeRow(
                    label: "终到站",
                    station: $log.destinationStation,
                    time: $log.destinationTime,
                    required: false
                )
            } header: {
                Text("站点与时间")
            } footer: {
                // 运转时长
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
                            saveAlertMessage = "请至少填写出发站和到达站"
                            showSaveAlert = true
                        }
                    } label: {
                        Label("保存草稿", systemImage: "doc.badge.ellipsis")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSaveAsDraft)

                    Button {
                        if canFinalize {
                            store.finalizeDraft(log)
                            dismiss()
                        } else {
                            saveAlertMessage = "完成运转需要至少填写出发站、到达站及其时间"
                            showSaveAlert = true
                        }
                    } label: {
                        Label("完成运转", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canFinalize)
                } else {
                    Button {
                        if canSaveAsDraft {
                            store.updateLog(log)
                            dismiss()
                        } else {
                            saveAlertMessage = "请至少填写出发站和到达站"
                            showSaveAlert = true
                        }
                    } label: {
                        Label("保存修改", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
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
        }
    }
}

// MARK: - 站点+时间行

private struct StationTimeRow: View {
    let label: String
    @Binding var station: String
    @Binding var time: Date?
    let required: Bool

    @State private var showStationPicker = false
    @State private var pickerDate: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if required {
                    Text("*")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundStyle(required ? .primary : .secondary)

                Spacer()

                Button {
                    showStationPicker = true
                } label: {
                    HStack {
                        Text(station.isEmpty ? "选择车站" : station)
                            .foregroundStyle(station.isEmpty ? .secondary : .primary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            DatePicker("时间", selection: $pickerDate, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .disabled(station.isEmpty)
                .onChange(of: pickerDate) { _, newValue in
                    time = newValue
                }
                .onAppear {
                    if let t = time { pickerDate = t }
                }
                .onChange(of: time) { _, newValue in
                    if let t = newValue { pickerDate = t }
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
