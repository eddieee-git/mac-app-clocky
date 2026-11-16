> 문서·UI 규칙은 ../mac-app/STYLE.md를 따른다. 다르게 할 때는 여기에 이유를 적는다.

> 업데이트 코드(`AppUpdater.swift`)는 다섯 앱 공통이다. 여기서 고치지 않고 ../mac-app/shared/AppUpdater.swift를 고친 뒤 ../mac-app/scripts/sync-shared.sh로 복사한다. 이 앱에만 해당하는 값은 `UpdaterSetup.swift`에 있다. 시험할 때는 디버그 빌드에서 `-debugUpdateURL <주소>`, `-debugUpdatePublicKey <키>`, `-debugAppVersion <버전>`을 쓴다.

# Clocky 개발 안내

메뉴바에 사는 넘김시계 타이머·알람·캘린더 알림 앱. 사용자 문서는 README.md(한국어)·README.en.md, 설치는 docs/install*.md, 바뀐 점은 CHANGELOG.md. 이 파일은 개발을 이어받는 사람(과 Claude)을 위한 것이다.

## 지켜야 할 것

- 대화와 문서는 한국어가 기본. 사용자 문서는 한국어·영어를 함께 고친다(README, docs/install, CHANGELOG, 화면 문구).
- **Apple 계정이 필요한 기능은 쓰지 않는다**: iCloud, 공증(notarization), 알림 권한, Developer ID 등. 서명은 임시 서명(`codesign --sign -`)뿐이다. 그래서 처음 실행할 때 Gatekeeper 경고가 나오고, 업데이트하면 캘린더 접근을 다시 물을 수 있다(문서에 안내되어 있음).
- Apple 실리콘(arm64), macOS 13 이상. Xcode 없이 Command Line Tools만으로 빌드한다. 외부 라이브러리 없음.
- 시계 창 크기는 고정. 항상 위는 기본으로 켜져 있고 끌 수 있다. 핀은 닫기 버튼과 같은 줄. 울리기 10초 전부터 창이 깜빡인다(설정으로 바꿈). 알람에는 이름이 있다.
- 작업 순서: 구현 → 빌드 → /Applications에 다시 설치 → 사용자 확인 → 로컬 커밋 → **사용자가 "push해"라고 할 때만 push**.
- 커밋 작성자는 저장소에 설정된 eddieee-git noreply 주소.

## 구조 (Sources/Clocky)

| 파일 | 내용 |
|---|---|
| ClockStore.swift | 타이머·알람·일정 알림의 상태와 시간 계산, 저장(UserDefaults JSON), 옛 설정 옮기기, 울리기·다시 울림 |
| FlipTimerView.swift | 시계 창 SwiftUI 화면 |
| TimerWindow.swift | 시계 창(NSPanel), 울릴 때 클릭·키 가로채기, 창 단축키 |
| ListWindow.swift | 전체 목록 창 |
| SettingsWindow.swift | 설정 창(일반·타이머·알람·소리·캘린더·단축키), 업데이트 칸 |
| ClockySettings.swift | 설정 값, 알람 소리, **화면 문구 영어 표(`Localization.english`)** |
| ICalendar.swift / CalendarSync.swift | iCal 해석(RRULE·EXDATE·시간대 등)과 주소에서 받아 오기 |
| MacCalendarSource.swift | EventKit으로 Mac 캘린더 앱 일정 읽기 |
| AppUpdater.swift(공통) / UpdaterSetup.swift / UpdateCleanup.swift | GitHub 최신 릴리스 확인, SHA-256·서명 확인 뒤 바꿔 넣고 다시 켜기 / Clocky 값(울리는 중엔 자동 설치 미룸) / 0.2.x가 받아 둔 dmg 정리 |
| SandboxMigration.swift | 0.2.x 샌드박스 컨테이너의 설정·파일을 처음 한 번 일반 위치로 옮기기(main.swift에서 설정을 읽기 전에) |
| HotKey.swift / MenuBarIcon.swift / AppDelegate.swift | 전역 단축키, 메뉴바 아이콘, 메뉴와 앱 연결 |

- 화면 문구는 `L("한국어")`로 쓰고 영어는 `Localization.english`에 넣는다. **표에 같은 열쇠가 두 번 들어가면 실행 중에 죽는다.**
- 0.3부터 앱 샌드박스를 쓰지 않는다(다른 앱처럼 앱 안에서 바꿔 넣으려고). 권한(Resources/Clocky.entitlements)은 강화 런타임에서 캘린더를 읽기 위한 것 하나뿐이다. 설정은 `~/Library/Preferences/com.eddieee.Clocky.plist`, 캘린더 캐시와 내 소리는 `~/Library/Application Support/Clocky`. 0.2.x의 `~/Library/Containers/com.eddieee.Clocky`는 옮긴 뒤에도 지우지 않는다.
- 주의: 컨테이너가 있으면 `defaults read com.eddieee.Clocky`는 컨테이너 쪽을 읽는다. 지금 설정은 `plutil -p ~/Library/Preferences/com.eddieee.Clocky.plist`로 본다.
- `#if DEBUG`에서만 쓰는 시험용 설정: `debugAppVersion`, `debugUpdateURL`, `debugUpdatePublicKey`(실행 인자 `-이름 값`으로도 줄 수 있다).

## 빌드와 시험

```bash
scripts/build-app.sh          # build/Clocky.app, build/Clocky-<버전>.dmg
scripts/test.sh               # 단위 시험(Swift Testing)
scripts/gui-test.sh           # 창을 띄우는 시험 전부. 이름을 주면 그것만: scripts/gui-test.sh update
scripts/gui-test.sh readme-shots   # README 이미지를 build/shots에 찍는다(한국어·영어)
scripts/e2e-update.sh         # 실제 Clocky가 서명된 새 버전을 받아 바꿔 넣고 다시 켜는지(시험용 번들 ID, 1분쯤)
swift scripts/make-icon.swift # 앱 아이콘 다시 그리기
```

- GUI 시험은 소스를 임시 폴더에 복사해 `private`를 풀고, 번들 없는 "Clocky" 설정 도메인으로 돈다. 실제 앱 설정에는 손대지 않는다.
- 화면이 잠겨 있으면 클릭·키·스크린샷이 필요한 `basics`, `restore`, `keyboard`, `windows`, `readme-shots`는 건너뛴다(잠금을 풀고 다시 돌린다). 부하가 크면 시간에 민감한 확인이 가끔 실패하므로 다시 돌려 본다.
- 단위 시험은 실제 사용자 폴더(다운로드, 휴지통)를 건드리지 않게 파일 처리를 주입해서 쓴다.
- 다시 설치: `osascript -e 'quit app "Clocky"'` → `rm -rf /Applications/Clocky.app` → `cp -R build/Clocky.app /Applications/` → `open /Applications/Clocky.app`.

## 릴리스

1. Resources/Info.plist의 `CFBundleShortVersionString`과 `CFBundleVersion`(빌드 번호, 하나씩 올림)을 올린다.
2. `docs/releases/vX.Y.Z.md`(GitHub 릴리스 본문, ../mac-app/templates/release-note.md 참고)를 쓰고, `CHANGELOG.md`·`CHANGELOG.en.md` 맨 위에 `## X.Y.Z (날짜)`와 짧은 명사형 항목을 더한다.
   - 노트 첫머리 약 600자가 앱의 업데이트 창에 보이므로 바뀐 점을 맨 앞에 한국어 · 영어로 쓴다. 업데이트 방법과 SHA-256을 함께 적는다(이전 노트 v0.3.0.md 참고).
3. `scripts/test.sh` → `scripts/e2e-update.sh` → `scripts/build-app.sh`. 서명 키가 있으면 `build/Clocky-X.Y.Z.dmg.sig`도 만든다(없으면 경고). `shasum -a 256 build/Clocky-X.Y.Z.dmg`를 노트에 넣는다.
4. 다시 설치하고 커밋한 뒤, push는 사용자가 허락할 때(릴리스하라는 말은 push 허락으로 쳐 왔다). `gh release create vX.Y.Z build/Clocky-X.Y.Z.dmg build/Clocky-X.Y.Z.dmg.sig --target main --title "Clocky X.Y.Z" --notes-file docs/releases/vX.Y.Z.md --latest`.
   - **0.2.2부터 앱은 `.sig`가 없거나 서명이 맞지 않는 릴리스는 받지 않는다.** dmg를 먼저, `.sig`를 함께 올린다. 태그는 `v` + 버전. 초안·시험판은 앱이 무시한다.
5. 확인: `curl -s https://api.github.com/repos/eddieee-git/mac-app-clocky/releases/latest`의 태그·dmg `digest`, 그리고 dmg와 `.sig`를 다시 받아 SHA-256과 서명(`clocky-release:<버전>:<SHA-256>`, 공개키는 UpdaterSetup.swift)을 검증한다.

## 릴리스 서명 키

- Ed25519 비밀키는 저장소 밖 `~/.clocky-release/signing-key`(권한 600)에 있다. 공개키는 `UpdaterSetup.swift`의 `AppUpdater.appPublicKey`에 들어 있다.
- `swift scripts/release-key.swift public`은 공개키를 보여 준다(없으면 새로 만든다). `sign <dmg> <버전>`은 `<dmg>.sig`를 만든다. 서명 내용은 `clocky-release:<버전>:<dmg SHA-256>`.
- **키를 잃어버리면 이미 배포한 앱이 새 버전을 받지 못한다.** 안전한 곳(암호 관리자 등)에 백업하고, 다른 Mac에서 릴리스하려면 같은 자리에 복사한다. 키를 바꾸면 사용자는 한 번 직접 업데이트해야 한다.
- 단위 시험 `서명_스크립트와_앱의_공개키가_맞다`는 키가 있는 Mac에서만 돌며, 앱의 공개키가 비밀키와 짝인지 확인한다.

## 정해 둔 것

- GitHub 저장소의 비공개 취약점 신고(private vulnerability reporting)를 켜 두었다. SECURITY.md의 신고 경로가 이것을 쓴다.

- 0.3부터 앱 샌드박스를 껐다. 샌드박스 앱은 /Applications의 자기 자신을 바꿀 수 없어 업데이트가 "dmg 받아 열기"에 머물렀기 때문이다. 다른 다섯 앱도 샌드박스 없이 배포한다. 대신 받은 업데이트는 SHA-256과 Ed25519 서명을 확인한다.
- iCal 비밀 주소는 키체인이 아니라 UserDefaults에 둔다. 임시 서명은 빌드마다 서명이 달라져, 키체인에 두면 업데이트할 때마다 macOS가 키체인 접근 암호를 묻기 때문이다. 대신 문서에 저장 위치와 백업에 들어간다는 점을 적었다.

## 지금 상태 (2026-11-16)

- **GitHub 최신 릴리스: v0.3.0** (2026-11-15). 코드의 버전도 0.3.0(빌드 6), 다음에 낼 버전은 0.3.1. `main`은 GitHub와 같고 작업 폴더는 깨끗하다.
- 0.3.0에서 바뀐 것: 앱 샌드박스를 끄고 업데이트를 앱 안에서 바꿔 넣는다(`installMode` 기본값 `.replaceInPlace`, 설정의 "새 버전 자동으로 설치"). 처음 켤 때 `SandboxMigration`이 0.2.x 컨테이너의 데이터를 옮긴다.
- 이 Mac: /Applications에 0.3.0이 설치되어 있고 컨테이너에서 옮기기가 끝났다(`migratedFromSandbox` = true). 옮기기 전 일반 위치에 있던 0.1 시절 설정은 `~/Library/Application Support/Clocky/Preferences before 0.3.plist`에 남아 있다.
- 0.2.x 사용자는 0.3.0으로 갈 때 한 번만 dmg에서 끌어다 놓아 바꾼다(릴리스 노트·설치 안내에 적음). 0.3.0 → 0.3.1부터 앱 안 설치.
- 확인한 것: 단위 시험 45개, GUI 시험(update·calendar·basics 등), `scripts/e2e-update.sh`(실제 Clocky 디버그 빌드가 0.3.0 → 0.3.1로 스스로 바꿔 넣고 다시 켬), 이 Mac 실제 데이터로 옮기기, 올라간 dmg의 SHA-256과 서명.
- 확인하지 못한 것: 실제 GitHub 릴리스로 0.3.0이 스스로 업데이트하는 것은 0.3.1을 낼 때 처음 일어난다. 0.3.1을 내면 이 Mac에서 메뉴의 **새 버전 0.3.1 설치…**로 확인한다.
- 저장소 규칙(../mac-app/CLAUDE.md): 앞으로는 `main`에 바로 커밋하지 말고 작업 브랜치에서 한 뒤 합친다.

## 남은 일

- Mac 캘린더 앱 연동은 실제 캘린더로 아직 시험하지 못했다(다른 Mac에서 확인 예정).
- macOS 13·14·15에서는 아직 실행해 보지 않았다.
- Floaty(별도 저장소)의 README에 있는 Clocky 소개 문구는 Floaty 쪽에서 고친다.
- README 스크린샷 다시 찍기: 설정 창에 정보 탭과 업데이트 칸이 생겼다. `scripts/gui-test.sh readme-shots`(화면 잠금이 풀려 있어야 함)로 찍고 사용자가 보고 고른다.
- `AppDelegate`의 `AppUpdater.shared` 줄에서 Swift 6 대비 경고 하나(Swift 5 모드라 동작엔 영향 없음, 공통 문제라 ../mac-app에서 다룬다).
- 사용자 할 일: 서명 키 `~/.clocky-release/signing-key` 백업(암호 관리자 등).
