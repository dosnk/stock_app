# =============================================
# Stock App APK 编译器
# 基于 Ubuntu + Flutter + Android SDK
# =============================================
FROM ubuntu:22.04

LABEL description="Stock App APK Builder"
LABEL maintainer="atrader"

ENV DEBIAN_FRONTEND=noninteractive

# 基础工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-17-jdk-headless \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 设置 JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# 下载 Flutter SDK
ENV FLUTTER_VERSION=3.27.4
ENV FLUTTER_HOME=/opt/flutter
RUN cd /opt && \
    wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz && \
    tar xf flutter_linux_${FLUTTER_VERSION}-stable.tar.xz && \
    rm flutter_linux_${FLUTTER_VERSION}-stable.tar.xz && \
    flutter config --no-analytics

ENV PATH=$FLUTTER_HOME/bin:$PATH

# 下载 Android SDK 命令行工具
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
RUN mkdir -p $ANDROID_SDK_ROOT/cmdline-tools && \
    cd /tmp && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip && \
    unzip -q commandlinetools-linux-11076708_latest.zip -d /tmp/cmdline-tools && \
    mv /tmp/cmdline-tools/cmdline-tools $ANDROID_SDK_ROOT/cmdline-tools/latest && \
    rm /tmp/commandlinetools-linux-11076708_latest.zip && \
    rm -rf /tmp/cmdline-tools

ENV PATH=$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH

# 安装 Android SDK 组件
RUN yes | sdkmanager --sdk_root=$ANDROID_SDK_ROOT \
    "platforms;android-34" \
    "build-tools;34.0.0" \
    "platform-tools" \
    "cmdline-tools;latest"

# 设置 Gradle 国内镜像
ENV GRADLE_OPTS="-Dorg.gradle.daemon=false"
RUN mkdir -p ~/.gradle/init.d && \
    echo 'allprojects { buildscript { repositories { maven { url "https://maven.aliyun.com/repository/public" } maven { url "https://maven.aliyun.com/repository/google" } } } repositories { maven { url "https://maven.aliyun.com/repository/public" } maven { url "https://maven.aliyun.com/repository/google" } } }' > ~/.gradle/init.d/mirrors.gradle

# 验证 flutter
RUN flutter doctor --android-licenses 2>&1 | tail -3
RUN flutter doctor 2>&1

WORKDIR /app

COPY build-entrypoint.sh /build-entrypoint.sh
RUN chmod +x /build-entrypoint.sh

ENTRYPOINT ["/build-entrypoint.sh"]
