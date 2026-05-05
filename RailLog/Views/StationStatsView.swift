import SwiftUI

struct StationStatsView: View {
    let stations: [(station: String, count: Int)]

    var body: some View {
        List {
            ForEach(stations.indices, id: \.self) { i in
                let item = stations[i]
                HStack {
                    Text("\(i + 1)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .leading)

                    Text(item.station)
                        .font(.subheadline)

                    Spacer()

                    Text("\(item.count) 次")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.1), in: .capsule)
                }
            }
        }
        .navigationTitle("车站统计")
        .navigationBarTitleDisplayMode(.inline)
    }
}
