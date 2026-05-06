import Foundation

extension Date {
    var zhDateTime: String {
        formatted(Date.FormatStyle(date: .long, time: .shortened).locale(Locale(identifier: "zh_CN")))
    }

    var zhDate: String {
        formatted(Date.FormatStyle(date: .long, time: .omitted).locale(Locale(identifier: "zh_CN")))
    }

    var zhTime: String {
        formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale(identifier: "zh_CN")))
    }

    var zhRelative: String {
        formatted(Date.RelativeFormatStyle(presentation: .named).locale(Locale(identifier: "zh_CN")))
    }
}
