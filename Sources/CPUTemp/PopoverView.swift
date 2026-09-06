import SwiftUI

// MARK: - Glass card modifier

private struct GlassCard<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(Color.white.opacity(0.5), in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.6), lineWidth: 0.5))
        }
    }
}

extension View {
    fileprivate func glassCard<S: Shape>(_ shape: S) -> some View {
        modifier(GlassCard(shape: shape))
    }
}

// MARK: - Popover root

struct PopoverView: View {
    @ObservedObject var store: SensorStore
    var onQuit: () -> Void

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer {
                content
            }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 10) {
            headerCard

            ScrollView(.vertical, showsIndicators: false) {
                sensorCards
            }
            .frame(maxHeight: 300)

            footerArea
        }
        .padding(14)
        .frame(width: 300)
        .background(Color.white.opacity(0.15))
        .environment(\.colorScheme, .light)
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CPU 温度")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                if let h = store.headline {
                    Text("\(Int(h.rounded()))℃")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(TempColor.color(for: h))
                } else {
                    Text("取得不可")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            TempRing(temp: store.headline)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Sensor cards

    private var sensorCards: some View {
        VStack(spacing: 8) {
            if store.sensors.isEmpty {
                Text("温度センサーを読み取れませんでした。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ForEach(store.grouped, id: \.category) { group in
                    CategoryCard(category: group.category, sensors: group.sensors)
                }
            }
        }
    }

    // MARK: - Footer

    private var footerArea: some View {
        Button(action: onQuit) {
            HStack(spacing: 6) {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .bold))
                Text("終了")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Color(red: 0.85, green: 0.22, blue: 0.22),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

// MARK: - Temperature ring

private struct TempRing: View {
    let temp: Double?

    private var fraction: Double {
        guard let t = temp else { return 0 }
        return min(max((t - 30) / 65, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    TempColor.color(for: temp ?? 0),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image(systemName: "thermometer.medium")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(TempColor.color(for: temp ?? 0))
        }
        .frame(width: 48, height: 48)
    }
}

// MARK: - Category card

private struct CategoryCard: View {
    let category: SensorCategory
    let sensors: [Sensor]
    @State private var expanded = false

    private var maxTemp: Double { sensors.map(\.value).max() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row (always visible)
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .frame(width: 12)

                    Text(category.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("\(sensors.count)")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.primary.opacity(0.07)))

                    Spacer(minLength: 4)

                    Circle()
                        .fill(TempColor.color(for: maxTemp))
                        .frame(width: 7, height: 7)

                    Text("最大 \(Int(maxTemp.rounded()))℃")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(TempColor.color(for: maxTemp))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Detail rows (expanded)
            if expanded {
                Divider().padding(.horizontal, 12).opacity(0.3)

                ForEach(sensors) { sensor in
                    HStack(spacing: 6) {
                        Text(sensor.name)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 4)
                        Text("\(sensor.value, specifier: "%.1f")℃")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(TempColor.color(for: sensor.value))
                    }
                    .padding(.horizontal, 12)
                    .padding(.leading, 18)
                    .padding(.vertical, 2.5)
                }
                .padding(.bottom, 6)
                .padding(.top, 2)
            }
        }
        .glassCard(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
