import SwiftUI

struct LogListView: View {
    @Environment(DataStore.self) private var store
    @State private var searchText = ""
    @State private var filterBureau: String = "全部"
    @State private var sortOrder: SortOrder = .newest

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
        ["全部"] + railwayBureaus.map(\.name)
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
                            NavigationLink {
                                LogDetailView(log: log)
                            } label: {
                                LogRow(log: log)
                            }
                        }
                        .onDelete { offsets in
                            for idx in offsets {
                                store.deleteLog(filteredLogs[idx])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("运转日志")
            .searchable(text: $searchText, prompt: "搜索车次、车站...")
        }
    }
}

struct LogRow: View {
    let log: TripLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.trainNumber.isEmpty ? log.emuNumber : log.trainNumber)
                    .font(.headline)
                if !log.carriage.isEmpty || !log.seat.isEmpty {
                    Text("\(log.carriage)车\(log.seat)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(log.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !log.trainNumber.isEmpty && !log.emuNumber.isEmpty {
                Text(log.emuNumber)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text(log.departureStation)
                    .font(.subheadline)
                Text("→")
                    .foregroundStyle(.secondary)
                Text(log.arrivalStation)
                    .font(.subheadline)

                if !log.durationFormatted.isEmpty {
                    Spacer()
                    Label(log.durationFormatted, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !log.bureau.isEmpty {
                Text("\(log.bureau) \(log.depot)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LogListView()
        .environment(DataStore())
}
