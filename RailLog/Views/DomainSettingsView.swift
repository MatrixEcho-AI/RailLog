import SwiftUI

struct DomainSettingsView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var refreshing = false
    @State private var exportURL: URL?

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

    private var updateTimeString: String {
        if let t = store.dataUpdateTime {
            return t.zhDate
        }
        return "未更新"
    }

    var body: some View {
        NavigationStack {
            Form {
                // 主项
                Section {
                    Picker("主项", selection: Binding(
                        get: { store.preferTrainNumber },
                        set: { store.preferTrainNumber = $0 }
                    )) {
                        Text("车次").tag(true)
                        Text("动车组编号").tag(false)
                    }
                } header: {
                    Text(store.currentDomain.name)
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
                    HStack {
                        Text("数据包更新时间")
                            .font(.subheadline)
                        Spacer()
                        if refreshing {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Text(updateTimeString)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("铁路局 \(store.branchCount) 个 · 客运段 \(store.depotCount) 个")
                        Text("车站 \(store.stationCount) 个 · 车型 \(store.modelCount) 种")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    Text("数据包包含车站列表、车型字典、路局客运段等基础数据。车站数据来自 [rail.re](https://rail.re)，车型数据来自 [china-emu.cn](https://www.china-emu.cn)，路局客运段来自维基百科。")
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
