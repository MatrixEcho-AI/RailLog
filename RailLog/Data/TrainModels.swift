import Foundation

/// 国铁车型字典（从数据包加载，JSON 数据源自 china-emu.cn）
var trainModels: [TrainModel] {
    DataBundleService.shared.models
}
