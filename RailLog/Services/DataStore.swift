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
    var dataUpdateTime: Date? { bundleService.stationsUpdateDate }
    var stationCount: Int { bundleService.stationCount }
    var modelCount: Int { bundleService.modelCount }
    var branchCount: Int { bundleService.branchCount }
    var depotCount: Int { bundleService.depotCount }

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
        Task { await cloudSync.pushOne(completed) }
    }

    func addLog(_ log: TripLog) {
        var newLog = log
        newLog.isDraft = false
        newLog.modifiedAt = Date()
        logs.insert(newLog, at: 0)
        saveLogs()
        Task { await cloudSync.pushOne(newLog) }
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

    // MARK: - 数据更新

    func refreshBundleData() async {
        await bundleService.refreshAll()
    }
}
