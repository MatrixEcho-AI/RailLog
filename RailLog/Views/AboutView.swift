import SwiftUI

struct AboutView: View {
    @Environment(DataStore.self) private var store
    /// 教程演示用：隐藏自带导航大标题
    var hideNavigationBar = false
    /// 教程演示用：0~1，统计数字按比例从 0 增长；默认 1（正常显示）
    var demoProgress: Double = 1
    @State private var showGameCenter = false
    private var totalTrips: Int {
        store.logs.filter { !$0.isDraft }.count
    }

    private var totalDuration: TimeInterval {
        store.logs.compactMap { $0.duration }.reduce(0, +)
    }

    private var totalDurationFormatted: String {
        let total = totalDuration * demoProgress
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 {
            return "\(hours) 小时 \(minutes) 分钟"
        }
        return "\(minutes) 分钟"
    }

    /// 以下均为 demoProgress 缩放后的演示值（生产 demoProgress=1，数值不变）
    private var displayTrips: Int { Int((Double(totalTrips) * demoProgress).rounded()) }
    private var displayUnlockedCount: Int { Int((Double(unlockedModelCodes.count) * demoProgress).rounded()) }
    private var displayStationCount: Int { Int((Double(stationVisitCounts.count) * demoProgress).rounded()) }
    private var displayModelProgress: Double { modelProgress * demoProgress }

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

    var body: some View {
        NavigationStack {
            List {
                // 运转统计
                Section {
                    HStack {
                        Label("运转次数", systemImage: "tram")
                        Spacer()
                        Text("\(displayTrips) 次")
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    HStack {
                        Label("运转时长", systemImage: "hourglass")
                        Spacer()
                        Text(totalDurationFormatted)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
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
                                    Text("\(displayUnlockedCount)/\(trainModels.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .contentTransition(.numericText())
                                }
                                ProgressView(value: displayModelProgress)
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
                            Text("\(displayStationCount) 个车站")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                    }
                }

                // Game Center 成就
                Section {
                    Button {
                        showGameCenter = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trophy.fill")
                                .font(.title3)
                                .foregroundStyle(.yellow)
                                .frame(width: 32)
                            Text("Game Center 成就")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

            }
            .navigationTitle("统计")
            .toolbar(hideNavigationBar ? .hidden : .automatic, for: .navigationBar)
            .sheet(isPresented: $showGameCenter) {
                GKGameCenterView()
            }
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
