#!/usr/bin/env bash
# Bộ cài offline tự giải nén. Ghép với tar.gz khi đóng gói.
set -euo pipefail
if [[ "${EUID}" -ne 0 ]]; then
  echo "Chạy: sudo $0" >&2
  exit 1
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ARCHIVE="$(awk '/^__ARCHIVE_BELOW__/ { print NR + 1; exit 0; }' "$0")"
tail -n +"$ARCHIVE" "$0" | tar -xz -C "$TMP"
DIR="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
if [[ -z "$DIR" || ! -x "$DIR/install.sh" ]]; then
  echo "Bộ cài hỏng (không thấy install.sh)." >&2
  exit 1
fi
bash "$DIR/install.sh"
exit 0
__ARCHIVE_BELOW__
