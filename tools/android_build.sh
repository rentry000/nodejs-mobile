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
  echo "=== Building for $TARGET_ARCH ==="

  # Clean previous compilation
  make clean || true
  rm -rf android-toolchain/ 2>/dev/null || true

  # Compile
  eval '"./android-configure" "$ANDROID_NDK_PATH" $ANDROID_SDK_VERSION $TARGET_ARCH'
  make -j $(getconf _NPROCESSORS_ONLN)

  # Determine output folder name
  TARGET_ARCH_FOLDER="$TARGET_ARCH"
  if [ "$TARGET_ARCH_FOLDER" == "arm" ]; then
    TARGET_ARCH_FOLDER="armeabi-v7a"
  elif [ "$TARGET_ARCH_FOLDER" == "arm64" ]; then
    TARGET_ARCH_FOLDER="arm64-v8a"
  fi

  mkdir -p "out_android/$TARGET_ARCH_FOLDER/"

  # ────────────────────────────────────────────────
  # 查找并复制 libnode.so（如果存在）
  # ────────────────────────────────────────────────
  SO_FOUND=0
  for SO_FILE in \
    "out/Release/lib.target/libnode.so" \
    "out/Release/obj.target/libnode.so" \
    "out/Release/libnode.so"; do
    if [ -f "$SO_FILE" ]; then
      cp "$SO_FILE" "out_android/$TARGET_ARCH_FOLDER/libnode.so"
      echo "Copied shared library: out_android/$TARGET_ARCH_FOLDER/libnode.so"
      SO_FOUND=1
      break
    fi
  done

  if [ $SO_FOUND -eq 0 ]; then
    echo "Warning: No libnode.so found in common locations"
  fi

  # ────────────────────────────────────────────────
  # 查找并复制 node 可执行文件（如果存在）
  # ────────────────────────────────────────────────
  NODE_FOUND=0
  for NODE_FILE in \
    "out/Release/node" \
    "out/Release/node.exe" \
    "out/node"; do
    if [ -f "$NODE_FILE" ]; then
      cp "$NODE_FILE" "out_android/$TARGET_ARCH_FOLDER/node"
      chmod +x "out_android/$TARGET_ARCH_FOLDER/node" 2>/dev/null || true
      echo "Copied executable: out_android/$TARGET_ARCH_FOLDER/node"
      NODE_FOUND=1

      # 额外输出文件信息，便于确认
      file "out_android/$TARGET_ARCH_FOLDER/node" 2>/dev/null || true
      ls -lh "out_android/$TARGET_ARCH_FOLDER/node" 2>/dev/null || true
      break
    fi
  done

  if [ $NODE_FOUND -eq 0 ]; then
    echo "Warning: No node executable found in common locations"
  fi

  # 如果两种文件都没找到，报错退出（可选，根据需求可注释掉）
  if [ $SO_FOUND -eq 0 ] && [ $NODE_FOUND -eq 0 ]; then
    echo "Error: No output binary or shared library found after build"
    exit 1
  fi
}

# ────────────────────────────────────────────────
# 执行构建
# ────────────────────────────────────────────────
if [ $# -eq 2 ]; then
  TARGET_ARCH="arm"
  BUILD_ARCH
  # TARGET_ARCH="x86"
  # BUILD_ARCH
  TARGET_ARCH="arm64"
  BUILD_ARCH
  TARGET_ARCH="x86_64"
  BUILD_ARCH
else
  TARGET_ARCH=$3
  BUILD_ARCH
fi

source $SCRIPT_DIR/copy_libnode_headers.sh android 2>/dev/null || true

cd "$ROOT"

echo ""
echo "Build completed."
echo "Check folder: out_android/"
ls -R out_android/ 2>/dev/null || true
