import SwiftUI

struct AboutView: View {
    @Environment(DataStore.self) private var store
    @State private var refreshing = false

    private var totalTrips: Int {
        store.logs.filter { !$0.isDraft }.count
    }

    private var totalDuration: TimeInterval {
        store.logs.compactMap { $0.duration }.reduce(0, +)
    }

    private var totalDurationFormatted: String {
        let total = totalDuration
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 {
            return "\(hours) 小时 \(minutes) 分钟"
        }
        return "\(minutes) 分钟"
    }

    private var unlockedModelCodes: Set<String> {
        let emuNumbers = store.logs.map { $0.emuNumber }.filter { !$0.isEmpty }
        let sortedModels = trainModels.sorted { $0.code.count > $1.code.count }
        var unlocked = Set<String>()
        for emu in emuNumbers {
            for model in sortedModels where emu.hasPrefix(model.code) {
                unlocked.insert(model.code)
                break
            }
        }
        return unlocked
    }

    private var modelSeries: [ModelSeries] {
        groupModelsBySeries()
    }

    private var modelProgress: Double {
        guard !trainModels.isEmpty else { return 0 }
        return Double(unlockedModelCodes.count) / Double(trainModels.count)
    }

    private var stationVisitCounts: [(station: String, count: Int)] {
        var counts: [String: Int] = [:]
        for log in store.logs where !log.isDraft {
            for station in [log.departureStation, log.arrivalStation, log.originStation, log.destinationStation] where !station.isEmpty {
                counts[station, default: 0] += 1
            }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }

    private var updateTimeString: String {
        if let t = store.dataUpdateTime {
            return t.formatted(date: .numeric, time: .omitted)
        }
        return "未更新"
    }

    var body: some View {
        NavigationStack {
            List {
                // 运转统计
                Section {
                    HStack {
                        Label("运转次数", systemImage: "tram")
                        Spacer()
                        Text("\(totalTrips) 次")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("运转时长", systemImage: "hourglass")
                        Spacer()
                        Text(totalDurationFormatted)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("运转统计")
                }

                // 统计入口
                Section {
                    NavigationLink {
                        ModelUnlockView(
                            unlockedModelCodes: unlockedModelCodes,
                            modelSeries: modelSeries
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "train.side.front.car")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("车型统计")
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text("\(unlockedModelCodes.count)/\(trainModels.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                ProgressView(value: modelProgress)
                                    .tint(.blue)
                            }
                        }
                    }

                    NavigationLink {
                        StationStatsView(stations: stationVisitCounts)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "building.2.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 32)
                            Text("车站统计")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(stationVisitCounts.count) 个车站")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // 数据包更新
                Section {
                    HStack {
                        Text("数据包更新时间")
                            .font(.subheadline)
                        Spacer()
                        if refreshing {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Text(updateTimeString)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        refreshing = true
                        Task {
                            await store.refreshBundleData()
                            refreshing = false
                        }
                    } label: {
                        Label("刷新数据包", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(refreshing)
                } footer: {
                    Text("数据包包含车站列表、车型字典、路局与段信息等基础数据。车站数据来自 [rail.re](https://rail.re)，车型数据来自 [china-emu.cn](https://www.china-emu.cn)。")
                }

                // 意见和建议
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("意见和建议")
                            .font(.subheadline)
                        Link("mikewu597@matrixecho.cn", destination: URL(string: "mailto:mikewu597@matrixecho.cn")!)
                            .font(.caption)
                        Link("i@hyp.ink", destination: URL(string: "mailto:i@hyp.ink")!)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("统计")
        }
    }

    private func groupModelsBySeries() -> [ModelSeries] {
        var groups: [String: [TrainModel]] = [:]

        for model in trainModels {
            groups[model.series, default: []].append(model)
        }

        let order = [
            "CR450 复兴号", "CR400 复兴号", "CR400 智能",
            "CR300 复兴号", "CR200J 动集",
            "CRH380 和谐号", "CRH1 和谐号", "CRH2 和谐号",
            "CRH3 和谐号", "CRH5 和谐号", "CRH6 和谐号"
        ]
        let sorted = groups.sorted { a, b in
            let ai = order.firstIndex(of: a.key) ?? 99
            let bi = order.firstIndex(of: b.key) ?? 99
            return ai < bi
        }

        return sorted.map { ModelSeries(name: $0.key, models: $0.value) }
    }
}

// MARK: - 车型系列

struct ModelSeries: Identifiable {
    var id: String { name }
    let name: String
    let models: [TrainModel]
}

#Preview {
    AboutView()
        .environment(DataStore())
}
