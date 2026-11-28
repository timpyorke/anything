#!/usr/bin/env bash
# หยุดตั้งแต่ต้นถ้ายังไม่ได้ตั้ง secret หรือ variable ที่จำเป็น: require-env.sh NAME...
set -euo pipefail

missing=0
for name in "$@"; do
  if [ -z "${!name:-}" ]; then
    echo "::error::ยังไม่ได้ตั้ง $name ใน environment production (ดู docs/deploy.md)"
    missing=1
  fi
done
exit "$missing"
