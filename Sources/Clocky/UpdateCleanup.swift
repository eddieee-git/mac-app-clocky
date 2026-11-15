import AppKit

// 업데이트 자체는 공통 파일(AppUpdater.swift)이 한다. 여기에는 Clocky에만 있는 것만 남긴다.

enum AppVersion {
    /// 이 앱의 버전. 번들 없이 돌 때(시험)는 0.
    static var current: String {
        #if DEBUG
        if let version = UserDefaults.standard.string(forKey: "debugAppVersion") { return version }
        #endif
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// "v0.2.1" → "0.2.1". 숫자로 시작하지 않으면 nil.
    static func normalized(_ tag: String) -> String? {
        var text = tag.trimmingCharacters(in: .whitespaces)
        if text.first == "v" || text.first == "V" { text.removeFirst() }
        guard let first = text.first, first.isNumber else { return nil }
        return text
    }

    /// 점으로 나눈 숫자를 차례로 비교한다. 0.2 = 0.2.0. "-beta" 같은 꼬리는 무시한다.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ text: String) -> [Int] {
            let core = text.split(separator: "-").first.map(String.init) ?? text
            return core.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}

/// 0.2.x(샌드박스)는 새 dmg를 다운로드 폴더에 받아 열어 주었다. 그렇게 0.3으로 넘어오면
/// 처음 켤 때 그 dmg를 정리할지 묻는다. 0.3부터는 AppUpdater가 바꿔 넣으므로 dmg가 남지 않는다.
enum UpdateCleanup {
    static let downloadedKey = "downloadedUpdate", lastRunKey = "lastRunVersion"  // downloadedUpdate는 AppUpdater.downloadedKey와 같다

    /// 새 버전으로 처음 켰으면, Clocky가 받아 둔 dmg를 꺼내고 휴지통으로 옮길지 묻는다.
    /// 받은 파일이 없으면(직접 업데이트했으면) 아무것도 묻지 않는다. 정리할 파일을 돌려준다.
    @discardableResult
    static func cleanUpAfterUpdate(defaults: UserDefaults = .standard, current: String = AppVersion.current,
                                   confirm: (URL) -> Bool = askToTrash, discard: (URL) -> Void = ejectAndTrash) -> URL? {
        let last = defaults.string(forKey: lastRunKey)
        defaults.set(current, forKey: lastRunKey)
        guard let last, AppVersion.isNewer(current, than: last),
              let path = defaults.string(forKey: downloadedKey) else { return nil }
        defaults.removeObject(forKey: downloadedKey)
        let file = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path), confirm(file) else { return nil }
        discard(file)
        return file
    }

    /// 열어 둔 dmg가 아직 붙어 있으면 먼저 꺼내고, 파일을 휴지통으로 옮긴다. 샌드박스가 꺼내기를 막으면 그대로 둔다.
    private static func ejectAndTrash(_ file: URL) {
        let volume = URL(fileURLWithPath: "/Volumes/Clocky")
        if FileManager.default.fileExists(atPath: volume.path) {
            try? NSWorkspace.shared.unmountAndEjectDevice(at: volume)
        }
        try? FileManager.default.trashItem(at: file, resultingItemURL: nil)
    }

    private static func askToTrash(_ file: URL) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("Clocky를 %@ 버전으로 업데이트했어요", AppVersion.current)
        alert.informativeText = L("받아 둔 설치 파일은 이제 필요 없어요: %@", file.lastPathComponent)
        alert.addButton(withTitle: L("휴지통으로 옮기기"))
        alert.addButton(withTitle: L("그대로 두기"))
        return alert.runModal() == .alertFirstButtonReturn
    }
}
