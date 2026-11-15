import Foundation

/// 0.2.3까지 Clocky는 앱 샌드박스 안에서 돌아, 설정·알람·캘린더 캐시·내 소리 파일이
/// ~/Library/Containers/com.eddieee.Clocky에 있었다. 샌드박스를 끈 첫 실행에서 한 번,
/// 설정을 읽기 전에 그것들을 일반 위치(~/Library/Preferences, ~/Library/Application Support/Clocky)로 옮긴다.
/// 컨테이너는 지우지 않고 그대로 둔다(되돌릴 때를 위한 백업).
enum SandboxMigration {
    static let doneKey = "migratedFromSandbox"

    struct Paths {
        var containerPreferences: URL
        var containerSupport: URL
        var support: URL
        /// 덮어쓰기 전의 일반 위치 설정을 남겨 둘 곳.
        var previousPreferencesBackup: URL

        static func live(bundleID: String) -> Paths {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let data = home.appendingPathComponent("Library/Containers/\(bundleID)/Data/Library")
            let support = home.appendingPathComponent("Library/Application Support/Clocky", isDirectory: true)
            return Paths(containerPreferences: data.appendingPathComponent("Preferences/\(bundleID).plist"),
                         containerSupport: data.appendingPathComponent("Application Support/Clocky", isDirectory: true),
                         support: support,
                         previousPreferencesBackup: support.appendingPathComponent("Preferences before 0.3.plist"))
        }
    }

    /// 샌드박스 밖에서, 아직 옮긴 적이 없고, 컨테이너에 설정이 있으면 옮긴다. 옮겼으면 true.
    @discardableResult
    static func runIfNeeded(defaults: UserDefaults = .standard, domain: String? = Bundle.main.bundleIdentifier,
                            paths: Paths? = nil, sandboxed: Bool = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil) -> Bool {
        guard !sandboxed, let domain, !defaults.bool(forKey: doneKey) else { return false }
        let paths = paths ?? .live(bundleID: domain)
        let manager = FileManager.default
        guard manager.fileExists(atPath: paths.containerPreferences.path) else {
            // 컨테이너가 없으면(처음 설치) 옮길 것이 없다. 다음부터는 보지 않는다.
            defaults.set(true, forKey: doneKey)
            return false
        }
        // 있는데 읽지 못하면(macOS가 막는 등) 끝난 것으로 치지 않고 다음 실행에 다시 해 본다.
        guard let saved = NSDictionary(contentsOf: paths.containerPreferences) as? [String: Any] else {
            NSLog("Clocky: 샌드박스 컨테이너의 설정을 읽지 못해 다음 실행에 다시 옮겨 봅니다.")
            return false
        }

        // 샌드박스 전(0.1)에 쓰던 설정이 일반 위치에 남아 있으면 덮어쓰기 전에 남겨 둔다.
        if let previous = defaults.persistentDomain(forName: domain), !previous.isEmpty {
            try? manager.createDirectory(at: paths.support, withIntermediateDirectories: true)
            (previous as NSDictionary).write(to: paths.previousPreferencesBackup, atomically: true)
        }
        // 컨테이너의 설정이 지금 쓰던 것이므로 통째로 바꾼다.
        var values = saved
        values[doneKey] = true
        defaults.setPersistentDomain(values, forName: domain)

        // 캘린더 캐시와 내 소리 파일. 같은 이름이 이미 있으면 그대로 둔다.
        if let items = try? manager.contentsOfDirectory(at: paths.containerSupport, includingPropertiesForKeys: nil) {
            try? manager.createDirectory(at: paths.support, withIntermediateDirectories: true)
            for item in items {
                let target = paths.support.appendingPathComponent(item.lastPathComponent)
                if !manager.fileExists(atPath: target.path) { try? manager.copyItem(at: item, to: target) }
            }
        }
        return true
    }
}
