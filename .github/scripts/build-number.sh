#!/usr/bin/env bash
# เลข build ที่สโตร์ใช้ ต้องเพิ่มขึ้นเสมอ — พิมพ์ BUILD_NUMBER=<เลข> สำหรับต่อท้าย $GITHUB_ENV
# BUILD_NUMBER_INPUT (ระบุตอนกดรัน) มาก่อน ไม่งั้นใช้ BUILD_NUMBER_OFFSET (ค่าเริ่มต้น 100) + เลขรอบของ workflow
set -euo pipefail

number="${BUILD_NUMBER_INPUT:-}"
if [ -z "$number" ]; then
  offset="${BUILD_NUMBER_OFFSET:-100}"
  [[ "$offset" =~ ^[0-9]+$ ]] || { echo "::error::BUILD_NUMBER_OFFSET ต้องเป็นตัวเลข" >&2; exit 1; }
  number=$((offset + GITHUB_RUN_NUMBER))
fi
[[ "$number" =~ ^[1-9][0-9]*$ ]] || { echo "::error::เลข build ต้องเป็นจำนวนเต็มบวก" >&2; exit 1; }
echo "BUILD_NUMBER=$number"
