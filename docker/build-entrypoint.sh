#!/bin/bash
# =============================================
# Stock App APK 编译入口
# 挂载源码目录到 /app，自动编译 APK
# =============================================
set -e

echo "========================================="
echo "  Stock App APK Builder"
echo "========================================="
echo ""
echo "源码目录: /app"
echo ""

# 检查源码是否存在
if [ ! -f "/app/pubspec.yaml" ]; then
    echo "❌ 错误: /app 下找不到 pubspec.yaml"
    echo ""
    echo "请确保源码已挂载到 /app"
    echo "示例:"
    echo "  docker run -v /path/to/stock_app:/app stock-builder"
    echo ""
    exit 1
fi

cd /app

echo "📦 安装依赖..."
flutter pub get
echo ""

echo "🔨 开始编译 APK (debug)..."
echo ""
flutter build apk --debug

echo ""
echo "========================================="
echo "  ✅ 编译完成!"
echo "========================================="
echo ""
echo "APK 路径: /app/build/app/outputs/flutter-apk/app-debug.apk"
echo ""
ls -lh /app/build/app/outputs/flutter-apk/app-debug.apk 2>/dev/null
echo ""

# 编译完成，停止容器
exit 0
