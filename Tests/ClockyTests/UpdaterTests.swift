import CryptoKit
import Foundation
import Testing
@testable import Clocky

@Suite struct UpdaterTests {
    /// 공통 업데이트(mac-app/shared/AppUpdater.swift)의 자체 점검: 버전 비교, 릴리스 읽기, 받는 주소, 서명.
    @Test func 공통_업데이트_점검() {
        let failures = AppUpdater.selfTest(appName: "Clocky", publicKey: AppUpdater.appPublicKey, format: AppUpdater.appSignatureFormat)
        #expect(failures.isEmpty, "\(failures)")
    }

    @Test func 버전_비교() {
        #expect(AppVersion.isNewer("0.2.1", than: "0.2.0"))
        #expect(AppVersion.isNewer("0.10.0", than: "0.9.9"))
        #expect(AppVersion.isNewer("1.0", than: "0.99.99"))
        #expect(!AppVersion.isNewer("0.2", than: "0.2.0"))
        #expect(!AppVersion.isNewer("0.2.0", than: "0.2.0"))
        #expect(!AppVersion.isNewer("0.1.9", than: "0.2.0"))
        #expect(AppVersion.isNewer("0.3.0-beta", than: "0.2.0"))
        #expect(AppVersion.normalized("v0.2.1") == "0.2.1")
        #expect(AppVersion.normalized("release") == nil)
    }

    /// 이 Mac에 릴리스 서명 키가 있으면, 서명 스크립트로 서명한 파일을 앱에 넣은 공개키로 검증해 본다.
    /// 스크립트와 앱의 서명 형식, 그리고 앱의 공개키가 비밀키와 짝인지 확인한다.
    @Test(.enabled(if: FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.clocky-release/signing-key")))
    func 서명_스크립트와_앱의_공개키가_맞다() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("clocky-sign-\(UUID().uuidString).dmg")
        let data = Data((0..<1000).map { UInt8($0 % 7) })
        try data.write(to: file)
        defer { try? FileManager.default.removeItem(at: file); try? FileManager.default.removeItem(atPath: file.path + ".sig") }
        let script = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("scripts/release-key.swift")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = [script.path, "sign", file.path, "9.9.9"]
        process.standardOutput = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        let signature = try String(contentsOfFile: file.path + ".sig", encoding: .utf8)
        let sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        #expect(AppUpdater.isSigned(dmg: data, sha256: sha, version: "9.9.9", signature: Data(signature.utf8),
                                    publicKey: AppUpdater.appPublicKey, format: AppUpdater.appSignatureFormat))
    }

}

@Suite struct InstallLocationTests {
    @Test func dmg와_임시_위치에서_실행하면_알린다() {
        #expect(InstallLocation.needsMove("/Volumes/Clocky/Clocky.app"))
        #expect(InstallLocation.needsMove("/private/var/folders/ab/xyz/T/AppTranslocation/1234/d/Clocky.app"))
        #expect(!InstallLocation.needsMove("/Applications/Clocky.app"))
        #expect(!InstallLocation.needsMove("/Users/me/Applications/Clocky.app"))
    }
}

@Suite struct AfterUpdateTests {
    private func fresh() -> UserDefaults {
        let name = "clocky-after-update-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func 새_버전으로_처음_켜면_받은_dmg를_정리한다() throws {
        let defaults = fresh()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("Clocky \(UUID().uuidString).dmg")
        try Data([1, 2, 3]).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        defaults.set("0.2.1", forKey: UpdateCleanup.lastRunKey)
        defaults.set(file.path, forKey: UpdateCleanup.downloadedKey)
        var asked: URL?
        let cleaned = UpdateCleanup.cleanUpAfterUpdate(defaults: defaults, current: "0.2.2") { asked = $0; return true } discard: { try? FileManager.default.removeItem(at: $0) }
        #expect(asked == file && cleaned == file)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(defaults.string(forKey: UpdateCleanup.lastRunKey) == "0.2.2")
        #expect(defaults.string(forKey: UpdateCleanup.downloadedKey) == nil)
    }

    @Test func 처음_설치했거나_같은_버전이거나_거절하면_묻지_않거나_남긴다() throws {
        var asked = 0
        // 처음 설치: 지난 버전 기록이 없다.
        let first = fresh()
        first.set("/tmp/x.dmg", forKey: UpdateCleanup.downloadedKey)
        #expect(UpdateCleanup.cleanUpAfterUpdate(defaults: first, current: "0.2.2") { _ in asked += 1; return true } discard: { _ in } == nil)
        // 같은 버전을 다시 켬
        let same = fresh()
        same.set("0.2.2", forKey: UpdateCleanup.lastRunKey)
        #expect(UpdateCleanup.cleanUpAfterUpdate(defaults: same, current: "0.2.2") { _ in asked += 1; return true } discard: { _ in } == nil)
        #expect(asked == 0)
        // 그대로 두기를 고르면 파일이 남는다.
        let keep = fresh()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("Clocky \(UUID().uuidString).dmg")
        try Data([1]).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        keep.set("0.2.1", forKey: UpdateCleanup.lastRunKey)
        keep.set(file.path, forKey: UpdateCleanup.downloadedKey)
        #expect(UpdateCleanup.cleanUpAfterUpdate(defaults: keep, current: "0.2.2") { _ in false } discard: { _ in } == nil)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }
}
