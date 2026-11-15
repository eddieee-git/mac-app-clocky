import AppKit

/// 공통 업데이트(AppUpdater.swift)에 Clocky 정보를 넣는다. AppUpdater.swift는 mac-app/shared에서 복사해 오므로 여기만 고친다.
extension AppUpdater {
    /// 릴리스 서명 공개 키. 비밀 키는 만든 사람의 Mac에만 있다(scripts/release-key.swift).
    nonisolated static let appPublicKey = "wR4U4lBWoALE/pudjp6Ad3z0pwhW1qgr2d7BR44xgsY="
    /// Clocky는 0.2.2부터 "clocky-release:<버전>:<SHA-256>"에 서명한다. 옛 파일을 새 버전으로 속이지 못한다.
    nonisolated static let appSignatureFormat = SignatureFormat.versionedSHA256(prefix: "clocky-release")

    static let shared = AppUpdater(.init(
        appName: "Clocky",
        repo: "eddieee-git/mac-app-clocky",
        publicKey: appPublicKey,
        signatureFormat: appSignatureFormat,
        isEnglish: { Localization.language == .english },
        // 0.2.2까지 쓰던 "업데이트 자동 확인" 설정
        legacyAutoCheckKey: "checkForUpdates",
        // 0.3부터 샌드박스를 껐으므로 다른 앱과 같이 바꿔 넣고 다시 켠다.
        // 울리는 중이거나 2분 안에 울릴 것이 있으면 자동 설치를 미룬다.
        canRestartNow: {
            MainActor.assumeIsolated {
                guard let store = (NSApp.delegate as? AppDelegate)?.window.store else { return true }
                if store.isRinging { return false }
                return store.nextAlert.map { $0.date.timeIntervalSinceNow > 120 } ?? true
            }
        }
    ))
}
