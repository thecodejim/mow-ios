import Foundation

struct AppEnvironment {
    enum Name: String {
        case localDev = "local-dev"
        case stage
        case prod

        var displayName: String {
            switch self {
            case .localDev: "Local Dev"
            case .stage: "Stage"
            case .prod: "Prod"
            }
        }

        var badgeText: String {
            rawValue.uppercased()
        }
    }

    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warn = "WARN"
        case error = "ERROR"

        static let fallback: LogLevel = .info
    }

    struct FeatureFlags {
        let useMockData: Bool
    }

    let name: Name
    let apiBaseURL: URL
    let docsURL: URL
    let portalURL: URL
    let telemetryURL: URL
    let healthCheckToken: String
    let featureFlags: FeatureFlags
    let logLevel: LogLevel
    let appVersion: String
    let buildNumber: String
    let bundleIdentifier: String

    static let current = AppEnvironment()

    init(bundle: Bundle = .main) {
        let info = Info(bundle: bundle)
        let nameRaw = info.string(.environmentName, fallback: Name.localDev.rawValue)
        name = Name(rawValue: nameRaw) ?? .localDev
        apiBaseURL = info.url(.apiBaseURL)
        docsURL = info.url(.docsURL)
        portalURL = info.url(.portalURL)
        telemetryURL = info.url(.telemetryURL)
        healthCheckToken = info.string(.healthCheckToken, fallback: "missing-token")
        featureFlags = FeatureFlags(useMockData: info.bool(.useMockData))
        let resolvedLevel = info.string(.logLevel, fallback: LogLevel.fallback.rawValue)
        logLevel = LogLevel(rawValue: resolvedLevel.uppercased()) ?? .fallback
        
        appVersion = info.string(.version, fallback: "Unknown")
        buildNumber = info.string(.build, fallback: "Unknown")
        bundleIdentifier = bundle.bundleIdentifier ?? "Unknown"
    }
}

private extension AppEnvironment {
    struct Info {
        enum Key: String {
            case environmentName = "MOWEnvironmentName"
            case apiBaseURL = "MOWAPIBaseURL"
            case docsURL = "MOWDocsURL"
            case portalURL = "MOWPortalURL"
            case telemetryURL = "MOWTelemetryURL"
            case healthCheckToken = "MOWHealthCheckToken"
            case useMockData = "MOWUseMockData"
            case logLevel = "MOWLogLevel"
            case version = "CFBundleShortVersionString"
            case build = "CFBundleVersion"
        }

        private let bundle: Bundle

        init(bundle: Bundle) {
            self.bundle = bundle
        }

        func string(_ key: Key, fallback: String? = nil) -> String {
            if let raw = bundle.object(forInfoDictionaryKey: key.rawValue) as? String {
                return raw
            }
            if let fallback {
                return fallback
            }
            fatalError("Missing Info.plist value for \(key.rawValue)")
        }

        func bool(_ key: Key, fallback: Bool = false) -> Bool {
            guard let raw = bundle.object(forInfoDictionaryKey: key.rawValue) else {
                return fallback
            }
            if let boolValue = raw as? Bool {
                return boolValue
            }
            if let stringValue = raw as? String {
                return (stringValue as NSString).boolValue
            }
            return fallback
        }

        func url(_ key: Key, fallback: URL? = nil) -> URL {
            let stringValue = string(key, fallback: fallback?.absoluteString)
            guard let url = URL(string: stringValue) else {
                fatalError("Invalid URL for \(key.rawValue): \(stringValue)")
            }
            return url
        }
    }
}

extension AppEnvironment {
    init(
        name: Name,
        apiBaseURL: URL,
        docsURL: URL,
        portalURL: URL,
        telemetryURL: URL,
        healthCheckToken: String = "preview-token",
        featureFlags: FeatureFlags = .init(useMockData: true),
        logLevel: LogLevel = .debug,
        appVersion: String = "0.0.0",
        buildNumber: String = "0",
        bundleIdentifier: String = "com.example.mow.preview"
    ) {
        self.name = name
        self.apiBaseURL = apiBaseURL
        self.docsURL = docsURL
        self.portalURL = portalURL
        self.telemetryURL = telemetryURL
        self.healthCheckToken = healthCheckToken
        self.featureFlags = featureFlags
        self.logLevel = logLevel
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.bundleIdentifier = bundleIdentifier
    }
}

extension AppEnvironment {
    static let preview = AppEnvironment(
        name: .localDev,
        apiBaseURL: URL(string: "https://api.preview.example.com")!,
        docsURL: URL(string: "https://docs.preview.example.com")!,
        portalURL: URL(string: "https://portal.preview.example.com")!,
        telemetryURL: URL(string: "https://telemetry.preview.example.com")!,
        healthCheckToken: "preview-health-token",
        featureFlags: .init(useMockData: true),
        logLevel: .debug,
        appVersion: "0.1.0-preview",
        buildNumber: "1",
        bundleIdentifier: "com.example.mow.preview"
    )
}
