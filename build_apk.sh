#!/bin/bash
# ============================================
# 📈 股票交易助手 - APK 编译脚本
# ============================================
# 用法: 在有网络的 Linux/Mac 上运行
# 需要: Flutter SDK + Java 17+
# ============================================

set -e

echo "📦 股票交易助手 APK 编译脚本"
echo "=============================="
echo ""

# 1. 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ 未找到 Flutter，请先安装:"
    echo "   https://docs.flutter.dev/get-started/install"
    exit 1
fi

# 2. 检查 Java
if ! command -v java &> /dev/null; then
    echo "❌ 未找到 Java，请安装 JDK 17+"
    exit 1
fi

JAVA_VER=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | cut -d'.' -f1)
if [ "$JAVA_VER" -lt 17 ]; then
    echo "❌ Java 版本过低 ($JAVA_VER)，需要 17+"
    exit 1
fi

echo "✅ Flutter: $(flutter --version 2>&1 | head -1)"
echo "✅ Java: $(java -version 2>&1 | head -1)"
echo ""

# 3. 进入项目目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "📁 项目目录: $SCRIPT_DIR"
echo ""

# 4. 获取依赖
echo "📥 获取 Flutter 依赖..."
flutter pub get
echo ""

# 5. 接受 Android 许可（首次需要）
echo "📱 接受 Android SDK 许可..."
flutter doctor --android-licenses 2>/dev/null || true
echo ""

# 6. 编译 APK
echo "🔨 正在编译 Debug APK..."
echo "    首次编译会自动下载 Android SDK 和 Gradle，耗时较长"
echo ""
flutter build apk --debug

if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    echo ""
    echo "==========================================="
    echo "✅ APK 编译成功！"
    echo "📁 位置: build/app/outputs/flutter-apk/app-debug.apk"
    echo "📏 大小: $(ls -lh build/app/outputs/flutter-apk/app-debug.apk | awk '{print $5}')"
    echo "==========================================="
else
    echo ""
    echo "❌ APK 编译失败，请检查错误日志"
    exit 1
fi
