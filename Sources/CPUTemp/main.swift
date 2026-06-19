import AppKit

// Debug helper: `CPUTEMP_DUMP=1 ./CPUTemp` prints all sensors and exits.
// Useful for verifying sensor access without launching the menu bar UI.
if ProcessInfo.processInfo.environment["CPUTEMP_DUMP"] != nil {
    let sensors = SensorReader.readAll()
    if sensors.isEmpty {
        print("No temperature sensors found.")
    } else {
        for s in sensors {
            print(String(format: "[%@] %@: %.1f℃", s.category.rawValue, s.name, s.value))
        }
        if let h = SensorReader.headlineTemperature(from: sensors) {
            print(String(format: "\nHeadline (menu bar): %.1f℃", h))
        }
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menu bar only — no Dock icon, no main window.
// CPUTEMP_REGULAR=1 forces a Dock icon (used only for UI verification).
if ProcessInfo.processInfo.environment["CPUTEMP_REGULAR"] != nil {
    app.setActivationPolicy(.regular)
} else {
    app.setActivationPolicy(.accessory)
}
app.run()
