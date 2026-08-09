import Foundation

extension Date {
    var zhDateTime: String {
        formatted(Date.FormatStyle(date: .long, time: .shortened).locale(Locale(identifier: "zh_CN")))
    }

    var zhDate: String {
        formatted(Date.FormatStyle(date: .long, time: .omitted).locale(Locale(identifier: "zh_CN")))
    }

    /// 24 小时制、小时分钟均补零两位，如 "08:05"
    var zhTime: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "HH:mm"
        return df.string(from: self)
    }

    var zhRelative: String {
        formatted(Date.RelativeFormatStyle(presentation: .named).locale(Locale(identifier: "zh_CN")))
    }
}
