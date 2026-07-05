#!/bin/bash
# ============================================================
# Moodle LMS 部署脚本 for learn.aclas.global
# 在 VPS 上以 root 身份运行: bash deploy.sh
# ============================================================
set -e

# ---- 配置 (可修改) ----
MOODLE_SITE="ACLAS Global LMS"
MOODLE_HOST="learn.aclas.global"
MOODLE_ADMIN="aclasadmin"
MOODLE_ADMIN_EMAIL="admin@aclas.global"
MOODLE_ADMIN_PASS="KbKgrXEayVd1EW3D"
DB_ROOT_PASS="vSBoY35wWRRWIRNfsLnB"
DB_MOODLE_PASS="88XtDtnlHW48JTx9SNVR"

echo "========================================"
echo " ACLAS Moodle Deployment"
echo " Site: ${MOODLE_HOST}"
echo "========================================"

# ---- 1. 清理旧环境 ----
echo ""
echo "[1/6] Cleaning old environment..."
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
docker system prune -af 2>/dev/null || true
rm -rf /opt/moodle 2>/dev/null || true
echo "  Done."

# ---- 2. 创建目录结构 ----
echo ""
echo "[2/6] Creating directories..."
mkdir -p /opt/moodle/{mariadb,moodle,moodledata,redis}
chmod -R 777 /opt/moodle/moodledata
echo "  Done."

# ---- 3. Docker Compose ----
echo ""
echo "[3/6] Writing docker-compose.yml..."
cat > /opt/moodle/docker-compose.yml << 'DOCKEREOF'
version: '3.8'

services:
  mariadb:
    image: bitnami/mariadb:11.4
    container_name: moodle-db
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASS}
      MARIADB_DATABASE: bitnami_moodle
      MARIADB_USER: bn_moodle
      MARIADB_PASSWORD: ${DB_MOODLE_PASS}
    volumes:
      - ./mariadb:/bitnami/mariadb
    networks:
      - moodle-net
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  moodle:
    image: bitnami/moodle:4.5
    container_name: moodle-app
    restart: unless-stopped
    depends_on:
      mariadb:
        condition: service_healthy
    environment:
      MOODLE_DATABASE_HOST: mariadb
      MOODLE_DATABASE_PORT_NUMBER: 3306
      MOODLE_DATABASE_USER: bn_moodle
      MOODLE_DATABASE_NAME: bitnami_moodle
      MOODLE_DATABASE_PASSWORD: ${DB_MOODLE_PASS}
      MOODLE_SITE_NAME: "${MOODLE_SITE}"
      MOODLE_USERNAME: ${MOODLE_ADMIN}
      MOODLE_PASSWORD: ${MOODLE_ADMIN_PASS}
      MOODLE_EMAIL: ${MOODLE_ADMIN_EMAIL}
      MOODLE_HOST: ${MOODLE_HOST}
      MOODLE_SKIP_BOOTSTRAP: "no"
      PHP_MEMORY_LIMIT: 256M
      PHP_MAX_EXECUTION_TIME: 300
      PHP_POST_MAX_SIZE: 128M
      PHP_UPLOAD_MAX_FILESIZE: 128M
    volumes:
      - ./moodle:/bitnami/moodle
      - ./moodledata:/bitnami/moodledata
    networks:
      - moodle-net
    ports:
      - "127.0.0.1:8080:8080"
      - "127.0.0.1:8443:8443"

  redis:
    image: redis:7-alpine
    container_name: moodle-redis
    restart: unless-stopped
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - ./redis:/data
    networks:
      - moodle-net

networks:
  moodle-net:
    driver: bridge
DOCKEREOF

# 替换变量
sed -i "s|\${DB_ROOT_PASS}|${DB_ROOT_PASS}|g" /opt/moodle/docker-compose.yml
sed -i "s|\${DB_MOODLE_PASS}|${DB_MOODLE_PASS}|g" /opt/moodle/docker-compose.yml
sed -i "s|\${MOODLE_SITE}|${MOODLE_SITE}|g" /opt/moodle/docker-compose.yml
sed -i "s|\${MOODLE_ADMIN}|${MOODLE_ADMIN}|g" /opt/moodle/docker-compose.yml
sed -i "s|\${MOODLE_ADMIN_PASS}|${MOODLE_ADMIN_PASS}|g" /opt/moodle/docker-compose.yml
sed -i "s|\${MOODLE_ADMIN_EMAIL}|${MOODLE_ADMIN_EMAIL}|g" /opt/moodle/docker-compose.yml
sed -i "s|\${MOODLE_HOST}|${MOODLE_HOST}|g" /opt/moodle/docker-compose.yml

echo "  Done."

# ---- 4. 启动容器 ----
echo ""
echo "[4/6] Starting containers (this takes 3-5 minutes on first run)..."
cd /opt/moodle
docker compose up -d

echo "  Waiting for Moodle to be ready..."
for i in $(seq 1 60); do
    if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080 2>/dev/null | grep -q "200\|302\|303"; then
        echo "  Moodle is ready! (took ${i}x5s)"
        break
    fi
    echo -n "."
    sleep 5
done

# ---- 5. Nginx + SSL ----
echo ""
echo "[5/6] Configuring Nginx + SSL..."
cat > /etc/nginx/conf.d/learn.aclas.global.conf << 'NGINXEOF'
server {
    listen 80;
    server_name learn.aclas.global;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name learn.aclas.global;

    ssl_certificate     /etc/letsencrypt/live/learn.aclas.global/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/learn.aclas.global/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;

    client_max_body_size 128M;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_buffering off;
        proxy_read_timeout 300s;
    }
}
NGINXEOF

# 获取 SSL 证书 (先确保 Nginx 80 端口能通过防火墙)
firewall-cmd --add-service=http --permanent 2>/dev/null || true
firewall-cmd --add-service=https --permanent 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true

# 启动 Nginx 80 先（没有 SSL cert 的话）
if [ ! -f /etc/letsencrypt/live/learn.aclas.global/fullchain.pem ]; then
    # 临时配置仅 80 端口来通过 certbot 验证
    cat > /etc/nginx/conf.d/learn.aclas.global.conf << 'NGINEXTMP'
server {
    listen 80;
    server_name learn.aclas.global;
    root /usr/share/nginx/html;
}
NGINEXTMP
    
    systemctl enable nginx 2>/dev/null || true
    systemctl restart nginx 2>/dev/null || nginx
    
    certbot --nginx -d learn.aclas.global --non-interactive --agree-tos --email admin@aclas.global
    
    # 恢复完整配置
    cat > /etc/nginx/conf.d/learn.aclas.global.conf << 'NGINXEOF'
server {
    listen 80;
    server_name learn.aclas.global;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name learn.aclas.global;

    ssl_certificate     /etc/letsencrypt/live/learn.aclas.global/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/learn.aclas.global/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;

    client_max_body_size 128M;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_buffering off;
        proxy_read_timeout 300s;
    }
}
NGINXEOF
fi

# 重启 Nginx
nginx -t && systemctl restart nginx 2>/dev/null || nginx -s reload
echo "  Done."

# ---- 6. 定时备份 ----
echo ""
echo "[6/6] Setting up daily backup cron..."
cat > /opt/moodle/backup.sh << 'BACKUPEOF'
#!/bin/bash
BACKUP_DIR=/opt/moodle/backups
mkdir -p $BACKUP_DIR
DATE=$(date +%Y%m%d_%H%M)
cd /opt/moodle
docker compose exec -T mariadb mysqldump -u root --password="${DB_ROOT_PASS}" bitnami_moodle | gzip > "$BACKUP_DIR/moodle_db_$DATE.sql.gz"
tar -czf "$BACKUP_DIR/moodledata_$DATE.tar.gz" -C /opt/moodle moodledata 2>/dev/null
# 保留最近 7 天的备份
find $BACKUP_DIR -type f -mtime +7 -delete
BACKUPEOF
sed -i "s|\${DB_ROOT_PASS}|${DB_ROOT_PASS}|g" /opt/moodle/backup.sh
chmod +x /opt/moodle/backup.sh

# 每天凌晨 3 点备份
(crontab -l 2>/dev/null; echo "0 3 * * * /opt/moodle/backup.sh >> /var/log/moodle_backup.log 2>&1") | crontab -
echo "  Done."

# ---- 完成 ----
echo ""
echo "========================================"
echo "  DEPLOYMENT COMPLETE!"
echo "========================================"
echo ""
echo "  Moodle URL:  https://${MOODLE_HOST}"
echo "  Admin user:  ${MOODLE_ADMIN}"
echo "  Admin pass:  ${MOODLE_ADMIN_PASS}"
echo ""
echo "  ⚠️  Before accessing:"
echo "     1. Add DNS A record in Cloudflare:"
echo "        ${MOODLE_HOST}  →  192.129.159.23"
echo "     2. Login and change the admin password"
echo "========================================"
