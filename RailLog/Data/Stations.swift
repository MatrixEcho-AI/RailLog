import Foundation

/// 国铁车站字典（从数据包加载，JSON 数据源自 12306）
var railwayStations: [RailwayStation] {
    DataBundleService.shared.stations
}
