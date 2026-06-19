import Foundation

/// One temperature reading from the system.
struct Sensor: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let value: Double
    let category: SensorCategory
}

/// Coarse grouping used to organise sensors in the popover.
enum SensorCategory: String, CaseIterable {
    case cpu = "CPU"
    case gpu = "GPU"
    case soc = "SoC / Neural"
    case battery = "バッテリー / 電源"
    case other = "その他"

    /// Display order in the popover.
    var sortIndex: Int {
        switch self {
        case .cpu: return 0
        case .gpu: return 1
        case .soc: return 2
        case .battery: return 3
        case .other: return 4
        }
    }

    /// Classify a raw sensor name into a category using keyword heuristics.
    /// Sensor names differ between Mac models, so matching is intentionally broad.
    static func classify(_ rawName: String) -> SensorCategory {
        let n = rawName.lowercased()

        func contains(_ keys: [String]) -> Bool { keys.contains { n.contains($0) } }

        if contains(["pmu"]) {
            return .battery
        }
        if contains(["gpu"]) {
            return .gpu
        }
        if contains(["cpu", "pacc", "eacc", "tdie", "core"]) {
            return .cpu
        }
        if contains(["soc", "ane", "neural", "isp", "pmgr", "die temp"]) {
            return .soc
        }
        if contains(["batt", "gas gauge", "charger", "nand", "usb"]) {
            return .battery
        }
        return .other
    }
}
