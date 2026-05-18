import Foundation

struct Timing {
    private let start = ContinuousClock.now

    var elapsedSeconds: Double {
        let duration = start.duration(to: ContinuousClock.now)
        return Double(duration.components.seconds)
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000_000
    }
}

enum ElapsedTimeFormatter {
    static func string(from seconds: Double) -> String {
        if seconds < 1 {
            return "\(Int((seconds * 1000).rounded())) ms"
        }

        return String(format: "%.1f s", seconds)
    }
}
