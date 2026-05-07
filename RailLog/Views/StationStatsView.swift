import SwiftUI

struct StationStatsView: View {
    let stations: [(station: String, count: Int)]

    private var maxCount: Double {
        Double(stations.map(\.count).max() ?? 1)
    }

    private func rank(at i: Int) -> String {
        if i == 0 { return "\(i + 1)" }
        if stations[i].count == stations[i - 1].count {
            return rank(at: i - 1)
        }
        return "\(i + 1)"
    }

    var body: some View {
        List {
            ForEach(stations.indices, id: \.self) { i in
                let item = stations[i]
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(rank(at: i))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .leading)

                        Text(item.station)
                            .font(.subheadline)

                        Spacer()

                        Text("\(item.count) 次")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.blue.gradient)
                            .frame(width: max(4, geo.size.width * Double(item.count) / maxCount))
                    }
                    .frame(height: 6)
                }
            }
        }
        .navigationTitle("车站统计")
        .navigationBarTitleDisplayMode(.inline)
    }
}
