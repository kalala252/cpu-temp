import Foundation
import SMCSensors

/// Reads temperature sensors via the SMCSensors C bridge.
enum SensorReader {

    /// Collects sensors during a single enumeration pass.
    private final class Collector {
        var sensors: [Sensor] = []
    }

    /// Plausible Celsius range. Readings outside this are treated as noise /
    /// unpopulated sensors and discarded.
    private static let validRange = 1.0 ... 130.0

    /// Reads every available temperature sensor. Returns them sorted by category.
    static func readAll() -> [Sensor] {
        let collector = Collector()

        let callback: smc_sensor_callback = { namePtr, value, ctx in
            guard let ctx = ctx, let namePtr = namePtr else { return }
            let collector = Unmanaged<Collector>.fromOpaque(ctx).takeUnretainedValue()
            let name = String(cString: namePtr)
            collector.sensors.append(
                Sensor(name: name, value: value, category: SensorCategory.classify(name))
            )
        }

        let ctx = Unmanaged.passUnretained(collector).toOpaque()
        smc_enumerate_temperature_sensors(callback, ctx)
        smc_enumerate_smc_sensors(callback, ctx)

        return collector.sensors
            .filter { validRange.contains($0.value) }
            .filter { !$0.name.lowercased().contains("tcal") }
            .sorted {
                if $0.category.sortIndex != $1.category.sortIndex {
                    return $0.category.sortIndex < $1.category.sortIndex
                }
                return $0.name < $1.name
            }
    }

    /// CPUに分類できるセンサーがなければ、ほかの部位の温度で代用しない。
    static func headlineTemperature(from sensors: [Sensor]) -> Double? {
        sensors.filter { $0.category == .cpu && validRange.contains($0.value) }
            .map(\.value).max()
    }
}
