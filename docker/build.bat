@echo off
REM =============================================
REM Stock App APK 编译脚本 (Windows)
REM 用法:
REM   第一次构建镜像: docker\build.bat
REM   之后只编译:     docker\build.bat build
REM =============================================

set ACTION=%1
if "%ACTION%"=="" set ACTION=full

if "%ACTION%"=="full" (
    echo Building Docker image...
    docker compose -f docker\docker-compose.yml build
) else if "%ACTION%"=="build" (
    echo Skipping image build...
)

echo Starting build...
docker compose -f docker\docker-compose.yml up --abort-on-container-exit

echo Done.
echo APK should be at: build\app\outputs\flutter-apk\app-debug.apk
pause
