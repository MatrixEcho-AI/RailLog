import Foundation
import SwiftUI

@Observable
final class DataStore {
    private(set) var logs: [TripLog] = []
    private(set) var drafts: [TripLog] = []

    private let logsURL: URL
    private let draftsURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logsURL = docs.appendingPathComponent("rail_logs.json")
        draftsURL = docs.appendingPathComponent("rail_drafts.json")
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
    }

    private func saveLogs() {
        guard let data = try? JSONEncoder().encode(logs) else { return }
        try? data.write(to: logsURL, options: .atomic)
    }

    private func saveDrafts() {
        guard let data = try? JSONEncoder().encode(drafts) else { return }
        try? data.write(to: draftsURL, options: .atomic)
    }
}
