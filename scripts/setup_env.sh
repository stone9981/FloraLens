#!/usr/bin/env bash
# 在本机从零搭一套 Flutter + Android 构建环境（macOS）。
#
# 用法: ./scripts/setup_env.sh
#
# 默认装到：
#   Flutter      ~/development/flutter
#   Android SDK  ~/Library/Android/sdk
#   JDK 17       通过 Homebrew（brew install openjdk@17）
#
# 国内网络默认走腾讯/阿里云镜像，境外请把脚本里的镜像变量改回官方地址。
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.5}"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/development/flutter}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
MIRROR="${MIRROR:-https://mirrors.tencent.com/flutter}"

case "$(uname -m)" in
  arm64) ARCH="arm64" ;;
  *)     ARCH="x64" ;;
esac

echo "==> 1/4 安装 JDK 17"
if ! command -v brew >/dev/null 2>&1; then
  echo "未检测到 Homebrew，请手动安装 JDK 17 后重跑本脚本" >&2
else
  brew list openjdk@17 >/dev/null 2>&1 || brew install --formula openjdk@17
  JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
  export JAVA_HOME
  echo "JAVA_HOME=$JAVA_HOME"
fi

echo "==> 2/4 下载 Flutter $FLUTTER_VERSION"
if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  mkdir -p "$(dirname "$FLUTTER_HOME")"
  TMP="$(mktemp -d)"
  ZIP="$TMP/flutter.zip"
  curl -fL --retry 3 -o "$ZIP" \
    "$MIRROR/flutter_infra_release/releases/stable/macos/flutter_macos_${ARCH}_${FLUTTER_VERSION}-stable.zip"
  unzip -q "$ZIP" -d "$(dirname "$FLUTTER_HOME")"
  rm -rf "$TMP"
fi
export PATH="$FLUTTER_HOME/bin:$PATH"
flutter --version

echo "==> 3/4 安装 Android SDK 组件"
mkdir -p "$ANDROID_HOME/cmdline-tools"
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
  TMP="$(mktemp -d)"
  curl -fL -o "$TMP/cmdline.zip" \
    "https://dl.google.com/android/repository/commandlinetools-mac-11479570_latest.zip"
  unzip -q "$TMP/cmdline.zip" -d "$ANDROID_HOME/cmdline-tools"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm -rf "$TMP"
fi
yes 2>/dev/null | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
  --sdk_root="$ANDROID_HOME" \
  platform-tools platforms\;android-36 platforms\;android-35 \
  build-tools\;36.0.0 build-tools\;35.0.0

echo "==> 4/4 同意 Android 许可并写入 shell 配置"
flutter doctor --android-licenses || true

SHELL_RC="$HOME/.zshrc"
[ -n "${BASH_VERSION:-}" ] && SHELL_RC="$HOME/.bash_profile"
{
  echo ''
  echo '# --- FloraLens / Flutter toolchain ---'
  echo "export FLUTTER_HOME=\"$FLUTTER_HOME\""
  echo 'export PATH="$FLUTTER_HOME/bin:$PATH"'
  echo "export ANDROID_HOME=\"$ANDROID_HOME\""
  echo "export JAVA_HOME=\"${JAVA_HOME:-}\""
  echo 'export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://mirrors.tencent.com/dart-pub}"'
  echo 'export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://mirrors.tencent.com/flutter}"'
} >> "$SHELL_RC"

echo
echo "环境就绪。请执行："
echo "  source $SHELL_RC"
echo "  flutter doctor -v"
echo "  ./scripts/build_android.sh release"
