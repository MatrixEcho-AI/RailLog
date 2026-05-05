import SwiftUI

struct LogDetailView: View {
    @Environment(DataStore.self) private var store
    @State var log: TripLog
    @State private var showEdit = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // 车次信息
            Section("列车信息") {
                DetailRow(label: "车次", value: log.trainNumber)
                DetailRow(label: "动车组", value: log.emuNumber)
                if !log.carriage.isEmpty || !log.seat.isEmpty {
                    DetailRow(label: "座位", value: "\(log.carriage)车 \(log.seat)")
                }
                DetailRow(label: "运转时长", value: log.durationFormatted)
            }

            // 站点信息
            Section("站点信息") {
                DetailRow(label: "始发站", value: log.originStation)
                if let t = log.originTime {
                    DetailRow(label: "始发时间", value: t.formatted(date: .omitted, time: .shortened))
                }
                DetailRow(label: "出发站", value: log.departureStation)
                if let t = log.departureTime {
                    DetailRow(label: "出发时间", value: t.formatted(date: .omitted, time: .shortened))
                }
                DetailRow(label: "到达站", value: log.arrivalStation)
                if let t = log.arrivalTime {
                    DetailRow(label: "到达时间", value: t.formatted(date: .omitted, time: .shortened))
                }
                DetailRow(label: "终到站", value: log.destinationStation)
                if let t = log.destinationTime {
                    DetailRow(label: "终到时间", value: t.formatted(date: .omitted, time: .shortened))
                }
            }

            // 运转详情
            Section("运转详情") {
                DetailRow(label: "运转里程", value: log.mileage.isEmpty ? "-" : "\(log.mileage) km")
                DetailRow(label: "最高时速", value: log.maxSpeed.isEmpty ? "-" : "\(log.maxSpeed) km/h")
                DetailRow(label: "担当路局", value: log.bureau)
                DetailRow(label: "担当段", value: log.depot)
            }

            // 操作
            Section {
                Button("编辑此日志") { showEdit = true }
                Button("删除此日志", role: .destructive) {
                    store.deleteLog(log)
                    dismiss()
                }
            }
        }
        .navigationTitle("运转详情")
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                TripEditView(existingLog: log)
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        if !value.isEmpty && value != "-" {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
            }
        }
    }
}

#Preview {
    NavigationStack {
        LogDetailView(log: TripLog(
            trainNumber: "G81",
            emuNumber: "CR400AF-2186",
            carriage: "04", seat: "05C",
            bureau: "北京局", depot: "北京动车段",
            departureStation: "北京南", arrivalStation: "上海虹桥"
        ))
        .environment(DataStore())
    }
}
