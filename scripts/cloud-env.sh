# Source from a shell in the prepared cloud snapshot.
export PATH="/workspace/toolchains/flutter/bin:/workspace/toolchains/android-sdk/platform-tools:$PATH"
export XDG_CONFIG_HOME=/workspace/toolchains/config
export ANALYZER_STATE_LOCATION_OVERRIDE=/workspace/toolchains/analyzer
export PUB_CACHE=/workspace/toolchains/pub-cache
export GRADLE_USER_HOME=/workspace/toolchains/gradle-cache
export ANDROID_HOME=/workspace/toolchains/android-sdk
export ANDROID_USER_HOME=/workspace/toolchains/android-home
export FLUTTER_SUPPRESS_ANALYTICS=true
export CI=true


export JAVA_HOME=/workspace/toolchains/jdk
export PATH="$JAVA_HOME/bin:$PATH"

export NOTIFILTER_DEBUG_KEYSTORE=/workspace/toolchains/notifilter-debug.keystore
