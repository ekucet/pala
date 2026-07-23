//
//  PalaConsole.swift
//  Pala
//
//  In-app log store + public logging API for the Console tool.
//

#if canImport(UIKit)
import UIKit

/// Severity of a log entry.
public enum PalaLogLevel: Int, CaseIterable {
    case debug, info, warning, error

    var name: String {
        switch self {
        case .debug:   return "DEBUG"
        case .info:    return "INFO"
        case .warning: return "WARN"
        case .error:   return "ERROR"
        }
    }

    var color: UIColor {
        switch self {
        case .debug:   return .systemGray
        case .info:    return .systemBlue
        case .warning: return .systemOrange
        case .error:   return .systemRed
        }
    }
}

/// A single captured log line.
public struct PalaLog: Identifiable {
    public let id = UUID()
    public let date: Date
    public let level: PalaLogLevel
    public let category: String
    public let message: String
}

/// Thread-safe ring buffer of logs, observed by the console view.
@MainActor
final class PalaConsole {
    static let shared = PalaConsole()
    private init() {}

    private(set) var logs: [PalaLog] = []
    private let limit = 2000

    /// Called whenever a log is added (so the view can refresh).
    var onChange: (() -> Void)?

    func add(_ message: String, category: String, level: PalaLogLevel, date: Date) {
        let entry = PalaLog(date: date, level: level, category: category, message: message)
        logs.append(entry)
        if logs.count > limit { logs.removeFirst(logs.count - limit) }
        onChange?()
    }

    func clear() {
        logs.removeAll()
        onChange?()
    }

    /// Distinct categories seen so far (for the filter bar).
    var categories: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for log in logs where !seen.contains(log.category) {
            seen.insert(log.category)
            ordered.append(log.category)
        }
        return ordered.sorted()
    }

    /// A plain-text export of all logs.
    func exportText() -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        return logs.map { log in
            "\(df.string(from: log.date)) [\(log.level.name)] [\(log.category)] \(log.message)"
        }.joined(separator: "\n")
    }
}
#endif
