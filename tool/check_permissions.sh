#!/usr/bin/env bash
# Fails when a release APK asks for any permission outside the allowlist.
# A new plugin that quietly adds INTERNET or storage access breaks the build
# instead of reaching users.
set -euo pipefail

allowed=(
  "android.permission.CAMERA"
  "com.khovakrishnapilato.pixelpaper.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"
)

aapt2="$(ls -d "${ANDROID_HOME:?ANDROID_HOME is not set}"/build-tools/* | sort -V | tail -1)/aapt2"
status=0

for apk in "$@"; do
  while read -r permission; do
    if [[ ! " ${allowed[*]} " == *" ${permission} "* ]]; then
      echo "::error file=${apk}::permesso non ammesso: ${permission}"
      status=1
    fi
  done < <("$aapt2" dump permissions "$apk" | sed -nE "s/^uses-permission: name='([^']+)'.*/\1/p")
  echo "permessi verificati: $(basename "$apk")"
done

exit "$status"
