import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("软件信息") {
                    HStack {
                        Image(systemName: "tram.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                            .frame(width: 60, height: 60)
                            .background(.blue.opacity(0.1), in: .rect(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("RailLog 铁路运转日志")
                                .font(.headline)
                            Text("版本 1.0.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                }

                Section("功能说明") {
                    Label("扫描铁路畅行码，快速录入车次座位", systemImage: "qrcode.viewfinder")
                    Label("记录运转里程、时速、站点、时间", systemImage: "pencil.and.list.clipboard")
                    Label("按路局、车次、站点查询历史运转", systemImage: "magnifyingglass")
                    Label("自动计算运转时长", systemImage: "clock.arrow.2.circlepath")
                }

                Section("数据来源") {
                    Text("车型、路局、车站数据来源于国铁集团公开信息，后续将通过在线更新方式进行维护。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("关于开发者") {
                    Text("RailLog 由铁路爱好者社区维护开发，旨在为广大车迷提供专业、便捷的运转记录工具。\n\n如有问题或建议，欢迎反馈。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("关于")
        }
    }
}

#Preview {
    AboutView()
}
