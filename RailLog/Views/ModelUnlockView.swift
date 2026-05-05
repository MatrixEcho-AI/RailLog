import SwiftUI

struct ModelUnlockView: View {
    @Environment(DataStore.self) private var store
    let unlockedModelCodes: Set<String>
    let modelSeries: [ModelSeries]

    var body: some View {
        List {
            ForEach(modelSeries) { series in
                Section {
                    ForEach(series.models) { model in
                        HStack {
                            Image(systemName: unlockedModelCodes.contains(model.code) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(unlockedModelCodes.contains(model.code) ? .green : .secondary.opacity(0.3))
                                .font(.title3)
                            Text(model.name)
                                .font(.subheadline)
                            Spacer()
                            if unlockedModelCodes.contains(model.code) {
                                Text("\(modelUnlockCount(model.code)) 次")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    let unlocked = series.models.filter { unlockedModelCodes.contains($0.code) }.count
                    let total = series.models.count
                    Text("\(series.name)  \(unlocked)/\(total)")
                }
            }
        }
        .navigationTitle("车型统计")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func modelUnlockCount(_ code: String) -> Int {
        store.logs.filter { log in
            let emu = log.emuNumber
            guard !emu.isEmpty else { return false }
            let sortedModels = trainModels.sorted { $0.code.count > $1.code.count }
            for model in sortedModels where emu.hasPrefix(model.code) {
                return model.code == code
            }
            return false
        }.count
    }
}
