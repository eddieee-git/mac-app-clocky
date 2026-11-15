import Foundation

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
        // 앱 샌드박스라 자기 자신을 바꿀 수 없다. 확인한 dmg를 다운로드 폴더에 받아 연다.
        installMode: .openDownloadedDMG,
        isEnglish: { Localization.language == .english },
        // 0.2.2까지 쓰던 "업데이트 자동 확인" 설정
        legacyAutoCheckKey: "checkForUpdates"
    ))
}
