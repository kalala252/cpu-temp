import AppKit
import SwiftUI

/// Maps a temperature to a colour along a green → orange → red gradient.
/// Chosen to stay legible on a light ("white based") UI and on the menu bar.
enum TempColor {

    private struct Stop { let t: Double; let r: Double; let g: Double; let b: Double }

    private static let stops: [Stop] = [
        Stop(t: 35, r: 0.16, g: 0.65, b: 0.32),   // cool  – green
        Stop(t: 55, r: 0.55, g: 0.62, b: 0.12),   // warm  – olive/lime
        Stop(t: 70, r: 0.92, g: 0.55, b: 0.10),   // hot   – orange
        Stop(t: 85, r: 0.86, g: 0.16, b: 0.16)    // very hot – red
    ]

    /// Returns interpolated RGB (0...1) for a temperature.
    private static func rgb(for temp: Double) -> (Double, Double, Double) {
        guard let first = stops.first, let last = stops.last else { return (0, 0, 0) }
        if temp <= first.t { return (first.r, first.g, first.b) }
        if temp >= last.t { return (last.r, last.g, last.b) }

        for i in 0 ..< stops.count - 1 {
            let a = stops[i], b = stops[i + 1]
            if temp >= a.t && temp <= b.t {
                let f = (temp - a.t) / (b.t - a.t)
                return (a.r + (b.r - a.r) * f,
                        a.g + (b.g - a.g) * f,
                        a.b + (b.b - a.b) * f)
            }
        }
        return (last.r, last.g, last.b)
    }

    static func nsColor(for temp: Double) -> NSColor {
        let (r, g, b) = rgb(for: temp)
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }

    static func color(for temp: Double) -> Color {
        let (r, g, b) = rgb(for: temp)
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
