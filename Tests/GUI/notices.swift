import AppKit
// 놓친 알림 띠: 늦게 확인한 알람이 시계 창과 메뉴바 메뉴에 보이고, 확인을 누르면 사라지는지 본다.
UserDefaults.standard.removePersistentDomain(forName: "Clocky")
setvbuf(stdout, nil, _IONBF, 0)
let shots = CommandLine.arguments[1]
let lang = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "ko"
UserDefaults.standard.set(lang, forKey: "language"); UserDefaults.standard.set(true, forKey: "hasLaunched")
let ko = lang == "ko"
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
var t: ClockStore { delegate.window.store }
var steps: [(Double, () -> Void)] = []
func at(_ x: Double, _ f: @escaping () -> Void) { steps.append((x, f)) }

at(0.5) {
  let a = t.addAlarm(minutes: 7 * 60 + 30); t.renameAlarm(a, to: ko ? "기상" : "Wake up")
  t.mode = .alarm
  t.forceNext(a, Date().addingTimeInterval(-3 * 3600))
  t.tick()
}
at(1.5) {
  check(delegate.window.isVisible, "놓친 알림이 생기면 창이 뜸")
  check(t.missedAlerts.map(\.title) == [ko ? "기상" : "Wake up"], "놓친 알림 기록: \(t.missedAlerts.map(\.title))")
  if let menu = delegate.statusItem?.menu {
    delegate.menuNeedsUpdate(menu)
    check(menu.items.contains { $0.title.hasPrefix("⚠︎") }, "메뉴바 메뉴에 놓친 알림 줄")
  }
  shot(delegate.window.panel.windowNumber, "notices-\(lang)")
  t.clearMissed()
}
at(2.5) {
  check(t.missedAlerts.isEmpty, "확인하면 사라짐")
  print(failures == 0 ? "ALL PASS" : "FAILURES: \(failures)")
  UserDefaults.standard.removePersistentDomain(forName: "Clocky")
  exit(failures == 0 ? 0 : 1)
}
for (x, f) in steps { DispatchQueue.main.asyncAfter(deadline: .now() + x, execute: f) }
app.run()
