import UIKit

protocol DeviceInfoService {
    var deviceArchitecture: String { get }
    var systemVersion: String { get }
    var modelName: String { get }
    var identifierForVendor: String { get }
}

struct LiveDeviceInfoService: DeviceInfoService {
    let deviceArchitecture: String
    
    init() {
        self.deviceArchitecture = Self.deviceArchitecture()
    }
    
    var systemVersion: String {
        UIDevice.current.systemVersion
    }
    
    var modelName: String {
        UIDevice.current.name
    }
    
    var identifierForVendor: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Unavailable"
    }
    
    private static func deviceArchitecture() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }

        return identifier
    }
}

struct MockDeviceInfoService: DeviceInfoService {
    let deviceArchitecture: String
    let systemVersion: String
    let modelName: String
    let identifierForVendor: String
    
    init(
        deviceArchitecture: String = "arm64",
        systemVersion: String = "17.0",
        modelName: String = "iPhone15,3",
        identifierForVendor: String = "00000000-0000-0000-0000-000000000000"
    ) {
        self.deviceArchitecture = deviceArchitecture
        self.systemVersion = systemVersion
        self.modelName = modelName
        self.identifierForVendor = identifierForVendor
    }
}
