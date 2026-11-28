#!/usr/bin/env bash
# ติดตั้ง certificate กับ provisioning profile บน runner แล้วตั้ง build ของ Release ให้เซ็นแบบ manual
# แก้ไฟล์ในโปรเจกต์ (Release.xcconfig, Runner.entitlements) — ใช้บน CI เท่านั้น
set -euo pipefail
[ "${GITHUB_ACTIONS:-}" = true ] || { echo "สคริปต์นี้ใช้บน GitHub Actions เท่านั้น" >&2; exit 1; }

bundle_id=com.codenour.anything
keychain="$RUNNER_TEMP/signing.keychain-db"
keychain_password="$(openssl rand -hex 24)"
profile="$RUNNER_TEMP/profile.mobileprovision"
plist_buddy=/usr/libexec/PlistBuddy

printf '%s' "$IOS_CERTIFICATE_BASE64" | base64 --decode > "$RUNNER_TEMP/certificate.p12"
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$RUNNER_TEMP/certificate.p12" -P "$IOS_CERTIFICATE_PASSWORD" -f pkcs12 -k "$keychain" \
  -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" > /dev/null
# ไม่ใส่เครื่องหมายคำพูดเพื่อแยกเป็นหลายรายการ ชื่อ keychain เดิมบน runner ไม่มีช่องว่าง
# shellcheck disable=SC2046
security list-keychains -d user -s "$keychain" $(security list-keychains -d user | tr -d '"')

printf '%s' "$IOS_PROFILE_BASE64" | base64 --decode > "$profile"
security cms -D -i "$profile" > "$RUNNER_TEMP/profile.plist"
read_profile() { "$plist_buddy" -c "Print :$1" "$RUNNER_TEMP/profile.plist"; }
uuid="$(read_profile UUID)"
name="$(read_profile Name)"
team="$(read_profile TeamIdentifier:0)"
app_id="$(read_profile Entitlements:application-identifier)"
if [ "$app_id" != "$team.$bundle_id" ]; then
  echo "::error::provisioning profile เป็นของ $app_id ไม่ใช่ $bundle_id"
  exit 1
fi
if ! grep -q "DEVELOPMENT_TEAM = $team;" app/ios/Runner.xcodeproj/project.pbxproj; then
  echo "::error::team ของ provisioning profile ไม่ตรงกับ DEVELOPMENT_TEAM ในโปรเจกต์"
  exit 1
fi
for dir in "$HOME/Library/MobileDevice/Provisioning Profiles" \
  "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"; do
  mkdir -p "$dir"
  cp "$profile" "$dir/$uuid.mobileprovision"
done

# ตั้งใน xcconfig ของ target Runner เท่านั้น package อื่นจึงไม่ถูกบังคับให้ใช้ profile นี้
cat >> app/ios/Flutter/Release.xcconfig <<XCCONFIG

CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY[sdk=iphoneos*] = Apple Distribution
PROVISIONING_PROFILE_SPECIFIER = $name
XCCONFIG

# profile สำหรับสโตร์ใช้ APNs แบบ production การเซ็นแบบ manual ไม่เปลี่ยนค่านี้ให้
"$plist_buddy" -c 'Set :aps-environment production' app/ios/Runner/Runner.entitlements

options="$RUNNER_TEMP/ExportOptions.plist"
rm -f "$options"
for command in \
  "Add :method string app-store-connect" \
  "Add :teamID string $team" \
  "Add :signingStyle string manual" \
  "Add :signingCertificate string Apple Distribution" \
  "Add :provisioningProfiles dict" \
  "Add :provisioningProfiles:$bundle_id string $name" \
  "Add :uploadSymbols bool true" \
  "Add :manageAppVersionAndBuildNumber bool false"; do
  "$plist_buddy" -c "$command" "$options"
done
