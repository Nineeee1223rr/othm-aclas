#!/bin/bash
# ============================================================
# Moodle 5.2.1 部署 for learn.aclas.global (AlmaLinux 8)
# ============================================================
set -e

MOODLE_HOST="learn.aclas.global"
MOODLE_SITE="ACLAS Global LMS"
MOODLE_ADMIN="aclasadmin"
MOODLE_ADMIN_EMAIL="admin@aclas.global"
MOODLE_ADMIN_PASS="KbKgrXEayVd1EW3D"
DB_ROOT_PASS="vSBoY35wWRRWIRNfsLnB"
DB_MOODLE_PASS="88XtDtnlHW48JTx9SNVR"

echo "========================================"
echo " ACLAS Moodle 5.2 Deployment"
echo " Site: ${MOODLE_HOST}"
echo "========================================"

# ---- 1. Stop any old stuff ----
echo "[1] Stopping old services..."
systemctl stop httpd nginx 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm -f $(docker ps -aq) 2>/dev/null || true
rm -rf /opt/moodle 2>/dev/null || true
mkdir -p /opt/moodle/{db,moodledata}
echo "  Done."

# ---- 2. Docker Compose ----
echo "[2] Creating docker-compose.yml..."
cat > /opt/moodle/docker-compose.yml << 'DOCKEREOF'
services:
  db:
    image: mariadb:10.6
    container_name: moodle-db
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASS}
      MARIADB_DATABASE: moodle
      MARIADB_USER: moodleuser
      MARIADB_PASSWORD: ${DB_MOODLE_PASS}
    volumes:
      - ./db:/var/lib/mysql
    networks:
      - moodle-net
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 10

  moodle:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: moodle-app
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      MOODLE_DB_HOST: db
      MOODLE_DB_NAME: moodle
      MOODLE_DB_USER: moodleuser
      MOODLE_DB_PASS: ${DB_MOODLE_PASS}
      MOODLE_URL: https://${MOODLE_HOST}
      MOODLE_SITE_NAME: ${MOODLE_SITE}
      MOODLE_ADMIN: ${MOODLE_ADMIN}
      MOODLE_ADMIN_PASS: ${MOODLE_ADMIN_PASS}
      MOODLE_ADMIN_EMAIL: ${MOODLE_ADMIN_EMAIL}
    volumes:
      - ./moodledata:/var/www/moodledata
    networks:
      - moodle-net
    ports:
      - "127.0.0.1:8090:80"

networks:
  moodle-net:
DOCKEREOF

# ---- 3. Moodle Dockerfile ----
echo "[3] Creating Dockerfile..."
cat > /opt/moodle/Dockerfile << 'DOCKEREOF'
FROM php:8.2-apache

RUN apt-get update && apt-get install -y --no-install-recommends \
    libzip-dev libxml2-dev libpng-dev libjpeg-dev libfreetype6-dev \
    libicu-dev libxslt-dev libldap2-dev cron wget unzip mariadb-client \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) zip xml intl mbstring curl gd soap opcache mysqli pgsql \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

RUN cd /var/www && \
    wget -q https://download.moodle.org/download.php/direct/stable502/moodle-latest-502.tgz && \
    tar xzf moodle-latest-502.tgz && \
    rm moodle-latest-502.tgz && \
    mkdir -p /var/www/moodledata && chmod 777 /var/www/moodledata && \
    chown -R www-data:www-data /var/www/moodle

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN { \
    echo 'file_uploads = On'; \
    echo 'memory_limit = 256M'; \
    echo 'post_max_size = 128M'; \
    echo 'upload_max_filesize = 128M'; \
    echo 'max_execution_time = 300'; \
    echo 'max_input_vars = 5000'; \
} > /usr/local/etc/php/conf.d/moodle.ini

RUN echo "<VirtualHost *:80>\n    DocumentRoot /var/www/moodle\n    <Directory /var/www/moodle>\n        AllowOverride All\n        Require all granted\n    </Directory>\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
DOCKEREOF

# ---- 4. Entrypoint (auto-install) ----
echo "[4] Creating entrypoint script..."
cat > /opt/moodle/entrypoint.sh << 'ENTRYEOF'
#!/bin/bash
set -e

echo "Waiting for database..."
until mysqladmin ping -h "$MOODLE_DB_HOST" --silent 2>/dev/null; do
    sleep 2
done

cd /var/www/moodle

# Auto-install if not already done
if [ ! -f /var/www/moodledata/installed ]; then
    echo "Installing Moodle..."
    php admin/cli/install_database.php \
        --lang=en \
        --adminuser="$MOODLE_ADMIN" \
        --adminpass="$MOODLE_ADMIN_PASS" \
        --adminemail="$MOODLE_ADMIN_EMAIL" \
        --agree-license \
        --fullname="$MOODLE_SITE_NAME" \
        --shortname="ACLAS" \
        --wwwroot="$MOODLE_URL" \
        --dbtype=mariadb \
        --dbhost="$MOODLE_DB_HOST" \
        --dbname="$MOODLE_DB_NAME" \
        --dbuser="$MOODLE_DB_USER" \
        --dbpass="$MOODLE_DB_PASS" 2>/dev/null || {
        # If install_database fails, try install.php
        php admin/cli/install.php \
            --lang=en \
            --adminuser="$MOODLE_ADMIN" \
            --adminpass="$MOODLE_ADMIN_PASS" \
            --adminemail="$MOODLE_ADMIN_EMAIL" \
            --agree-license \
            --fullname="$MOODLE_SITE_NAME" \
            --shortname="ACLAS" \
            --wwwroot="$MOODLE_URL" \
            --dbtype=mariadb \
            --dbhost="$MOODLE_DB_HOST" \
            --dbname="$MOODLE_DB_NAME" \
            --dbuser="$MOODLE_DB_USER" \
            --dbpass="$MOODLE_DB_PASS" \
            --dataroot=/var/www/moodledata \
            --non-interactive
    }
    touch /var/www/moodledata/installed
    echo "Moodle installed!"
fi

exec "$@"
ENTRYEOF

# Substitute passwords in compose file
sed -i "s|\${DB_ROOT_PASS}|${DB_ROOT_PASS}|g" /opt/moodle/docker-compose.yml
sed -i "s|\${DB_MOODLE_PASS}|${DB_MOODLE_PASS}|g" /opt/moodle/docker-compose.yml
sed -i "s|\${MOODLE_HOST}|${MOODLE_HOST}|g" /opt/moodle/docker-compose.yml
sed -i "s|\${MOODLE_SITE}|${MOODLE_SITE}|g" /opt/moodle/docker-compose.yml
sed -i "s|\${MOODLE_ADMIN}|${MOODLE_ADMIN}|g" /opt/moodle/docker-compose.yml
sed -i "s|\${MOODLE_ADMIN_PASS}|${MOODLE_ADMIN_PASS}|g" /opt/moodle/docker-compose.yml
sed -i "s|\${MOODLE_ADMIN_EMAIL}|${MOODLE_ADMIN_EMAIL}|g" /opt/moodle/docker-compose.yml

# ---- 5. Build & Start ----
echo "[5] Building Moodle image (3-5 min)..."
cd /opt/moodle
docker compose build --no-cache 2>&1 | tail -5
echo "[6] Starting containers..."
docker compose up -d

echo ""
echo "========================================"
echo "  Moodle is starting up!"
echo "  Check: https://${MOODLE_HOST}"
echo "  Admin: ${MOODLE_ADMIN} / ${MOODLE_ADMIN_PASS}"
echo "========================================"
