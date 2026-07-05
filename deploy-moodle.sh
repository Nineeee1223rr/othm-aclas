#!/bin/bash
# Moodle 5.2.1 — minimal deploy for learn.aclas.global
set -e

HOST="learn.aclas.global"
DBPASS="88XtDtnlHW48JTx9SNVR"

echo "=== ACLAS Moodle ==="

# Clean
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm -f $(docker ps -aq) 2>/dev/null || true
rm -rf /opt/moodle 2>/dev/null || true
mkdir -p /opt/moodle/{db,moodledata,moodle}
chmod 777 /opt/moodle/moodledata

# Download Moodle
echo "Downloading Moodle 5.2..."
cd /opt/moodle/moodle
wget -q https://download.moodle.org/download.php/direct/stable502/moodle-latest-502.tgz
tar xzf moodle-latest-502.tgz --strip-components=1
rm moodle-latest-502.tgz
chown -R 1000:1000 /opt/moodle/moodle /opt/moodle/moodledata

# Docker compose
cat > /opt/moodle/docker-compose.yml << EOF
services:
  db:
    image: mariadb:10.6
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: ${DBPASS}
      MARIADB_DATABASE: moodle
      MARIADB_USER: moodleuser
      MARIADB_PASSWORD: ${DBPASS}
    volumes:
      - ./db:/var/lib/mysql
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 10

  moodle:
    image: moodlehq/moodle-php-apache:8.3
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      MOODLE_DOCKER_DBNAME: moodle
      MOODLE_DOCKER_DBUSER: moodleuser
      MOODLE_DOCKER_DBPASS: ${DBPASS}
      MOODLE_DOCKER_DBPORT: 3306
      MOODLE_DOCKER_DBHOST: db
      MOODLE_DOCKER_WWWROOT: https://${HOST}
      MOODLE_DOCKER_WEB_PORT: 80
    volumes:
      - ./moodle:/var/www/html
      - ./moodledata:/var/www/moodledata
    ports:
      - "127.0.0.1:8090:80"
EOF

# Start DB first
echo "Starting DB..."
cd /opt/moodle
docker compose up -d db
echo "Waiting for DB..."
sleep 15

# Run Moodle install
echo "Installing Moodle..."
docker compose run --rm -T moodle php admin/cli/install.php \
  --lang=en \
  --adminuser=aclasadmin \
  --adminpass='KbKgrXEayVd1EW3D' \
  --adminemail=admin@aclas.global \
  --agree-license \
  --fullname='ACLAS Global LMS' \
  --shortname=ACLAS \
  --wwwroot=https://${HOST} \
  --dbtype=mariadb \
  --dbhost=db \
  --dbname=moodle \
  --dbuser=moodleuser \
  --dbpass="${DBPASS}" \
  --dataroot=/var/www/moodledata \
  --non-interactive 2>&1 || echo "Install may need retry..."

# Start Moodle
echo "Starting Moodle..."
docker compose up -d

echo ""
echo "DONE! Visit: https://${HOST}"
echo "Admin: aclasadmin / KbKgrXEayVd1EW3D"
