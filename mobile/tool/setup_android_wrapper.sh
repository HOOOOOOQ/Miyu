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
  fetched=0
  for url in \
    "https://github.com/gradle/gradle/raw/v${GRADLE_VERSION}.0/gradle/wrapper/gradle-wrapper.jar" \
    "https://raw.githubusercontent.com/gradle/gradle/v${GRADLE_VERSION}.0/gradle/wrapper/gradle-wrapper.jar" \
    "https://github.com/gradle/gradle/raw/v${GRADLE_VERSION}/gradle/wrapper/gradle-wrapper.jar"; do
    if curl -fsSL --retry 2 --retry-delay 2 --max-time 60 -o "$JAR.part" "$url"; then
      mv "$JAR.part" "$JAR"; fetched=1; echo "  ok: $url"; break
    fi
    echo "  miss: $url"
  done
  rm -f "$JAR.part"

  if [[ "$fetched" -ne 1 ]]; then
    # Fallback 1: the Flutter SDK ships a wrapper jar in its artifact cache.
    FLUTTER_ROOT_GUESS="${FLUTTER_ROOT:-$(dirname "$(dirname "$(command -v flutter 2>/dev/null || echo /nonexistent/flutter)")")}"
    for candidate in \
      "$FLUTTER_ROOT_GUESS/bin/cache/artifacts/gradle_wrapper/gradle/wrapper/gradle-wrapper.jar" \
      "$HOME/flutter/bin/cache/artifacts/gradle_wrapper/gradle/wrapper/gradle-wrapper.jar"; do
      if [[ -s "$candidate" ]]; then
        cp "$candidate" "$JAR"
        echo "  copied from Flutter cache: $candidate"
        fetched=1
        break
      fi
    done
  fi

  if [[ "$fetched" -ne 1 ]]; then
    # Fallback 2: a locally installed Gradle can generate the wrapper itself.
    if command -v gradle >/dev/null 2>&1; then
      echo "Download failed; generating the wrapper with local Gradle"
      (cd "$ANDROID_DIR" && gradle wrapper --gradle-version "$GRADLE_VERSION")
    else
      # Not fatal: `flutter build apk` injects its own bundled wrapper when
      # gradle/wrapper/gradle-wrapper.jar is missing.
      echo "::warning::Could not fetch gradle-wrapper.jar; Flutter will inject its bundled wrapper." 
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
