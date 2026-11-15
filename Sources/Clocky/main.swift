import AppKit

// 샌드박스를 쓰던 0.2.x의 설정을 읽기 전에 일반 위치로 옮긴다(처음 한 번).
SandboxMigration.runIfNeeded()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// 메뉴바 전용 앱: Dock 아이콘과 앱 메뉴를 표시하지 않는다.
app.setActivationPolicy(.accessory)
app.run()
