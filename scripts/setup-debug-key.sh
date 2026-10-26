#!/usr/bin/env bash
set -euo pipefail
: "${NOTIFILTER_DEBUG_KEYSTORE:?Source scripts/cloud-env.sh first}"
if [ ! -e "$NOTIFILTER_DEBUG_KEYSTORE" ]; then
  "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$NOTIFILTER_DEBUG_KEYSTORE" \
    -alias androiddebugkey -storepass android -keypass android -keyalg RSA \
    -keysize 2048 -validity 10000 -dname 'CN=Android Debug,O=Android,C=US' -noprompt
fi
