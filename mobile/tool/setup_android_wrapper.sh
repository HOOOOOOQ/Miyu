#!/usr/bin/env bash
# Ensures mobile/android has a working Gradle wrapper.
#
# Flutter's Android build shells out to ./gradlew. The wrapper JAR is a binary
# that some checkouts deliberately exclude, so CI (and fresh clones) restore it
# here instead of relying on the developer's local Android Studio install.
set -euo pipefail

ANDROID_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/android"
WRAPPER_DIR="$ANDROID_DIR/gradle/wrapper"
JAR="$WRAPPER_DIR/gradle-wrapper.jar"
GRADLE_VERSION="8.12"

mkdir -p "$WRAPPER_DIR"

if [[ -s "$JAR" ]]; then
  echo "gradle-wrapper.jar already present"
else
  echo "Fetching gradle-wrapper.jar for Gradle $GRADLE_VERSION"
  if ! curl -fsSL --retry 3 --retry-delay 2 \
      -o "$JAR" \
      "https://raw.githubusercontent.com/gradle/gradle/v${GRADLE_VERSION}.0/gradle/wrapper/gradle-wrapper.jar" \
      || ! curl -fsSL --retry 3 --retry-delay 2 \
        -o "$JAR" \
        "https://github.com/gradle/gradle/raw/v${GRADLE_VERSION}/gradle/wrapper/gradle-wrapper.jar"; then
    echo "Download failed; falling back to a locally installed Gradle"
    rm -f "$JAR"
    if command -v gradle >/dev/null 2>&1; then
      (cd "$ANDROID_DIR" && gradle wrapper --gradle-version "$GRADLE_VERSION")
    else
      echo "No Gradle available. Install Gradle $GRADLE_VERSION or run: flutter build apk (which bootstraps it)" >&2
      exit 1
    fi
  fi
fi

if [[ ! -x "$ANDROID_DIR/gradlew" ]]; then
  cat > "$ANDROID_DIR/gradlew" <<'GRADLEW'
#!/usr/bin/env sh
# Minimal launcher: prefer the checked-in wrapper, otherwise use system Gradle.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
if [ -s "$DIR/gradle/wrapper/gradle-wrapper.jar" ] && command -v java >/dev/null 2>&1; then
  exec java -classpath "$DIR/gradle/wrapper/gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain "$@"
fi
exec gradle "$@"
GRADLEW
  chmod +x "$ANDROID_DIR/gradlew"
  echo "Created android/gradlew"
fi

if [[ ! -x "$ANDROID_DIR/gradlew.bat" ]]; then
  cat > "$ANDROID_DIR/gradlew.bat" <<'GRADLEWBAT'
@rem Minimal Gradle launcher for Windows.
@echo off
set DIR=%~dp0
if exist "%DIR%gradle\wrapper\gradle-wrapper.jar" (
  java -classpath "%DIR%gradle\wrapper\gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain %*
) else (
  gradle %*
)
GRADLEWBAT
fi

echo "Android Gradle wrapper ready"
