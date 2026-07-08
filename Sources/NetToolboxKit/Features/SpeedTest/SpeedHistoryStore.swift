import Foundation
import Observation

/// Persists recent speed-test results as JSON in `UserDefaults`, so throughput
/// can be trended over time. Keeps the most recent runs only.
@MainActor
@Observable
final class SpeedHistoryStore {
    struct Record: Codable, Identifiable, Equatable, Sendable {
        var id = UUID()
        var timestamp: Double
        var download: Double
        var upload: Double
        var latency: Double
        var jitter: Double

        var date: Date { Date(timeIntervalSince1970: timestamp) }
    }

    private(set) var records: [Record] = []
    private let key = "nettoolbox.speedhistory.v1"
    private let limit = 30

    init() {
        load()
        // Reload when iCloud sync pulls newer values into UserDefaults.
        NotificationCenter.default.addObserver(
            forName: .cloudSyncDidPull, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.load() }
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Record].self, from: data) {
            records = decoded
        }
    }

    func add(download: Double, upload: Double, latency: Double, jitter: Double) {
        let record = Record(
            timestamp: Date().timeIntervalSince1970,
            download: download,
            upload: upload,
            latency: latency,
            jitter: jitter
        )
        records.insert(record, at: 0)
        if records.count > limit { records.removeLast(records.count - limit) }
        save()
    }

    func clear() {
        records = []
        save()
    }

    /// Replaces all records (used when restoring a backup).
    func replaceAll(_ records: [Record]) {
        self.records = records
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
