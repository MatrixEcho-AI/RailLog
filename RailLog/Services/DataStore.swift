import Foundation
import SwiftUI

@Observable
final class DataStore {
    private(set) var logs: [TripLog] = []
    private(set) var drafts: [TripLog] = []

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
        logs.insert(completed, at: 0)
        drafts.removeAll { $0.id == draft.id }
        saveLogs()
        saveDrafts()
    }

    func addLog(_ log: TripLog) {
        var newLog = log
        newLog.isDraft = false
        logs.insert(newLog, at: 0)
        saveLogs()
    }

    func updateLog(_ log: TripLog) {
        if let idx = logs.firstIndex(where: { $0.id == log.id }) {
            logs[idx] = log
            saveLogs()
        }
    }

    func deleteLog(_ log: TripLog) {
        logs.removeAll { $0.id == log.id }
        saveLogs()
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
}
