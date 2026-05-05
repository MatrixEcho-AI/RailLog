import Foundation

struct Domain: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let icon: String
}

// MARK: - 安全教育

struct SafetyEducation: Codable, Equatable {
    let rules: [SafetyRule]
    let confirmationPhrase: String
}

struct SafetyRule: Codable, Equatable, Identifiable {
    var id: String { icon }
    let icon: String
    let title: String
    let description: String
}

extension Domain {
    var safetyEducation: SafetyEducation? {
        switch id {
        case "china":
            return SafetyEducation(
                rules: [
                    SafetyRule(
                        icon: "tram.fill",
                        title: "不得干扰铁路车辆和站台正常运行",
                        description: "严禁在站台追逐打闹、侵入安全线、向列车抛掷物品或擅自进入轨行区。候车时请在安全区域内等候，上下车时注意脚下间隙。"
                    ),
                    SafetyRule(
                        icon: "shield.checkered",
                        title: "不得违反铁路安全规定",
                        description: "遵守铁路安全管理条例，不得携带危险品进站乘车，不得损坏铁路设施设备，不得在禁烟区域吸烟或使用明火。"
                    ),
                    SafetyRule(
                        icon: "person.text.rectangle",
                        title: "不得违抗工作人员命令",
                        description: "服从铁路工作人员的安全指挥和引导，配合安全检查。遇到紧急情况时，保持冷静并按照工作人员的指示有序撤离。"
                    )
                ],
                confirmationPhrase: "铁路安全高于一切"
            )
        default:
            return nil
        }
    }
}

extension Domain {
    static let chinaRailway = Domain(id: "china", name: "中国铁路", icon: "tram.fill")

    static let all: [Domain] = [.chinaRailway]
}
