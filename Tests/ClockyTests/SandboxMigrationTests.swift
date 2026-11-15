import Foundation
import Testing
@testable import Clocky

@Suite struct SandboxMigrationTests {
    private func setUp() -> (UserDefaults, String, SandboxMigration.Paths, URL) {
        let domain = "clocky-migration-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(domain)
        let paths = SandboxMigration.Paths(
            containerPreferences: root.appendingPathComponent("Container/Preferences/\(domain).plist"),
            containerSupport: root.appendingPathComponent("Container/Application Support/Clocky"),
            support: root.appendingPathComponent("Application Support/Clocky"),
            previousPreferencesBackup: root.appendingPathComponent("Application Support/Clocky/backup.plist"))
        try? FileManager.default.createDirectory(at: paths.containerPreferences.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: paths.containerSupport.appendingPathComponent("Sounds"), withIntermediateDirectories: true)
        return (defaults, domain, paths, root)
    }

    @Test func 컨테이너의_설정과_파일을_옮긴다() throws {
        let (defaults, domain, paths, root) = setUp()
        defer { try? FileManager.default.removeItem(at: root); defaults.removePersistentDomain(forName: domain) }
        (["language": "en", "alarms": Data("[1]".utf8)] as NSDictionary).write(to: paths.containerPreferences, atomically: true)
        try Data("ding".utf8).write(to: paths.containerSupport.appendingPathComponent("Sounds/bell.aiff"))
        // 샌드박스 전 판의 낡은 설정이 일반 위치에 남아 있다.
        defaults.set("ko", forKey: "language"); defaults.set("old", forKey: "stale")

        #expect(SandboxMigration.runIfNeeded(defaults: defaults, domain: domain, paths: paths, sandboxed: false))
        #expect(defaults.string(forKey: "language") == "en")
        #expect(defaults.data(forKey: "alarms") == Data("[1]".utf8))
        #expect(defaults.object(forKey: "stale") == nil)
        #expect(defaults.bool(forKey: SandboxMigration.doneKey))
        #expect(FileManager.default.contents(atPath: paths.support.appendingPathComponent("Sounds/bell.aiff").path) == Data("ding".utf8))
        let backup = NSDictionary(contentsOf: paths.previousPreferencesBackup) as? [String: Any]
        #expect(backup?["stale"] as? String == "old")
        // 두 번째는 하지 않는다.
        defaults.set("ko", forKey: "language")
        #expect(!SandboxMigration.runIfNeeded(defaults: defaults, domain: domain, paths: paths, sandboxed: false))
        #expect(defaults.string(forKey: "language") == "ko")
    }

    @Test func 샌드박스_안이거나_컨테이너가_없으면_옮기지_않는다() {
        let (defaults, domain, paths, root) = setUp()
        defer { try? FileManager.default.removeItem(at: root); defaults.removePersistentDomain(forName: domain) }
        (["language": "en"] as NSDictionary).write(to: paths.containerPreferences, atomically: true)
        #expect(!SandboxMigration.runIfNeeded(defaults: defaults, domain: domain, paths: paths, sandboxed: true))
        #expect(defaults.string(forKey: "language") == nil)
        // 있는데 읽을 수 없으면 끝난 것으로 치지 않는다.
        try? Data("not a plist".utf8).write(to: paths.containerPreferences)
        #expect(!SandboxMigration.runIfNeeded(defaults: defaults, domain: domain, paths: paths, sandboxed: false))
        #expect(!defaults.bool(forKey: SandboxMigration.doneKey))
        try? FileManager.default.removeItem(at: paths.containerPreferences)
        #expect(!SandboxMigration.runIfNeeded(defaults: defaults, domain: domain, paths: paths, sandboxed: false))
        #expect(defaults.bool(forKey: SandboxMigration.doneKey))
    }
}
