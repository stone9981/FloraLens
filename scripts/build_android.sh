#!/usr/bin/env bash
# 一键构建 Android 包。
#
# 用法:
#   ./scripts/build_android.sh            # release，按 ABI 拆包
#   ./scripts/build_android.sh debug      # debug 包
#   ./scripts/build_android.sh appbundle  # 上架用 AAB
#
# 环境变量（在本机已装好 Flutter/Android SDK 时可自动探测）:
#   FLUTTER_HOME / JAVA_HOME / ANDROID_HOME / PUB_HOSTED_URL
set -euo pipefail

MODE="${1:-release}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- 环境探测 ---
if [ -z "${FLUTTER_HOME:-}" ]; then
  for c in "$HOME/development/flutter" "$HOME/flutter" "/opt/flutter" "/usr/local/flutter"; do
    if [ -x "$c/bin/flutter" ]; then FLUTTER_HOME="$c"; break; fi
  done
fi
if [ -z "${FLUTTER_HOME:-}" ] && command -v flutter >/dev/null 2>&1; then
  FLUTTER_HOME="$(dirname "$(dirname "$(command -v flutter)")")"
fi
if [ -z "${FLUTTER_HOME:-}" ]; then
  echo "找不到 Flutter SDK，请设置 FLUTTER_HOME，或先运行 scripts/setup_env.sh" >&2
  exit 1
fi

if [ -z "${JAVA_HOME:-}" ]; then
  if [ -x /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/bin/java ]; then
    JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
  elif [ -x /usr/libexec/java_home ]; then
    JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
  fi
fi

if [ -z "${ANDROID_HOME:-}" ]; then
  ANDROID_HOME="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
  [ -d "$ANDROID_HOME" ] || ANDROID_HOME="$HOME/Android/Sdk"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
[ -n "${JAVA_HOME:-}" ] && export JAVA_HOME
export ANDROID_HOME
# 国内网络下走镜像，境外可删掉这两行
export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://mirrors.tencent.com/dart-pub}"
export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://mirrors.tencent.com/flutter}"

echo "Flutter : $FLUTTER_HOME"
echo "Java    : ${JAVA_HOME:-auto}"
echo "Android : $ANDROID_HOME"
echo "Mode    : $MODE"
echo "----------------------------------------"

cd "$PROJECT_DIR"
flutter pub get

case "$MODE" in
  debug)
    flutter build apk --debug
    ;;
  appbundle)
    flutter build appbundle --release
    ;;
  release)
    flutter build apk --release --split-per-abi
    ;;
  *)
    echo "未知模式: $MODE（可选 debug | release | appbundle）" >&2
    exit 2
    ;;
esac

echo "----------------------------------------"
echo "产物："
find build/app/outputs -name "*.apk" -o -name "*.aab" 2>/dev/null | sed 's/^/  /' || true
