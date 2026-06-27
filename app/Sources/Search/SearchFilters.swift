import Foundation

// Lightweight, value-type filters applied to indexed frames before scoring.
// Cheap predicates (type/folder) run before the pricier date math.
struct SearchFilters: Equatable, Sendable {
    enum DateRange: String, CaseIterable, Sendable {
        case any, last7, last30, lastYear, custom

        var label: String {
            switch self {
            case .any: return "Any time"
            case .last7: return "Last 7 days"
            case .last30: return "Last 30 days"
            case .lastYear: return "Last year"
            case .custom: return "Custom…"
            }
        }

        // Does `date` fall within this range? `start`/`end` are only consulted for `.custom`.
        func contains(_ date: Date, start: Date?, end: Date?) -> Bool {
            switch self {
            case .any:
                return true
            case .last7:
                return date >= Date.now.addingTimeInterval(-7 * 86_400)
            case .last30:
                return date >= Date.now.addingTimeInterval(-30 * 86_400)
            case .lastYear:
                return date >= Date.now.addingTimeInterval(-365 * 86_400)
            case .custom:
                return date >= (start ?? .distantPast) && date <= (end ?? .distantFuture)
            }
        }
    }

    enum DurationBucket: String, CaseIterable, Sendable {
        case under1, oneToFive, fiveToThirty, overThirty

        var label: String {
            switch self {
            case .under1: return "< 1 min"
            case .oneToFive: return "1–5 min"
            case .fiveToThirty: return "5–30 min"
            case .overThirty: return "30 min +"
            }
        }

        func contains(_ seconds: Double) -> Bool {
            switch self {
            case .under1: return seconds < 60
            case .oneToFive: return seconds >= 60 && seconds < 300
            case .fiveToThirty: return seconds >= 300 && seconds < 1800
            case .overThirty: return seconds >= 1800
            }
        }
    }

    var dateRange: DateRange = .any
    var customStart: Date? = nil
    var customEnd: Date? = nil
    var durations: Set<DurationBucket> = []   // empty = any
    var folders: Set<String> = []             // standardized parent-folder paths; empty = all
    var fileTypes: Set<String> = []           // lowercased extensions; empty = all

    var isActive: Bool {
        dateRange != .any || !durations.isEmpty || !folders.isEmpty || !fileTypes.isEmpty
    }

    func matches(_ f: IndexedFrame) -> Bool {
        if !fileTypes.isEmpty && !fileTypes.contains(f.videoURL.pathExtension.lowercased()) {
            return false
        }
        if !folders.isEmpty
            && !folders.contains(f.videoURL.deletingLastPathComponent().standardizedFileURL.path) {
            return false
        }
        if !durations.isEmpty && !durations.contains(where: { $0.contains(f.videoDuration) }) {
            return false
        }
        if dateRange != .any {
            guard let modified = f.videoModified,
                  dateRange.contains(modified, start: customStart, end: customEnd) else {
                return false
            }
        }
        return true
    }
}
