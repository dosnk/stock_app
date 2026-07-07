# 🐳 Docker APK 编译指南

## 前置条件

- Docker 已安装并可运行（`docker ps` 能正常执行）
- 如果你没有 docker 权限，先执行：
  ```bash
  sudo usermod -aG docker $USER
  # 然后重新登录
  ```

## 首次使用（构建镜像 + 编译）

```bash
cd stock_app
docker compose -f docker/docker-compose.yml build
docker compose -f docker/docker-compose.yml up
```

或使用快捷脚本：
```bash
bash docker/build.sh
```

## 后续使用（只编译，不重新构建镜像）

```bash
docker compose -f docker/docker-compose.yml up
```

或：
```bash
bash docker/build.sh build
```

## 查看编译日志

```bash
docker compose -f docker/docker-compose.yml logs
# 或
docker logs stock-builder
```

## 查看进度（另一个终端）

```bash
docker compose -f docker/docker-compose.yml logs -f
```

## 编译产物

编译成功后 APK 在：
```
stock_app/build/app/outputs/flutter-apk/app-debug.apk
```

## 清理

```bash
docker compose -f docker/docker-compose.yml down
docker rmi stock-builder:latest  # 可选，删除镜像
```

## 手动运行（不修改 compose 文件）

```bash
docker run --rm -v /实际路径/stock_app:/app stock-builder:latest
```
