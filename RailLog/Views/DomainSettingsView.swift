import SwiftUI

struct DomainSettingsView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var refreshing = false
    @State private var exportURL: URL?
    @State private var showPrivacyPolicy = false

    private var syncStatusText: String {
        if store.cloudSync.syncInProgress {
            return "同步中…"
        }
        if let error = store.cloudSync.syncError {
            return "同步失败：\(error)"
        }
        if let last = store.cloudSync.lastSyncDate {
            return "上次同步：\(last.zhRelative)"
        }
        return "尚未同步"
    }

    private func timeString(_ date: Date?) -> String {
        if let t = date { return t.zhDate }
        return "未更新"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("主项", selection: Binding(
                        get: { store.preferTrainNumber },
                        set: { store.preferTrainNumber = $0 }
                    )) {
                        Text("车次").tag(true)
                        Text("动车组编号").tag(false)
                    }
                    Toggle("HDR 显示", isOn: Binding(
                        get: { store.hdrEnabled },
                        set: { store.hdrEnabled = $0 }
                    ))
                } header: {
                    Text(store.currentDomain.name)
                } footer: {
                    Text("在支持 HDR 的设备上使用高动态范围渲染，卡片背景更亮。")
                }

                // iCloud 同步 + 导出
                Section {
                    HStack {
                        Label("iCloud 同步", systemImage: "icloud")
                        Spacer()
                        if store.cloudSync.syncInProgress {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(syncStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await store.performSync() }
                    } label: {
                        Label("立即同步", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(store.cloudSync.syncInProgress)
                    Button {
                        exportURL = store.exportCSV()
                    } label: {
                        Label("导出 CSV", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                }

                // 安全教育
                Section {
                    Button {
                        store.triggerSafetyRelearn(for: store.currentDomainID)
                        dismiss()
                    } label: {
                        Label("重新学习安全教育", systemImage: "hand.raised.fill")
                    }
                }

                // 数据包
                Section {
                    VStack(spacing: 12) {
                        HStack {
                            Text("车站数据")
                                .font(.subheadline)
                            Text("\(store.stationCount) 个")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if refreshing {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Text(timeString(store.stationsUpdateTime))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Text("车型数据")
                                .font(.subheadline)
                            Text("\(store.modelCount) 种")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if refreshing {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Text(timeString(store.modelsUpdateTime))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Text("路局数据")
                                .font(.subheadline)
                            Text("\(store.branchCount) 局 · \(store.depotCount) 段")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if refreshing {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Text(timeString(store.branchesUpdateTime))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    Button {
                        refreshing = true
                        Task {
                            await store.refreshBundleData()
                            refreshing = false
                        }
                    } label: {
                        Label("刷新数据包", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(refreshing)
                } footer: {
                    Text("车站数据来自 [rail.re](https://rail.re)，车型数据来自 [china-emu.cn](https://www.china-emu.cn)，路局数据来自维基百科。")
                }

                // 意见和建议
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("意见和建议")
                            .font(.subheadline)
                        Link("mikewu597@matrixecho.cn", destination: URL(string: "mailto:mikewu597@matrixecho.cn")!)
                            .font(.caption)
                        Link("i@hyp.ink", destination: URL(string: "mailto:i@hyp.ink")!)
                            .font(.caption)
                        Text("隐私政策")
                            .font(.subheadline)
                            .padding(.top, 8)
                        Button {
                            showPrivacyPolicy = true
                        } label: {
                            Text("查看隐私政策")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                    }
                }

                // 法律与许可
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("本软件与中国国家铁路集团有限公司及其分支机构、各地方铁路公司不存在任何关联或隶属关系。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider()

                        Text("RailLog 以 MIT 许可证开源，欢迎参与贡献。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Link("GitHub 仓库", destination: URL(string: "https://github.com/MatrixEcho-AI/RailLog")!)
                            .font(.caption)
                        Link("查看许可证 (MIT)", destination: URL(string: "https://github.com/MatrixEcho-AI/RailLog/blob/main/LICENSE.md")!)
                            .font(.caption)
                    }
                }

                // 备案信息
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("粤ICP备2026018443号-4A")
                            .font(.caption)
                        Text("深圳回响矩阵人工智能有限公司")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("版本 1.0 · 域版本 \(BuildInfo.commitHash)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("域设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(item: $exportURL) { url in
                ActivityViewController(activityItems: [url])
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView(isMandatory: false)
            }
        }
    }
}

// MARK: - UIActivityViewController Wrapper

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    DomainSettingsView()
        .environment(DataStore())
}
