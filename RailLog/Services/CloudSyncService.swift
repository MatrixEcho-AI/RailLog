import CloudKit
import Foundation
import SwiftUI

@Observable
final class CloudSyncService {
    static let shared = CloudSyncService()

    private let db = CKContainer(identifier: "iCloud.cn.matrixecho.raillog").privateCloudDatabase
    private(set) var syncInProgress = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: String?

    private let recordType = "TripLog"

    // MARK: - Account Status

    func checkAccountStatus() async -> Bool {
        do {
            let status = try await CKContainer(identifier: "iCloud.cn.matrixecho.raillog").accountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    // MARK: - Bidirectional Sync

    /// Performs bidirectional sync: pushes local-only logs to cloud,
    /// pulls cloud-only logs, resolves conflicts by `modifiedAt`.
    /// Returns the merged set of logs.
    func sync(localLogs: [TripLog]) async -> [TripLog] {
        guard !syncInProgress else { return localLogs }
        guard await checkAccountStatus() else { return localLogs }

        syncInProgress = true
        syncError = nil
        defer { syncInProgress = false }

        print("[CloudSync] sync started, local logs: \(localLogs.count), non-draft: \(localLogs.filter { !$0.isDraft }.count)")

        var merged = localLogs
        let localByID = Dictionary(uniqueKeysWithValues: localLogs.map { ($0.id, $0) })

        // Fetch all cloud records; schema may not exist yet
        let cloudRecords: [CKRecord]
        do {
            cloudRecords = try await fetchAll()
        } catch {
            print("[CloudSync] fetchAll threw: \(error.localizedDescription)")
            cloudRecords = []
        }

        var cloudByID: [UUID: CKRecord] = [:]

        for record in cloudRecords {
            let rawName = record.recordID.recordName
            guard let id = UUID(uuidString: rawName) else {
                print("[CloudSync] skip record: invalid UUID \(rawName)")
                continue
            }
            cloudByID[id] = record
        }

        print("[CloudSync] fetched \(cloudRecords.count) cloud records, \(cloudByID.count) valid")

        let localIDs = Set(localByID.keys)
        let cloudIDs = Set(cloudByID.keys)
        let localOnlyIDs = localIDs.subtracting(cloudIDs)
        let cloudOnlyIDs = cloudIDs.subtracting(localIDs)
        let commonIDs = localIDs.intersection(cloudIDs)

        print("[CloudSync] localOnly:\(localOnlyIDs.count) cloudOnly:\(cloudOnlyIDs.count) common:\(commonIDs.count)")

        // Push local-only logs
        for id in localOnlyIDs {
            guard let log = localByID[id] else { continue }
            if log.isDraft {
                print("[CloudSync] skip pushing draft: \(id)")
                continue
            }
            print("[CloudSync] pushing local-only log: \(log.trainNumber) \(id)")
            await pushOne(log)
        }

        // Pull cloud-only logs
        for id in cloudOnlyIDs {
            guard let record = cloudByID[id] else { continue }
            guard let log = tripLog(from: record) else {
                print("[CloudSync] tripLog(from:) failed for \(id)")
                continue
            }
            guard !log.isDraft else {
                print("[CloudSync] skip draft \(id)")
                continue
            }
            print("[CloudSync] pulled cloud-only log: \(log.trainNumber) \(id)")
            merged.append(log)
        }

        // Resolve conflicts — keep newest by modifiedAt
        for id in commonIDs {
            guard let localLog = localByID[id],
                  let cloudRecord = cloudByID[id],
                  let cloudLog = tripLog(from: cloudRecord) else { continue }

            if cloudLog.modifiedAt > localLog.modifiedAt {
                // Cloud is newer → update local
                if let idx = merged.firstIndex(where: { $0.id == id }) {
                    merged[idx] = cloudLog
                }
            } else if localLog.modifiedAt > cloudLog.modifiedAt {
                // Local is newer → push to cloud
                await pushOne(localLog)
            }
            // If equal timestamps, cloud wins (no action needed)
        }

        lastSyncDate = Date()
        return merged
    }

    /// Push a single log to CloudKit.
    func pushOne(_ log: TripLog) async {
        guard await checkAccountStatus() else {
            print("[CloudSync] pushOne skipped: iCloud unavailable")
            return
        }
        let record = ckRecord(from: log)
        do {
            let (saveResults, _) = try await db.modifyRecords(
                saving: [record], deleting: [],
                savePolicy: .allKeys,
                atomically: true
            )
            if let result = saveResults[record.recordID], case .failure(let error) = result {
                print("[CloudSync] pushOne error: \(error.localizedDescription)")
            } else {
                print("[CloudSync] pushed: \(log.id)")
            }
        } catch {
            print("[CloudSync] pushOne error: \(error.localizedDescription)")
        }
    }

    /// Delete a log from CloudKit.
    func deleteOne(_ logID: UUID) async {
        guard await checkAccountStatus() else { return }
        let recordID = CKRecord.ID(recordName: logID.uuidString)
        do {
            try await db.deleteRecord(withID: recordID)
        } catch {
            // Record may already be deleted; ignore
        }
    }

    // MARK: - CloudKit Fetch

    private func fetchAll() async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "modifiedAt > %@", Date.distantPast as NSDate))

        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor? = nil

        repeat {
            let matchResults: [(CKRecord.ID, Result<CKRecord, Error>)]
            let nextCursor: CKQueryOperation.Cursor?
            if let cursor = cursor {
                (matchResults, nextCursor) = try await db.records(continuingMatchFrom: cursor)
            } else {
                (matchResults, nextCursor) = try await db.records(matching: query)
            }
            for (recordID, result) in matchResults {
                switch result {
                case .success(let record):
                    allRecords.append(record)
                case .failure(let error):
                    print("[CloudSync] fetch error for \(recordID.recordName): \(error.localizedDescription)")
                }
            }
            cursor = nextCursor
        } while cursor != nil

        print("[CloudSync] fetchAll returned \(allRecords.count) records")
        return allRecords
    }

    // MARK: - CKRecord ↔ TripLog

    private func ckRecord(from log: TripLog) -> CKRecord {
        let recordID = CKRecord.ID(recordName: log.id.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["trainNumber"] = log.trainNumber
        record["emuNumber"] = log.emuNumber
        record["carriage"] = log.carriage
        record["seat"] = log.seat
        record["mileage"] = log.mileage
        record["maxSpeed"] = log.maxSpeed
        record["bureau"] = log.bureau
        record["depot"] = log.depot
        record["originStation"] = log.originStation
        record["departureStation"] = log.departureStation
        record["arrivalStation"] = log.arrivalStation
        record["destinationStation"] = log.destinationStation
        record["originTime"] = log.originTime
        record["departureTime"] = log.departureTime
        record["arrivalTime"] = log.arrivalTime
        record["destinationTime"] = log.destinationTime
        record["verifiedOnRailway"] = log.verifiedOnRailway.map { $0 ? 1 : 0 }
        record["isDraft"] = log.isDraft ? 1 : 0
        record["isFavorite"] = log.isFavorite ? 1 : 0
        record["notes"] = log.notes
        record["createdAt"] = log.createdAt
        record["modifiedAt"] = log.modifiedAt
        return record
    }

    private func tripLog(from record: CKRecord) -> TripLog? {
        guard let createdAt = record["createdAt"] as? Date,
              let modifiedAt = record["modifiedAt"] as? Date else {
            print("[CloudSync] tripLog missing dates: createdAt=\(record["createdAt"] ?? "nil"), modifiedAt=\(record["modifiedAt"] ?? "nil")")
            return nil
        }

        var log = TripLog()
        log.id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        log.isDraft = (record["isDraft"] as? Int64) == 1
        log.trainNumber = record["trainNumber"] as? String ?? ""
        log.emuNumber = record["emuNumber"] as? String ?? ""
        log.carriage = record["carriage"] as? String ?? ""
        log.seat = record["seat"] as? String ?? ""
        log.mileage = record["mileage"] as? String ?? ""
        log.maxSpeed = record["maxSpeed"] as? String ?? ""
        log.bureau = record["bureau"] as? String ?? ""
        log.depot = record["depot"] as? String ?? ""
        log.originStation = record["originStation"] as? String ?? ""
        log.departureStation = record["departureStation"] as? String ?? ""
        log.arrivalStation = record["arrivalStation"] as? String ?? ""
        log.destinationStation = record["destinationStation"] as? String ?? ""
        log.originTime = record["originTime"] as? Date
        log.departureTime = record["departureTime"] as? Date
        log.arrivalTime = record["arrivalTime"] as? Date
        log.destinationTime = record["destinationTime"] as? Date
        log.createdAt = createdAt
        log.modifiedAt = modifiedAt
        log.isFavorite = (record["isFavorite"] as? Int64) == 1
        log.notes = record["notes"] as? String ?? ""

        if let verifiedInt = record["verifiedOnRailway"] as? Int64 {
            log.verifiedOnRailway = verifiedInt == 1
        } else {
            log.verifiedOnRailway = nil
        }

        return log
    }
}
