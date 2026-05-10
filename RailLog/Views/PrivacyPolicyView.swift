import SwiftUI

struct PrivacyPolicyView: View {
    let isMandatory: Bool
    var onAgree: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("隐私政策")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 4)

                    Text("最近更新日期：2026年5月10日")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("深圳回响矩阵人工智能有限公司（以下简称\"我们\"）深知个人信息对您的重要性。本隐私政策旨在向您说明 RailLog（以下简称\"本应用\"）如何处理您的个人数据。")
                        .font(.body)

                    section(title: "一、我们收集的信息") {
                        Text("1. 行程数据")
                            .fontWeight(.medium)
                        Text("您在使用本应用记录铁路行程时，我们会收集您主动填写或通过扫码获取的以下信息：车次、动车组编号、车厢号、座位号、出发站、到达站、始发站、终到站、出发时间、到达时间、运转里程、最高时速、担当路局、担当段、备注信息。以上数据均存储在您的设备本地及您的个人 iCloud 账户中。")

                        Text("2. 位置信息")
                            .fontWeight(.medium)
                            .padding(.top, 8)
                        Text("在您主动触发\"在途验证\"功能时，本应用会获取您的 GPS 位置信息，用于确认您是否正在铁路线路上。位置数据仅在验证过程中临时使用，不会长期存储。在您使用地图功能时，本应用会通过 Apple 地图服务查询车站坐标和路线信息。")

                        Text("3. 相机")
                            .fontWeight(.medium)
                            .padding(.top, 8)
                        Text("在您使用扫码功能时，本应用会使用您的相机来识别 12306 铁路畅行码和动车组车体编号。相机数据仅在设备本地处理，不会上传至任何服务器。")
                    }

                    section(title: "二、数据存储方式") {
                        Text("1. 本地存储")
                            .fontWeight(.medium)
                        Text("您的行程数据以文件形式存储在您的设备本地。您的偏好设置（如 HDR 显示、显示偏好等）存储在设备本地。地图坐标缓存存储在设备本地。未完成的草稿记录将在 10 分钟后自动清理。")

                        Text("2. iCloud 同步")
                            .fontWeight(.medium)
                            .padding(.top, 8)
                        Text("如果您已登录 iCloud 账户，您的行程数据将通过 Apple CloudKit 服务在您的设备间进行同步。数据存储在您的个人 iCloud 私有数据库中，仅您本人可访问。您可以随时在系统设置的 iCloud 管理中关闭本应用的同步功能。本应用不会将您的行程数据上传至除 iCloud 以外的任何服务器。")
                    }

                    section(title: "三、使用的第三方服务") {
                        Text("本应用使用以下第三方服务来实现特定功能：")

                        Text("1. OpenStreetMap Overpass API")
                            .fontWeight(.medium)
                            .padding(.top, 8)
                        Text("用于在途验证功能中查询铁路线路数据。我们会向 overpass-api.de 发送您的当前 GPS 坐标以查询附近的铁路轨道。该服务由 OpenStreetMap 社区维护，我们不向其发送任何个人身份信息。")

                        Text("2. Apple 地图服务 (MKLocalSearch)")
                            .fontWeight(.medium)
                            .padding(.top, 8)
                        Text("用于查询车站地理坐标和搜索附近车站信息。地图服务由 Apple 提供，受 Apple 隐私政策约束。")

                        Text("3. Apple Game Center")
                            .fontWeight(.medium)
                            .padding(.top, 8)
                        Text("用于成就系统。认证和成就数据由 Apple 管理，我们仅通过 GameKit 框架上报成就进度。")

                        Text("4. 数据更新服务")
                            .fontWeight(.medium)
                            .padding(.top, 8)
                        Text("用于从本公司服务器获取车站列表、车型数据、铁路局信息等静态参考数据。该请求为单向数据获取，不包含您的任何个人信息或行程数据。")
                    }

                    section(title: "四、数据共享与披露") {
                        Text("我们不会将您的个人数据出售、交易或以其他方式转让给第三方用于营销目的。我们不会将您的行程数据上传至我们自己的服务器。您的所有行程数据仅存储在您的设备本地和您的个人 iCloud 账户中。")
                    }

                    section(title: "五、您的权利") {
                        Text("您可以通过以下方式管理您的数据：")
                        Text("• 导出：在设置页面使用\"导出 CSV\"功能，将您的行程数据导出为文件")
                        Text("• 删除：您可以在日志详情页删除单个行程记录")
                        Text("• 停止同步：您可以在系统设置中关闭本应用的 iCloud 同步")
                        Text("• 草稿自动清理：未完成的草稿记录将在 10 分钟后自动删除")
                    }

                    section(title: "六、儿童隐私") {
                        Text("本应用在 App Store 上的年龄分级为 4+，适合各年龄段用户使用。本应用不要求用户提供个人身份信息（如姓名、电子邮件地址、电话号码等），所有数据均为用户自主记录的铁路行程信息，且仅存储在用户设备本地及其个人 iCloud 账户中。如对本应用的数据处理方式有任何疑问，监护人可以随时通过下方提供的联系方式与我们沟通。")
                    }

                    section(title: "七、隐私政策更新") {
                        Text("我们可能会不时更新本隐私政策。更新后的隐私政策将在应用内展示，您需要重新同意后方可继续使用本应用。")
                    }

                    section(title: "八、联系我们") {
                        Text("如果您对本隐私政策有任何疑问，请通过以下方式联系我们：")
                        Text("邮箱：mikewu597@matrixecho.cn / i@hyp.ink")
                            .padding(.top, 4)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("粤ICP备2026018443号-4A")
                            .font(.caption)
                        Text("深圳回响矩阵人工智能有限公司")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .toolbar {
                if !isMandatory {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("完成") { dismiss() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isMandatory {
                    VStack(spacing: 12) {
                        Text("请阅读并同意隐私政策后使用本应用")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            onAgree?()
                        } label: {
                            Text("同意并继续")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                    .background(.regularMaterial)
                }
            }
        }
    }

    @ViewBuilder
    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
                .font(.body)
        }
    }
}

#Preview {
    PrivacyPolicyView(isMandatory: true) {}
}
