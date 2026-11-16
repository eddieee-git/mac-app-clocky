import AppKit
import CryptoKit
import SwiftUI
// 이 Mac 안의 작은 웹 서버를 GitHub 릴리스처럼 쓰고, 공통 업데이트(AppUpdater)의 새 버전 찾기부터
// dmg 받기와 SHA-256·서명·주소 확인, 다운로드 폴더 저장까지 본다.
UserDefaults.standard.removePersistentDomain(forName: "Clocky")
setvbuf(stdout, nil, _IONBF, 0)
let shots = CommandLine.arguments[1]
let lang = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "ko"
let ko = lang == "ko"
let port = Int.random(in: 20000...40000)
let base = "http://127.0.0.1:\(port)"
UserDefaults.standard.set(lang, forKey: "language"); UserDefaults.standard.set(true, forKey: "hasLaunched")
UserDefaults.standard.set("0.2.0", forKey: "debugAppVersion")
// 시험 실행은 .app 번들이 아니라 앱 안에서 설치할 수 없다. 그럴 때 자동 확인이 한 번 띄우는 알림 창이 시험을 멈추지 않게, 이미 알린 것으로 해 둔다.
UserDefaults.standard.set("0.3.0", forKey: "offeredUpdateVersion")
UserDefaults.standard.set("\(base)/latest.json", forKey: "debugUpdateURL")
// 시험용 서명 키. 앱이 이 공개키를 믿게 한다.
let testKey = Curve25519.Signing.PrivateKey()
UserDefaults.standard.set(testKey.publicKey.rawRepresentation.base64EncodedString(), forKey: "debugUpdatePublicKey")

let folder = FileManager.default.temporaryDirectory.appendingPathComponent("clocky-update-\(UUID().uuidString)")
let downloads = folder.appendingPathComponent("Downloads")
try! FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
let dmg = Data((0..<50_000).map { UInt8($0 % 251) })
try! dmg.write(to: folder.appendingPathComponent("Clocky-0.3.0.dmg"))
let sha = SHA256.hash(data: dmg).map { String(format: "%02x", $0) }.joined()
func sign(_ version: String) -> String {
  try! testKey.signature(for: Data("clocky-release:\(version):\(sha)".utf8)).base64EncodedString()
}
try! sign("0.3.0").write(to: folder.appendingPathComponent("Clocky-0.3.0.dmg.sig"), atomically: true, encoding: .utf8)
// 옛 버전에 붙였던 서명을 새 버전에 그대로 붙인 경우
try! sign("0.2.9").write(to: folder.appendingPathComponent("old.sig"), atomically: true, encoding: .utf8)
func release(_ tag: String, digest: String) -> String {
  ##"{"tag_name":"\##(tag)","html_url":"https://github.com/eddieee-git/mac-app-clocky/releases/tag/\##(tag)","body":"새 기능 · New\r\n- **업데이트 확인**","draft":false,"prerelease":false,"assets":[{"name":"Clocky-0.3.0.dmg","browser_download_url":"\##(base)/Clocky-0.3.0.dmg","digest":"sha256:\##(digest)"},{"name":"Clocky-0.3.0.dmg.sig","browser_download_url":"\##(base)/Clocky-0.3.0.dmg.sig"}]}"##
}
try! release("v0.3.0", digest: sha).write(to: folder.appendingPathComponent("latest.json"), atomically: true, encoding: .utf8)
try! release("v0.2.0", digest: sha).write(to: folder.appendingPathComponent("same.json"), atomically: true, encoding: .utf8)
let server = Process()
server.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
server.arguments = ["-m", "http.server", "\(port)", "--bind", "127.0.0.1", "--directory", folder.path]
server.standardOutput = FileHandle.nullDevice; server.standardError = FileHandle.nullDevice
try! server.run()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
var failures = 0
func check(_ ok: Bool, _ msg: String) { print(ok ? "PASS" : "FAIL", msg); if !ok { failures += 1 } }
func shot(_ number: Int, _ name: String) {
  let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
  p.arguments = ["-x", "-o", "-l", "\(number)", "\(shots)/\(name).png"]; try? p.run(); p.waitUntilExit()
}
var steps: [(Double, @MainActor () -> Void)] = []
func at(_ x: Double, _ f: @escaping @MainActor () -> Void) { steps.append((x, f)) }
@MainActor var u: AppUpdater { AppUpdater.shared }
func menuTitles() -> [String] { delegate.statusItem?.menu?.items.map(\.title) ?? [] }
let t = AppUpdater.Messages(english: !ko)
let key = testKey.publicKey.rawRepresentation.base64EncodedString()
func downloadsList() -> [String] { ((try? FileManager.default.contentsOfDirectory(atPath: downloads.path)) ?? []).sorted() }
/// 받아서 확인한 뒤 다운로드 폴더로 옮긴다(메뉴에서 "받기"를 고른 것과 같은 길, 창만 띄우지 않는다).
func get(_ r: AppUpdater.Release) async throws -> URL {
  let file = try await AppUpdater.downloadVerified(r, publicKey: key, format: AppUpdater.appSignatureFormat, messages: t)
  return try AppUpdater.moveToDownloads(file, appName: "Clocky", version: r.version, folder: downloads)
}
func copy(_ r: AppUpdater.Release, dmg: URL?? = .none, signature: URL?? = .none, sha256: String?? = .none) -> AppUpdater.Release {
  AppUpdater.Release(version: r.version, dmg: dmg ?? r.dmg, signature: signature ?? r.signature,
                     sha256: sha256 ?? r.sha256, page: r.page, notes: r.notes)
}

at(1.0) {
  check(u.available == nil && u.lastCheck == nil, "처음에는 아직 확인 전")
  check(menuTitles().contains(ko ? "업데이트 확인…" : "Check for Updates…"), "메뉴에 업데이트 확인: \(menuTitles())")
  check(u.autoCheck, "자동 확인은 기본으로 켜짐")
  check(!u.canInstallInPlace, "시험 실행(번들 아님)에서는 앱 안에서 바꿔 넣지 않음")
  // 켠 지 15초 뒤 저절로 확인하는 것과 같은 길을 바로 부른다.
  u.checkIfDue()
}
at(4.0) {
  check(u.available?.version == "0.3.0", "새 버전 찾음: \(String(describing: u.available?.version))")
  check(u.lastCheck != nil, "마지막 확인 시각 기록")
  check(menuTitles().contains(ko ? "새 버전 0.3.0 받기…" : "Get Version 0.3.0…"), "메뉴에 새 버전 알림: \(menuTitles())")
  delegate.settingsWindow.show(tab: .general)
}
at(5.5) {
  if let w = NSApp.windows.first(where: { $0.title == L("Clocky 설정") }) { shot(w.windowNumber, "settings-update-\(lang)") }
  let r = u.available!
  Task { @MainActor in
    do {
      let file = try await get(r)
      check(file.lastPathComponent == "Clocky 0.3.0.dmg", "다운로드 폴더에 저장: \(file.lastPathComponent)")
      check((try? Data(contentsOf: file)) == dmg, "받은 내용이 같음")
      let again = try await get(r)
      check(again.lastPathComponent == "Clocky 0.3.0 (2).dmg", "두 번째는 번호: \(again.lastPathComponent)")
    } catch { check(false, "다운로드 실패: \(error)") }

    // 확인에 실패하면 다운로드 폴더에 아무것도 남지 않는다.
    let bad: [(String, AppUpdater.Release)] = [
      ("SHA-256이 다르면 거부", copy(r, sha256: .some(String(repeating: "0", count: 64)))),
      ("다른 버전의 서명은 거부", copy(r, signature: .some(URL(string: "\(base)/old.sig")))),
      ("서명 없는 릴리스는 받지 않음", copy(r, signature: .some(nil))),
      ("GitHub 밖에서는 받지 않음", copy(r, dmg: .some(URL(string: "https://example.com/Clocky.dmg")))),
    ]
    for (name, release) in bad {
      do { _ = try await get(release); check(false, name) } catch { check(true, "\(name): \(error.localizedDescription)") }
    }
    check(downloadsList().count == 2, "잘못 받은 파일은 남지 않음: \(downloadsList())")
  }
}
at(9.0) {
  // 같은 버전이 최신이면 알림이 사라진다.
  UserDefaults.standard.set("\(base)/same.json", forKey: "debugUpdateURL")
  UserDefaults.standard.removeObject(forKey: "lastUpdateCheck")
  Task { @MainActor in
    await u.check(userInitiated: false)
    check(u.available == nil && u.state == .upToDate, "최신 버전이면 알림 없음: \(u.state)")
    check(menuTitles().contains(ko ? "업데이트 확인…" : "Check for Updates…"), "메뉴가 다시 업데이트 확인으로: \(menuTitles())")
  }
}
at(11.0) {
  // 끄면 저절로 확인하지 않는다.
  u.autoCheck = false
  UserDefaults.standard.removeObject(forKey: "lastUpdateCheck")
  u.checkIfDue()
  check(u.state != .checking, "자동 확인을 끄면 묻지 않음")
}
at(12.0) {
  print(failures == 0 ? "ALL PASS" : "FAILURES: \(failures)")
  server.terminate()
  try? FileManager.default.removeItem(at: folder)
  UserDefaults.standard.removePersistentDomain(forName: "Clocky")
  exit(failures == 0 ? 0 : 1)
}
for (x, f) in steps { DispatchQueue.main.asyncAfter(deadline: .now() + x) { MainActor.assumeIsolated { f() } } }
app.run()
