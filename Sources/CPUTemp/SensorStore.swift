import SwiftUI
import Combine

/// Holds the latest sensor snapshot and refreshes it on a timer.
final class SensorStore: ObservableObject {
    @Published private(set) var sensors: [Sensor] = []
    @Published private(set) var headline: Double? = nil
    @Published private(set) var lastUpdated: Date? = nil

    /// Refresh interval in seconds.
    let interval: TimeInterval = 2.0

    private var timer: Timer?

    /// Called after every refresh (used to update the menu bar title).
    var onUpdate: (() -> Void)?

    func start() {
        refresh()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        // Reading sensors is cheap but touches IOKit; do it off the main thread.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let sensors = SensorReader.readAll()
            let headline = SensorReader.headlineTemperature(from: sensors)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.sensors = sensors
                self.headline = headline
                self.lastUpdated = Date()
                self.onUpdate?()
            }
        }
    }

    /// Sensors grouped by category, preserving category sort order.
    var grouped: [(category: SensorCategory, sensors: [Sensor])] {
        let groups = Dictionary(grouping: sensors, by: \.category)
        return groups
            .map { (category: $0.key, sensors: $0.value) }
            .sorted { $0.category.sortIndex < $1.category.sortIndex }
    }
}
