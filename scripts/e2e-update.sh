#!/bin/zsh
# 실제 Clocky가 새 버전을 받아 스스로 바꿔 넣고 다시 켜는지 끝까지 확인한다.
#
# Clocky 디버그 빌드를 시험용 번들 ID(com.eddieee.clocky.e2e)로 0.3.0과 0.3.1 두 벌 묶고, 이 Mac 안의 웹 서버를
# GitHub 릴리스처럼 써서 시험 키로 서명(clocky-release:<버전>:<SHA-256>)한 0.3.1 dmg를 내려 준다.
# 0.3.0이 자동 확인 → 내려받기 → 확인 → 바꿔 넣기 → 다시 켜기를 하면 통과. 실제 Clocky와 그 설정은 건드리지 않는다.
# 1분쯤 걸린다.
set -eu
cd "$(dirname "$0")/.."
root=$PWD
id=com.eddieee.clocky.e2e
work=$(mktemp -d -t clocky-e2e)
port=$(( 20000 + RANDOM % 20000 ))
server_pid=""
cleanup() {
    [[ -n $server_pid ]] && kill $server_pid 2>/dev/null || true
    pkill -f "$work/Applications/Clocky.app" 2>/dev/null || true
    defaults delete $id >/dev/null 2>&1 || true
    rm -rf "$work"
}
trap cleanup EXIT

echo "== 빌드(디버그)"
swift build -c debug --arch arm64 2>&1 | grep -E "error:" && exit 1 || true
binary=.build/arm64-apple-macosx/debug/Clocky

bundle() {  # bundle <폴더> <버전>
    local app="$1/Clocky.app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    cp "$binary" "$app/Contents/MacOS/Clocky"
    cp Resources/AppIcon.icns "$app/Contents/Resources/"
    cp Resources/Info.plist "$app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set CFBundleIdentifier $id" -c "Set CFBundleShortVersionString $2" -c "Set CFBundleVersion $2" "$app/Contents/Info.plist"
    codesign --force --sign - --options runtime --identifier $id --entitlements Resources/Clocky.entitlements "$app" 2>/dev/null
}
mkdir -p "$work/Applications" "$work/new" "$work/www"
bundle "$work/Applications" 0.3.0
bundle "$work/new" 0.3.1
ln -s /Applications "$work/new/Applications"
hdiutil create -quiet -volname Clocky -srcfolder "$work/new" -format UDZO "$work/www/Clocky-0.3.1.dmg"

echo "== 시험 키로 서명"
cat > "$work/sign.swift" <<'EOF'
import CryptoKit
import Foundation
let key = Curve25519.Signing.PrivateKey()
let path = CommandLine.arguments[1]
let data = try Data(contentsOf: URL(fileURLWithPath: path))
let sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
let message = Data("clocky-release:\(CommandLine.arguments[2]):\(sha)".utf8)
try key.signature(for: message).base64EncodedString().write(toFile: path + ".sig", atomically: true, encoding: .utf8)
print(key.publicKey.rawRepresentation.base64EncodedString())
EOF
public_key=$(swift "$work/sign.swift" "$work/www/Clocky-0.3.1.dmg" 0.3.1)
sha=$(shasum -a 256 "$work/www/Clocky-0.3.1.dmg" | cut -d' ' -f1)
base="http://127.0.0.1:$port"
cat > "$work/www/latest.json" <<EOF
{"tag_name":"v0.3.1","html_url":"$base/","body":"시험 릴리스","assets":[
 {"name":"Clocky-0.3.1.dmg","browser_download_url":"$base/Clocky-0.3.1.dmg","digest":"sha256:$sha"},
 {"name":"Clocky-0.3.1.dmg.sig","browser_download_url":"$base/Clocky-0.3.1.dmg.sig"}]}
EOF
python3 -m http.server $port --bind 127.0.0.1 --directory "$work/www" >/dev/null 2>&1 &
server_pid=$!
sleep 1

echo "== 0.3.0 실행 (자동 확인 → 자동 설치)"
defaults delete $id >/dev/null 2>&1 || true
open -g -n "$work/Applications/Clocky.app" --args \
    -debugUpdateURL "$base/latest.json" \
    -debugUpdatePublicKey "$public_key" \
    -autoInstallUpdates '<true/>' \
    -hasLaunched '<true/>'

installed="?"
for _ in {1..90}; do
    installed=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$work/Applications/Clocky.app/Contents/Info.plist" 2>/dev/null || echo "?")
    [[ $installed == 0.3.1 ]] && pgrep -f "$work/Applications/Clocky.app/Contents/MacOS/Clocky" >/dev/null && break
    sleep 1
done
sleep 2

failed=0
check() { if eval "$1"; then echo "✓ $2"; else echo "✗ $2"; failed=1; fi }
check '[[ $installed == 0.3.1 ]]' "응용 프로그램 자리의 Clocky가 0.3.1로 바뀜 (지금 $installed)"
check 'pgrep -f "$work/Applications/Clocky.app/Contents/MacOS/Clocky" >/dev/null' "새 버전이 다시 켜짐"
check 'codesign --verify --strict "$work/Applications/Clocky.app" 2>/dev/null' "바꿔 넣은 앱의 코드 서명이 온전함"
check '[[ $(ls "$work/Applications") == Clocky.app ]]' "작업 폴더·옛 앱이 남지 않음: $(ls "$work/Applications" | tr '\n' ' ')"
(( failed == 0 )) && echo "모두 통과" || echo "실패"
exit $failed
