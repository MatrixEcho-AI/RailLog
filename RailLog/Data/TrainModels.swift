import Foundation

/// 国铁常见车型字典
let trainModels: [TrainModel] = [
    // MARK: - 复兴号系列 (CR 高速动车组)
    TrainModel(code: "CR400AF",  name: "CR400AF 复兴号",  category: .highSpeed),
    TrainModel(code: "CR400AF-B", name: "CR400AF-B 复兴号 (17辆编组)", category: .highSpeed),
    TrainModel(code: "CR400AF-S", name: "CR400AF-S 复兴号 (双层/提升型)", category: .highSpeed),
    TrainModel(code: "CR400BF",  name: "CR400BF 复兴号",  category: .highSpeed),
    TrainModel(code: "CR400BF-B", name: "CR400BF-B 复兴号 (17辆编组)", category: .highSpeed),
    TrainModel(code: "CR400BF-C", name: "CR400BF-C 复兴号 (智能型)", category: .highSpeed),
    TrainModel(code: "CR300AF",  name: "CR300AF 复兴号",  category: .highSpeed),
    TrainModel(code: "CR300BF",  name: "CR300BF 复兴号",  category: .highSpeed),
    TrainModel(code: "CR200J",   name: "CR200J 复兴号 (动集)", category: .emu),

    // MARK: - 和谐号系列 (CRH)
    TrainModel(code: "CRH1A", name: "CRH1A 和谐号", category: .highSpeed),
    TrainModel(code: "CRH1B", name: "CRH1B 和谐号", category: .highSpeed),
    TrainModel(code: "CRH1E", name: "CRH1E 和谐号 (卧铺)", category: .highSpeed),
    TrainModel(code: "CRH2A", name: "CRH2A 和谐号", category: .highSpeed),
    TrainModel(code: "CRH2B", name: "CRH2B 和谐号", category: .highSpeed),
    TrainModel(code: "CRH2C", name: "CRH2C 和谐号", category: .highSpeed),
    TrainModel(code: "CRH2E", name: "CRH2E 和谐号 (卧铺)", category: .highSpeed),
    TrainModel(code: "CRH3C", name: "CRH3C 和谐号", category: .highSpeed),
    TrainModel(code: "CRH5A", name: "CRH5A 和谐号", category: .highSpeed),
    TrainModel(code: "CRH5G", name: "CRH5G 和谐号 (高寒)", category: .highSpeed),
    TrainModel(code: "CRH6A", name: "CRH6A 和谐号", category: .intercity),
    TrainModel(code: "CRH6F", name: "CRH6F 和谐号", category: .intercity),
    TrainModel(code: "CRH380A", name: "CRH380A 和谐号", category: .highSpeed),
    TrainModel(code: "CRH380AL", name: "CRH380AL 和谐号 (16辆)", category: .highSpeed),
    TrainModel(code: "CRH380B", name: "CRH380B 和谐号", category: .highSpeed),
    TrainModel(code: "CRH380BL", name: "CRH380BL 和谐号 (16辆)", category: .highSpeed),
    TrainModel(code: "CRH380CL", name: "CRH380CL 和谐号", category: .highSpeed),
    TrainModel(code: "CRH380D", name: "CRH380D 和谐号", category: .highSpeed),

    // MARK: - 普速列车
    TrainModel(code: "25G", name: "25G 型客车", category: .conventional),
    TrainModel(code: "25K", name: "25K 型客车", category: .conventional),
    TrainModel(code: "25T", name: "25T 型客车", category: .conventional),
    TrainModel(code: "25B", name: "25B 型客车", category: .conventional),
    TrainModel(code: "BSP", name: "BSP 型客车", category: .conventional)
]
