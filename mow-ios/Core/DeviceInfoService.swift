import UIKit

protocol DeviceInfoService {
    var model: String { get }
    var systemVersion: String { get }
    var name: String { get }
    var identifierForVendor: String { get }
}

struct LiveDeviceInfoService: DeviceInfoService {
    var model: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    var systemVersion: String {
        UIDevice.current.systemVersion
    }
    
    var name: String {
        UIDevice.current.name
    }
    
    var identifierForVendor: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Unavailable"
    }
}

struct MockDeviceInfoService: DeviceInfoService {
    let model: String
    let systemVersion: String
    let name: String
    let identifierForVendor: String
    
    init(
        model: String = "iPhone15,3",
        systemVersion: String = "17.0",
        name: String = "Preview iPhone",
        identifierForVendor: String = "00000000-0000-0000-0000-000000000000"
    ) {
        self.model = model
        self.systemVersion = systemVersion
        self.name = name
        self.identifierForVendor = identifierForVendor
    }
}
