import UIKit

enum DeviceInfo {
    static var hardwareModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { partialResult, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            partialResult.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier
    }

    static var systemDescription: String {
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }

    static var primaryLanguage: String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.components(separatedBy: "-").first ?? preferred
    }

    static var regionCode: String {
        Locale.current.region?.identifier ?? "US"
    }
}
