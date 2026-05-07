import Foundation
import SwiftUI

@Observable
final class DataStore {
    private(set) var logs: [TripLog] = []
    private(set) var drafts: [TripLog] = []
    let bundleService = DataBundleService.shared
    let cloudSync = CloudSyncService.shared

    var stations: [RailwayStation] { bundleService.stations }
    var models: [TrainModel] { bundleService.models }
    var stationsUpdateTime: Date? { bundleService.stationsUpdateDate }
    var modelsUpdateTime: Date? { bundleService.modelsUpdateDate }
    var branchesUpdateTime: Date? { bundleService.branchesUpdateDate }
    var stationCount: Int { bundleService.stationCount }
    var modelCount: Int { bundleService.modelCount }
    var branchCount: Int { bundleService.branchCount }
    var depotCount: Int { bundleService.depotCount }

    /// true = 开启 HDR 显示
    var hdrEnabled: Bool {
        get { access(keyPath: \.hdrEnabled); return UserDefaults.standard.bool(forKey: "hdrEnabled") }
        set {
            withMutation(keyPath: \.hdrEnabled) {
                UserDefaults.standard.set(newValue, forKey: "hdrEnabled")
            }
        }
    }

    /// true = 主项显示车次, false = 主项显示动车组编号
    var preferTrainNumber: Bool {
        get { access(keyPath: \.preferTrainNumber); return UserDefaults.standard.bool(forKey: "preferTrainNumber") }
        set {
            withMutation(keyPath: \.preferTrainNumber) {
                UserDefaults.standard.set(newValue, forKey: "preferTrainNumber")
            }
        }
    }

    var currentDomainID: String {
        get { access(keyPath: \.currentDomainID); return UserDefaults.standard.string(forKey: "currentDomainID") ?? Domain.chinaRailway.id }
        set {
            withMutation(keyPath: \.currentDomainID) {
                UserDefaults.standard.set(newValue, forKey: "currentDomainID")
                load()
            }
        }
    }

    var currentDomain: Domain {
        Domain.all.first { $0.id == currentDomainID } ?? Domain.chinaRailway
    }

    func needsSafetyEducation(for domainID: String) -> Bool {
        guard Domain.all.first(where: { $0.id == domainID })?.safetyEducation != nil else { return false }
        return !completedSafetyEducationIDs.contains(domainID)
    }

    func markSafetyEducationCompleted(for domainID: String) {
        completedSafetyEducationIDs.insert(domainID)
    }

    private(set) var safetyRelearnToken = 0

    func triggerSafetyRelearn(for domainID: String) {
        completedSafetyEducationIDs.remove(domainID)
        safetyRelearnToken &+= 1
    }

    private var completedSafetyEducationIDs: Set<String> {
        get {
            let ids = UserDefaults.standard.stringArray(forKey: "safetyEducationCompleted") ?? []
            return Set(ids)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "safetyEducationCompleted")
        }
    }

    private var logsURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("rail_logs_\(currentDomainID).json")
    }

    private var draftsURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("rail_drafts_\(currentDomainID).json")
    }

    init() {
        load()
    }

    // MARK: - 草稿

    func createDraft(from scan: ScannedTripData) -> TripLog {
        var draft = TripLog()
        draft.emuNumber = scan.emuNumber
        draft.carriage = scan.carriage
        draft.seat = scan.seat
        draft.isDraft = true
        drafts.append(draft)
        saveDrafts()
        return draft
    }

    func createEmptyDraft() -> TripLog {
        let draft = TripLog()
        drafts.append(draft)
        saveDrafts()
        return draft
    }

    func updateDraft(_ draft: TripLog) {
        if let idx = drafts.firstIndex(where: { $0.id == draft.id }) {
            drafts[idx] = draft
            saveDrafts()
        }
    }

    func deleteDraft(_ draft: TripLog) {
        drafts.removeAll { $0.id == draft.id }
        saveDrafts()
    }

    // MARK: - 正式日志

    func finalizeDraft(_ draft: TripLog) {
        var completed = draft
        completed.isDraft = false
        completed.createdAt = Date()
        completed.modifiedAt = Date()
        logs.insert(completed, at: 0)
        drafts.removeAll { $0.id == draft.id }
        saveLogs()
        saveDrafts()
        checkFirstTripAchievement()
        Task { await cloudSync.pushOne(completed) }
    }

    func addLog(_ log: TripLog) {
        var newLog = log
        newLog.isDraft = false
        newLog.modifiedAt = Date()
        logs.insert(newLog, at: 0)
        saveLogs()
        checkFirstTripAchievement()
        Task { await cloudSync.pushOne(newLog) }
    }

    private func checkFirstTripAchievement() {
        let count = logs.filter { !$0.isDraft }.count
        if count == 1 {
            AchievementService.shared.reportAchievement(id: "first_trip", percentComplete: 100)
        }
    }

    func updateLog(_ log: TripLog) {
        var updated = log
        updated.modifiedAt = Date()
        updated.walletPassAddedAt = nil
        if let idx = logs.firstIndex(where: { $0.id == log.id }) {
            logs[idx] = updated
            saveLogs()
            Task { await cloudSync.pushOne(updated) }
        }
    }

    func deleteLog(_ log: TripLog) {
        let id = log.id
        logs.removeAll { $0.id == id }
        saveLogs()
        Task { await cloudSync.deleteOne(id) }
    }

    // MARK: - Persistence

    private func load() {
        do {
            if let data = try? Data(contentsOf: logsURL) {
                logs = try JSONDecoder().decode([TripLog].self, from: data)
            }
            if let data = try? Data(contentsOf: draftsURL) {
                drafts = try JSONDecoder().decode([TripLog].self, from: data)
            }
        } catch {
            print("DataStore load error: \(error)")
        }
        cleanExpiredDrafts()
    }

    private func saveLogs() {
        guard let data = try? JSONEncoder().encode(logs) else { return }
        try? data.write(to: logsURL, options: .atomic)
    }

    private func saveDrafts() {
        cleanExpiredDrafts()
        guard let data = try? JSONEncoder().encode(drafts) else { return }
        try? data.write(to: draftsURL, options: .atomic)
    }

    func cleanExpiredDrafts() {
        let deadline = Date().addingTimeInterval(-600)
        drafts.removeAll { $0.createdAt < deadline }
    }

    // MARK: - iCloud 同步

    func performSync() async {
        let merged = await cloudSync.sync(localLogs: logs)
        logs = merged
        saveLogs()
    }

    // MARK: - CSV 导出

    func exportCSV() -> URL {
        let headers = [
            "id", "车次", "动车组编号", "车厢", "座位",
            "始发站", "出发站", "到达站", "终到站",
            "始发时间", "出发时间", "到达时间", "终到时间",
            "运转里程(km)", "最高时速(km/h)", "担当路局", "担当段",
            "运转时长", "备注", "收藏", "记录时间", "在途验证", "草稿"
        ]

        let formatter = ISO8601DateFormatter()
        let dateFormatter: (Date?) -> String = { date in
            guard let d = date else { return "" }
            return formatter.string(from: d)
        }

        var lines = [headers.joined(separator: ",")]
        let nonDrafts = logs.filter { !$0.isDraft }

        for log in nonDrafts {
            let row = [
                log.id.uuidString,
                csvEscape(log.trainNumber),
                csvEscape(log.emuNumber),
                csvEscape(log.carriage),
                csvEscape(log.seat),
                csvEscape(log.originStation),
                csvEscape(log.departureStation),
                csvEscape(log.arrivalStation),
                csvEscape(log.destinationStation),
                dateFormatter(log.originTime),
                dateFormatter(log.departureTime),
                dateFormatter(log.arrivalTime),
                dateFormatter(log.destinationTime),
                csvEscape(log.mileage),
                csvEscape(log.maxSpeed),
                csvEscape(log.bureau),
                csvEscape(log.depot),
                csvEscape(log.durationFormatted),
                csvEscape(log.notes),
                log.isFavorite ? "是" : "" ,
                dateFormatter(log.createdAt),
                log.verifiedOnRailway.map { $0 ? "是" : "否" } ?? "",
                log.isDraft ? "是" : "否"
            ]
            lines.append(row.joined(separator: ","))
        }

        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RailLog_导出.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func csvEscape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return s
    }

    // MARK: - 数据更新

    func refreshBundleData() async {
        await bundleService.refreshAll()
    }
}
