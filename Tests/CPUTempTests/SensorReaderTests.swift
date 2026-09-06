import XCTest
@testable import CPUTemp

final class SensorReaderTests: XCTestCase {
    func testMissingCPUDoesNotUseGPUOrBattery() {
        let sensors = [
            Sensor(name: "GPU", value: 85, category: .gpu),
            Sensor(name: "Battery", value: 35, category: .battery),
        ]
        XCTAssertNil(SensorReader.headlineTemperature(from: sensors))
    }

    func testHighestCPUReadingIgnoresHotterGPU() {
        let sensors = [
            Sensor(name: "CPU 1", value: 45, category: .cpu),
            Sensor(name: "CPU 2", value: 62, category: .cpu),
            Sensor(name: "GPU", value: 90, category: .gpu),
        ]
        XCTAssertEqual(SensorReader.headlineTemperature(from: sensors), 62)
    }

    func testInvalidCPUReadingsDoNotFallBackToOtherSensors() {
        let sensors = [Double.nan, .infinity, -1, 0, 131].map {
            Sensor(name: "CPU", value: $0, category: .cpu)
        } + [Sensor(name: "Battery", value: 35, category: .battery)]
        XCTAssertNil(SensorReader.headlineTemperature(from: sensors))
    }

    func testEmptyListHasNoTemperature() {
        XCTAssertNil(SensorReader.headlineTemperature(from: []))
    }
}
