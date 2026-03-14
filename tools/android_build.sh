#!/bin/bash

set -e

ROOT=${PWD}

if [ $# -lt 2 ]; then
  echo "Requires a path to the Android NDK and an SDK version number (optionally: target arch)"
  echo "Usage: android_build.sh <ndk_path> <sdk_version> [target_arch]"
  exit 1
fi

ANDROID_SDK_VERSION="$2"

SCRIPT_DIR="$(dirname "$BASH_SOURCE")"
cd "$SCRIPT_DIR"
SCRIPT_DIR=${PWD}

cd "$ROOT"
cd "$1"
ANDROID_NDK_PATH=${PWD}
cd "$SCRIPT_DIR"
cd ../

BUILD_ARCH() {
  echo "=== Building Node.js for $TARGET_ARCH (executable binary) ==="

  # Clean previous build
  make clean
  rm -rf android-toolchain/ out/ out_android/ 2>/dev/null || true

  # === 1. 设置工具链（关键修复）===
  TOOLCHAIN=$ANDROID_NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64

  if [ "$TARGET_ARCH" = "arm64" ]; then
    export CC="\( TOOLCHAIN/bin/aarch64-linux-android \){ANDROID_SDK_VERSION}-clang"
    export CXX="\( TOOLCHAIN/bin/aarch64-linux-android \){ANDROID_SDK_VERSION}-clang++"
    DEST_CPU="arm64"
    TARGET_ARCH_FOLDER="arm64-v8a"
  elif [ "$TARGET_ARCH" = "arm" ]; then
    export CC="\( TOOLCHAIN/bin/armv7a-linux-androideabi \){ANDROID_SDK_VERSION}-clang"
    export CXX="\( TOOLCHAIN/bin/armv7a-linux-androideabi \){ANDROID_SDK_VERSION}-clang++"
    DEST_CPU="arm"
    TARGET_ARCH_FOLDER="armeabi-v7a"
  elif [ "$TARGET_ARCH" = "x86_64" ]; then
    export CC="\( TOOLCHAIN/bin/x86_64-linux-android \){ANDROID_SDK_VERSION}-clang"
    export CXX="\( TOOLCHAIN/bin/x86_64-linux-android \){ANDROID_SDK_VERSION}-clang++"
    DEST_CPU="x64"
    TARGET_ARCH_FOLDER="x86_64"
  elif [ "$TARGET_ARCH" = "x86" ]; then
    export CC="\( TOOLCHAIN/bin/i686-linux-android \){ANDROID_SDK_VERSION}-clang"
    export CXX="\( TOOLCHAIN/bin/i686-linux-android \){ANDROID_SDK_VERSION}-clang++"
    DEST_CPU="ia32"
    TARGET_ARCH_FOLDER="x86"
  else
    echo "Unsupported architecture: $TARGET_ARCH"
    exit 1
  fi

  export AR="$TOOLCHAIN/bin/llvm-ar"
  export NM="$TOOLCHAIN/bin/llvm-nm"
  export AS="$CC"

  export GYP_DEFINES="target_arch=$DEST_CPU v8_target_arch=$DEST_CPU android_target_arch=$DEST_CPU host_os=linux OS=android android_ndk_path=$ANDROID_NDK_PATH openssl_no_asm=1"

  echo "✅ CC = $CC"
  echo "✅ DEST_CPU = $DEST_CPU"

  # === 2. 执行 Configure（不带 --shared，生成可执行文件）===
  ./configure \
    --dest-cpu=$DEST_CPU \
    --dest-os=android \
    --cross-compiling \
    --openssl-no-asm \
    --without-intl \
    --without-snapshot

  # === 3. 编译 ===
  make -j$(getconf _NPROCESSORS_ONLN)

  # === 4. 复制二进制文件（关键修改：不再复制 .so）===
  mkdir -p "out_android/$TARGET_ARCH_FOLDER/"
  if [ -f "out/Release/node" ]; then
    cp "out/Release/node" "out_android/$TARGET_ARCH_FOLDER/node"
    chmod +x "out_android/$TARGET_ARCH_FOLDER/node"
    echo "🎉 构建成功！可执行二进制文件已生成："
    echo "    out_android/$TARGET_ARCH_FOLDER/node"
    ls -lh "out_android/$TARGET_ARCH_FOLDER/node"
  else
    echo "❌ 未找到 out/Release/node，请检查 configure/make 输出"
    exit 1
  fi
}

# 默认只构建 arm64（最常用）
if [ $# -eq 2 ]; then
  TARGET_ARCH="arm64"
  BUILD_ARCH
else
  TARGET_ARCH=$3
  BUILD_ARCH
fi

# （可选）如果你还需要头文件，保留下面这行
# source $SCRIPT_DIR/copy_libnode_headers.sh android

cd "$ROOT"
