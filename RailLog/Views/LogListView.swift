import SwiftUI

struct LogListView: View {
    @Environment(DataStore.self) private var store
    @State private var searchText = ""
    @State private var filterBureau: String = "全部"
    @State private var showFavoritesOnly = false
    @State private var sortOrder: SortOrder = .newest
    @State private var deleteTarget: TripLog?

    enum SortOrder: String, CaseIterable, Identifiable {
        case newest = "最新优先"
        case oldest = "最早优先"
        case longest = "时长最长"

        var id: String { rawValue }
    }

    private var filteredLogs: [TripLog] {
        var result = store.logs.filter { !$0.isDraft }

        if !searchText.isEmpty {
            result = result.filter {
                $0.trainNumber.localizedCaseInsensitiveContains(searchText) ||
                $0.emuNumber.localizedCaseInsensitiveContains(searchText) ||
                $0.departureStation.localizedCaseInsensitiveContains(searchText) ||
                $0.arrivalStation.localizedCaseInsensitiveContains(searchText) ||
                $0.bureau.localizedCaseInsensitiveContains(searchText) ||
                $0.seat.localizedCaseInsensitiveContains(searchText)
            }
        }

        if filterBureau != "全部" {
            result = result.filter { $0.bureau == filterBureau }
        }

        if showFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }

        switch sortOrder {
        case .newest:
            result.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            result.sort { $0.createdAt < $1.createdAt }
        case .longest:
            result.sort { ($0.duration ?? 0) > ($1.duration ?? 0) }
        }

        return result
    }

    private var bureauOptions: [String] {
        let bureaus = DataBundleService.shared.branches.isEmpty ? railwayBureaus : DataBundleService.shared.branches
        return ["全部"] + bureaus.map(\.name)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 筛选栏
                HStack {
                    Picker("路局", selection: $filterBureau) {
                        ForEach(bureauOptions, id: \.self) { b in
                            Text(b).tag(b)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        showFavoritesOnly.toggle()
                    } label: {
                        Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                            .foregroundStyle(showFavoritesOnly ? .red : .secondary)
                    }

                    Spacer()

                    Picker("排序", selection: $sortOrder) {
                        ForEach(SortOrder.allCases) { o in
                            Text(o.rawValue).tag(o)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                if filteredLogs.isEmpty {
                    ContentUnavailableView(
                        "暂无运转日志",
                        systemImage: "tram",
                        description: Text("点击 + 号开始记录你的铁路运转")
                    )
                } else {
                    List {
                        ForEach(filteredLogs) { log in
                            LogListRow(
                                log: log,
                                preferTrainNumber: store.preferTrainNumber,
                                hdrEnabled: store.hdrEnabled,
                                deleteTarget: $deleteTarget
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("运转日志")
            .searchable(text: $searchText, prompt: "搜索车次、车站...")
            .alert("删除运转日志", isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            )) {
                Button("取消", role: .cancel) { deleteTarget = nil }
                Button("确定删除", role: .destructive) {
                    if let log = deleteTarget { store.deleteLog(log) }
                    deleteTarget = nil
                }
            } message: {
                if let log = deleteTarget {
                    let title = log.trainNumber.isEmpty ? log.emuNumber : log.trainNumber
                    Text("「\(title)」将被永久删除，不可恢复。")
                }
            }
        }
    }
}

struct LogListRow: View {
    let log: TripLog
    let preferTrainNumber: Bool
    let hdrEnabled: Bool
    @Binding var deleteTarget: TripLog?

    var body: some View {
        ZStack {
            NavigationLink {
                LogDetailView(log: log)
            } label: {
                EmptyView()
            }
            .opacity(0)

            LogRow(log: log, preferTrainNumber: preferTrainNumber, hdrEnabled: hdrEnabled)
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteTarget = log
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

struct LogRow: View {
    let log: TripLog
    let preferTrainNumber: Bool
    let hdrEnabled: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var primaryText: String {
        if preferTrainNumber {
            return log.trainNumber.isEmpty ? log.emuNumber : log.trainNumber
        } else {
            return log.emuNumber.isEmpty ? log.trainNumber : log.emuNumber
        }
    }

    private var secondaryText: String? {
        if preferTrainNumber {
            return log.emuNumber.isEmpty || log.trainNumber.isEmpty ? nil : log.emuNumber
        } else {
            return log.trainNumber.isEmpty || log.emuNumber.isEmpty ? nil : log.trainNumber
        }
    }

    var body: some View {
        ZStack {
            if hdrEnabled && colorScheme != .dark {
                HDRMetalView(red: 1.1, green: 1.1, blue: 1.1)
            } else {
                Color(.systemBackground)
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        if log.isFavorite {
                            if hdrEnabled {
                                HDRMetalView(red: 1.3, green: 0, blue: 0)
                                    .frame(width: 12, height: 12)
                                    .mask {
                                        Image(systemName: "heart.fill")
                                            .font(.caption2)
                                    }
                            } else {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                        Text(primaryText)
                            .font(.headline)
                            .fontDesign(.monospaced)
                    }

                    if let secondary = secondaryText {
                        Text(secondary)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Text(log.departureStation)
                            .font(.subheadline)
                        Text("→")
                            .foregroundStyle(.secondary)
                        Text(log.arrivalStation)
                            .font(.subheadline)
                    }

                    if !log.bureau.isEmpty {
                        Text("\(log.bureau) \(log.depot)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text((log.departureTime ?? log.createdAt).zhDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if !log.carriage.isEmpty || !log.seat.isEmpty {
                        HStack(spacing: 4) {
                            Text("\(log.carriage)车\(log.seat)")
                            Image(systemName: "chair.lounge")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if !log.durationFormatted.isEmpty {
                        HStack(spacing: 4) {
                            Text(log.durationFormatted)
                            Image(systemName: "clock")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: colorScheme == .dark ? .white.opacity(0.15) : .black.opacity(0.15), radius: 4, y: 2)
    }
}

#Preview {
    LogListView()
        .environment(DataStore())
}
