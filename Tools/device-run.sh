#!/bin/zsh
# Bangun kedua app untuk perangkat fisik generik dengan tanda tangan otomatis,
# supaya galat tanda tangan/profil terlihat sebelum memasang ke perangkat.
#
#   Tools/device-run.sh <team-id> [bundle-id-prefix]
#
# Menulis Config/Local.xcconfig (tidak di-commit), menjalankan xcodegen, lalu
# `xcodebuild build` untuk generic iOS & watchOS device dengan
# -allowProvisioningUpdates. Tidak memasang apa pun ke perangkat.
set -euo pipefail
cd "$(dirname "$0")/.."

team="${1:-}"
prefix="${2:-}"
if [[ ! "$team" =~ '^[A-Z0-9]{10}$' ]]; then
  echo "Pemakaian: Tools/device-run.sh <team-id 10 karakter> [bundle-id-prefix]" >&2
  exit 2
fi

{
  echo "// Dibuat oleh Tools/device-run.sh — tidak di-commit."
  echo "DEVELOPMENT_TEAM = $team"
  [[ -n "$prefix" ]] && echo "BUNDLE_ID_PREFIX = $prefix"
} > Config/Local.xcconfig
echo "Config/Local.xcconfig ditulis (team $team${prefix:+, prefix $prefix})."

XCODEGEN="${XCODEGEN:-$(command -v xcodegen || echo "$HOME/Developer/tools/XcodeGen/.build/release/xcodegen")}"
"$XCODEGEN" generate

mkdir -p build
status=0
for pair in "PointAndKnow|generic/platform=iOS" "PointAndKnowWatch|generic/platform=watchOS"; do
  scheme="${pair%%|*}"; dest="${pair##*|}"
  log="build/device-$scheme.log"
  echo "== $scheme ($dest) → $log"
  if xcodebuild build -project PointAndKnow.xcodeproj -scheme "$scheme" \
      -destination "$dest" -allowProvisioningUpdates -skipPackagePluginValidation \
      > "$log" 2>&1; then
    echo "   BUILD SUCCEEDED"
  else
    status=1
    echo "   BUILD FAILED — galat tanda tangan/profil:"
    grep -E 'error:|Signing|provisioning|No Account|No profiles' "$log" | sort -u | head -20
  fi
done
exit $status
