import SwiftUI

/// 车票统计：统计车票花费。人民币与积分合并显示占比（100 积分 = 1 元），
/// 单条堆叠条形图直观呈现两种支付方式的花费比例。
struct TicketStatsView: View {
    /// 人民币合计（元）
    let rmbTotal: Double
    /// 积分合计（分）
    let pointsTotal: Double

    /// 积分折合成元
    private var pointsYuan: Double { pointsTotal / 100 }
    private var totalYuan: Double { rmbTotal + pointsYuan }
    private var rmbFraction: Double { totalYuan > 0 ? rmbTotal / totalYuan : 0 }

    var body: some View {
        List {
            if totalYuan <= 0 {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "ticket")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("暂无车票花费记录")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 24)
                        Spacer()
                    }
                }
            } else {
                Section {
                    HStack {
                        Label("折合总花费", systemImage: "yensign.circle")
                        Spacer()
                        Text("¥\(Self.yuanText(totalYuan))")
                            .font(.headline)
                    }

                    // 堆叠条形图：人民币 vs 积分（折合后）占比
                    VStack(alignment: .leading, spacing: 10) {
                        GeometryReader { geo in
                            let total = geo.size.width
                            // 非零分段至少 8pt 宽，保证占比极小时仍可见
                            let rmbWidth = rmbTotal > 0 ? max(8, total * rmbFraction) : 0
                            HStack(spacing: 0) {
                                if rmbTotal > 0 {
                                    Rectangle()
                                        .fill(.blue.gradient)
                                        .frame(width: rmbWidth)
                                }
                                if pointsTotal > 0 {
                                    Rectangle()
                                        .fill(.orange.gradient)
                                        .frame(width: max(0, total - rmbWidth))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                        .frame(height: 18)

                        // 图例
                        if rmbTotal > 0 {
                            legendRow(
                                color: .blue,
                                title: "人民币",
                                value: "¥\(Self.yuanText(rmbTotal))",
                                percent: percentText(rmbTotal / totalYuan)
                            )
                        }
                        if pointsTotal > 0 {
                            legendRow(
                                color: .orange,
                                title: "积分",
                                value: "\(Self.pointsText(pointsTotal)) 积分 ≈ ¥\(Self.yuanText(pointsYuan))",
                                percent: percentText(pointsYuan / totalYuan)
                            )
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("总览")
                } footer: {
                    Text("积分按 100 积分 = 1 元折合人民币计算。")
                }
            }
        }
        .navigationTitle("车票统计")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legendRow(color: Color, title: String, value: String, percent: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
            Text(percent)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private func percentText(_ fraction: Double) -> String {
        String(format: "%.1f%%", fraction * 100)
    }

    // MARK: - 格式化（AboutView 入口行共用）

    /// 金额文本：整数不带小数，否则保留 1~2 位
    static func yuanText(_ v: Double) -> String {
        if v.truncatingRemainder(dividingBy: 1) == 0 { return String(format: "%.0f", v) }
        let one = String(format: "%.1f", v)
        if Double(one) == v { return one }
        return String(format: "%.2f", v)
    }

    /// 积分文本：整数不带小数
    static func pointsText(_ v: Double) -> String {
        if v.truncatingRemainder(dividingBy: 1) == 0 { return String(format: "%.0f", v) }
        return String(format: "%.1f", v)
    }
}

#Preview {
    NavigationStack {
        TicketStatsView(rmbTotal: 5453.5, pointsTotal: 8850)
    }
}
