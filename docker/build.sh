#!/bin/bash
# =============================================
# Stock App APK 编译脚本
# 用法:
#   第一次构建镜像: ./docker/build.sh
#   之后只编译:     ./docker/build.sh build
# =============================================
set -e

cd "$(dirname "$0")/.."

ACTION="${1:-full}"

if [ "$ACTION" = "full" ] || [ "$ACTION" = "image" ]; then
    echo "🔨 构建 Docker 镜像..."
    docker compose -f docker/docker-compose.yml build
    echo ""
fi

echo "🚀 启动编译..."
docker compose -f docker/docker-compose.yml up --abort-on-container-exit

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "  ✅ 编译成功!"
    echo "========================================="
    echo ""
    APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
    ls -lh "$APK_PATH"
    echo ""
    echo "APK 位置: $(pwd)/$APK_PATH"
else
    echo ""
    echo "❌ 编译失败，退出码: $EXIT_CODE"
    echo "查看日志: docker logs stock-builder"
fi

exit $EXIT_CODE
