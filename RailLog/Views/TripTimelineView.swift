import SwiftUI

/// 行程时间轴：详情页"行程信息"栏的主体（日期头 + 站点节点 + 出发/到达之间的列车信息块）。
/// 详情页直接使用；教程页通过 revealCount 做逐段出现动画，复用同一份实现。
struct TripTimelineView: View {
    let log: TripLog
    /// 依次揭示的行数（教程动画用）；默认全部显示
    var revealCount: Int = .max
    var onSelectStation: (String) -> Void = { _ in }
    var onSelectTrain: () -> Void = {}
    var onSelectEMU: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                row
                    .opacity(i < revealCount ? 1 : 0)
                    .offset(y: i < revealCount ? 0 : 8)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - 行装配

    private var rows: [AnyView] {
        let points = timelinePoints
        var result: [AnyView] = []

        // 顶部初始日期（第一个有时间的节点）
        if let start = timelineStartDate {
            result.append(AnyView(
                Text(start.zhDate)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            ))
        }

        for (index, point) in points.enumerated() {
            // 轴分段着色：两端都是蓝点（非端点）的连接线用蓝色
            let topBlue = index > 0 && !points[index - 1].isTerminus && !point.isTerminus
            let bottomBlue = index < points.count - 1 && !points[index + 1].isTerminus && !point.isTerminus
            result.append(AnyView(nodeRow(
                point: point,
                dayOffset: dayOffset(for: point),
                isFirst: index == 0,
                isLast: index == points.count - 1,
                topLineBlue: topBlue,
                bottomLineBlue: bottomBlue
            )))
            // 列车信息插在"出发"节点之后（出发、到达之间）
            if point.role.contains("出发"), hasTrainInfo {
                result.append(AnyView(trainInfoRow))
            }
        }
        return result
    }

    // MARK: - 数据

    private struct TimelinePoint {
        let role: String      // 始发/出发/到达/终到（合并时为 始发、出发 / 到达、终到）
        let station: String
        let time: Date?
        /// 独立显示的始发/终到节点（未与出发/到达合并）——灰点、灰 badge
        let isTerminus: Bool
    }

    /// 按分钟精度比较两个时间（DatePicker 的值可能带不同的秒数）；同为 nil 视为相同
    private func sameMinute(_ a: Date?, _ b: Date?) -> Bool {
        guard let a, let b else { return a == b }
        let cal = Calendar.current
        let keys: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]
        return cal.dateComponents(keys, from: a) == cal.dateComponents(keys, from: b)
    }

    private var timelinePoints: [TimelinePoint] {
        // 始发与出发同站且同一时间 → 合并为"始发、出发"；到达与终到同理
        let mergeOrigin = !log.originStation.isEmpty
            && log.originStation == log.departureStation
            && sameMinute(log.originTime, log.departureTime)
        let mergeDestination = !log.destinationStation.isEmpty
            && log.destinationStation == log.arrivalStation
            && sameMinute(log.arrivalTime, log.destinationTime)

        var points: [TimelinePoint] = []
        if !log.originStation.isEmpty {
            points.append(TimelinePoint(
                role: mergeOrigin ? "始发、出发" : "始发",
                station: log.originStation,
                time: log.originTime,
                isTerminus: !mergeOrigin
            ))
        }
        if !mergeOrigin {
            points.append(TimelinePoint(role: "出发", station: log.departureStation, time: log.departureTime, isTerminus: false))
        }
        if !mergeDestination {
            points.append(TimelinePoint(role: "到达", station: log.arrivalStation, time: log.arrivalTime, isTerminus: false))
        }
        if !log.destinationStation.isEmpty {
            points.append(TimelinePoint(
                role: mergeDestination ? "到达、终到" : "终到",
                station: log.destinationStation,
                time: log.destinationTime,
                isTerminus: !mergeDestination
            ))
        }
        return points
    }

    /// 时间轴顶部的初始日期（第一个有时间的节点）
    private var timelineStartDate: Date? {
        timelinePoints.first { $0.time != nil }?.time
    }

    /// 节点相对初始日期的跨日偏移（0=当天，1=次日…）；无时间或早于起始日时为 0
    private func dayOffset(for point: TimelinePoint) -> Int {
        guard let t = point.time, let base = timelineStartDate else { return 0 }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: base), to: cal.startOfDay(for: t)).day ?? 0
        return max(days, 0)
    }

    // MARK: - 节点行

    private func nodeRow(point: TimelinePoint, dayOffset: Int, isFirst: Bool, isLast: Bool, topLineBlue: Bool, bottomLineBlue: Bool) -> some View {
        let grayLine = Color.secondary.opacity(0.45)
        return HStack(spacing: 12) {
            // 左侧轴：竖线贯通整行，圆点压在线上方（重叠绘制，避免相切处的抗锯齿缝隙）
            ZStack {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(isFirst ? Color.clear : (topLineBlue ? Color.accentColor : grayLine))
                        .frame(width: 4)
                    Rectangle()
                        .fill(isLast ? Color.clear : (bottomLineBlue ? Color.accentColor : grayLine))
                        .frame(width: 4)
                }
                Circle()
                    .fill(point.isTerminus ? Color.gray : Color.accentColor)
                    .frame(width: 13, height: 13)
            }
            .frame(width: 16)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(point.time?.zhTime ?? "--:--")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(point.time == nil ? .tertiary : .primary)
                if dayOffset > 0 {
                    Text("+\(dayOffset)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .baselineOffset(6)
                }
            }
            .frame(width: 72, alignment: .leading)

            Button {
                onSelectStation(point.station)
            } label: {
                HStack(spacing: 6) {
                    Text(point.station)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            point.isTerminus ? Color.gray.opacity(0.18) : Color.accentColor.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                    Text(point.role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(height: 46)
    }

    // MARK: - 列车信息块

    /// 出发 → 到达 区间内的列车信息块：左侧轴贯通（两端必是蓝点，固定蓝色），无圆点
    private var trainInfoRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 4)
                .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 8) {
                if !log.emuNumber.isEmpty {
                    Button(action: onSelectEMU) {
                        trainInfoLine(bold: true, value: log.emuNumber, navigable: true)
                    }
                    .buttonStyle(.plain)
                }
                if !log.trainNumber.isEmpty {
                    Button(action: onSelectTrain) {
                        trainInfoLine(icon: "tram.fill", value: log.trainNumber, navigable: true)
                    }
                    .buttonStyle(.plain)
                }
                if !log.carriage.isEmpty || !log.seat.isEmpty {
                    trainInfoLine(icon: "chair.lounge", weight: .bold, value: "\(log.carriage)车 \(log.seat)", navigable: false)
                }
                if !log.durationFormatted.isEmpty {
                    trainInfoLine(icon: "clock", weight: .bold, value: log.durationFormatted, navigable: false)
                }
            }
            .padding(.leading, 48) // 时间列右缘的 2/3 处
            .padding(.vertical, 4)

            Spacer()
        }
    }

    private var hasTrainInfo: Bool {
        !log.trainNumber.isEmpty || !log.emuNumber.isEmpty
            || !log.carriage.isEmpty || !log.seat.isEmpty
            || !log.durationFormatted.isEmpty
    }

    private func trainInfoLine(icon: String? = nil, weight: Font.Weight = .regular, bold: Bool = false, value: String, navigable: Bool) -> some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.callout.weight(weight))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }
            Text(value)
                .font(.callout)
                .fontWeight(bold ? .bold : .regular)
                .fontDesign(navigable ? .monospaced : .default)
            if navigable {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
