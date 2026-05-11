#!/bin/bash
# ============================================================
# MOODLE SETUP - TKJ SMKN 1 TUREN
# Cara pakai: bash moodle.sh
# Yang manual dulu sebelum jalanin ini:
#   1. /etc/network/interfaces (IP static)
#   2. SSH (PermitRootLogin yes)
#   3. /etc/apt/sources.list (trusted=yes cdrom)
#   4. apt-cdrom add DVD1 & DVD2
# ============================================================

echo "=== MOODLE SETUP - TKJ SMKN 1 TUREN ==="

# ============================================================
# 1. INSTALL SEMUA PAKET
# ============================================================
echo "[1/6] Install paket..."
apt install -y bind9 bind9-dnsutils dns-root-data apache2 libapache2-mod-php mariadb-server php8.2 php8.2-cli php8.2-curl php8.2-zip php8.2-gd php8.2-xml php8.2-intl php8.2-mbstring php8.2-soap php8.2-ldap php8.2-mysql php8.2-bcmath zip

# ============================================================
# 2. DNS - named.conf.local
# ============================================================
echo "[2/6] Konfigurasi DNS..."

cat > /etc/bind/named.conf.local << 'EOF'
zone "ujiankolaborasi.net" {
    type master;
    file "/etc/bind/db.domain";
};
zone "56.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.ip";
};
EOF

cp /etc/bind/db.local /etc/bind/db.domain
cp /etc/bind/db.127 /etc/bind/db.ip

cat > /etc/bind/db.domain << 'EOF'
$TTL    604800
@   IN  SOA ujiankolaborasi.net. root.ujiankolaborasi.net. (
                2 ; Serial
           604800 ; Refresh
            86400 ; Retry
          2419200 ; Expire
           604800 ) ; Negative Cache TTL
;
@   IN  NS  ujiankolaborasi.net.
@   IN  A   192.168.56.10
www IN  A   192.168.56.10
EOF

cat > /etc/bind/db.ip << 'EOF'
$TTL    604800
@   IN  SOA ujiankolaborasi.net. root.ujiankolaborasi.net. (
                1 ; Serial
           604800 ; Refresh
            86400 ; Retry
          2419200 ; Expire
           604800 ) ; Negative Cache TTL
;
@   IN  NS  ujiankolaborasi.net.
10  IN  PTR ujiankolaborasi.net.
10  IN  PTR www.ujiankolaborasi.net.
EOF

systemctl restart named.service
echo "    DNS OK"

# ============================================================
# 3. APACHE - 000-default.conf
# ============================================================
echo "[3/6] Konfigurasi Apache..."

a2enmod rewrite setenvif -q

cat > /etc/apache2/sites-available/000-default.conf << 'EOF'
<VirtualHost *:80>
    ServerName ujiankolaborasi.net
    ServerAlias www.ujiankolaborasi.net
    ServerAdmin webmaster@localhost
    DocumentRoot /home/moodle

    <Directory /home/moodle>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php index.html
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

echo "    Apache OK"

# ============================================================
# 4. PHP.INI
# ============================================================
echo "[4/6] Konfigurasi PHP.ini..."

sed -i 's/^;max_input_vars.*/max_input_vars = 5000/;s/^post_max_size.*/post_max_size = 256M/;s/^upload_max_filesize.*/upload_max_filesize = 256M/' /etc/php/8.2/apache2/php.ini
sed -i 's/^;max_input_vars.*/max_input_vars = 5000/;s/^post_max_size.*/post_max_size = 256M/;s/^upload_max_filesize.*/upload_max_filesize = 256M/' /etc/php/8.2/cli/php.ini

echo "    PHP.ini OK"

# ============================================================
# 5. MARIADB
# ============================================================
echo "[5/6] Konfigurasi MariaDB..."

systemctl start mariadb

mariadb -u root << 'SQLEOF'
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('rp');
CREATE USER IF NOT EXISTS 'moodleuser'@'localhost' IDENTIFIED BY 'rp');
CREATE DATABASE IF NOT EXISTS moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON moodle.* TO 'moodleuser'@'localhost';
FLUSH PRIVILEGES;
SQLEOF

echo "    MariaDB OK - moodleuser/rp"

# ============================================================
# 6. EXTRACT MOODLE + CRON (antisipasi error soal)
# ============================================================
echo "[6/6] Setup Moodle files..."

cd /home
unzip -q moodle-5.0.7.zip 2>/dev/null
mkdir -p moodledata
chown -R www-data:www-data moodle moodledata

systemctl restart apache2 named mariadb
systemctl enable apache2 named mariadb bind9 2>/dev/null

echo "    Moodle files OK"

# ============================================================
# SELESAI
# ============================================================
echo ""
echo "================================================"
echo " SETUP SELESAI!"
echo "================================================"
echo ""
echo "Langkah selanjutnya:"
echo "1. Set DNS Windows (adapter Host-Only):"
echo "   IP  : 192.168.56.1 | Subnet: 255.255.255.0"
echo "   DNS : 192.168.56.10"
echo ""
echo "2. Buka browser: http://ujiankolaborasi.net"
echo ""
echo "Credential Moodle installer:"
echo "   DB Driver : MariaDB (native/mariadb) <- BUKAN MySQL!"
echo "   DB User   : moodleuser"
echo "   DB Pass   : rp"
echo ""
echo "Kalau error soal/adhoc task, jalankan:"
echo "   php /home/moodle/admin/cli/cron.php"
echo ""
echo "Selamat ujian! - TKJ SMKN 1 TUREN 2026"
