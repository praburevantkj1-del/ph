#!/bin/bash
# ============================================================
# MOODLE SETUP - TKJ SMKN 1 TUREN
# curl -s https://raw.githubusercontent.com/praburevantkj1-del/ph/main/tes.sh | bash
#
# Yang manual dulu SEBELUM jalanin ini:
#   1. /etc/network/interfaces  -> IP static 192.168.56.10
#   2. /etc/ssh/sshd_config     -> PermitRootLogin yes
#   3. /etc/apt/sources.list    -> [trusted=yes] di cdrom
#   4. apt-cdrom add DVD1 & DVD2
#   5. apt update
# ============================================================

echo "==================================="
echo " MOODLE SETUP - TKJ SMKN 1 TUREN "
echo "==================================="
echo ""

# ============================================================
# 1. INSTALL SEMUA PAKET
# ============================================================
echo "[1/7] Install paket..."

apt install -y bind9 bind9-dnsutils dns-root-data apache2 libapache2-mod-php mariadb-server php8.2 php8.2-cli php8.2-curl php8.2-zip php8.2-gd php8.2-xml php8.2-intl php8.2-mbstring php8.2-soap php8.2-ldap php8.2-mysql php8.2-bcmath zip

echo "    [OK] Paket terinstall"

# ============================================================
# 2. DNS
# ============================================================
echo "[2/7] Konfigurasi DNS..."

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
echo "    [OK] DNS siap"

# ============================================================
# 3. APACHE
# ============================================================
echo "[3/7] Konfigurasi Apache..."

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

echo "    [OK] Apache siap"

# ============================================================
# 4. PHP.INI
# ============================================================
echo "[4/7] Konfigurasi PHP.ini..."

for PHP_INI in /etc/php/8.2/apache2/php.ini /etc/php/8.2/cli/php.ini; do
    # Pakai append langsung biar pasti kena
    sed -i 's/^post_max_size.*/post_max_size = 256M/'            $PHP_INI
    sed -i 's/^upload_max_filesize.*/upload_max_filesize = 256M/' $PHP_INI
    # max_input_vars di-append langsung ke bawah file
    echo "max_input_vars = 5000" >> $PHP_INI
done

systemctl restart apache2
echo "    [OK] PHP.ini siap"

# ============================================================
# 5. MARIADB
# ============================================================
echo "[5/7] Konfigurasi MariaDB..."

systemctl start mariadb

mariadb -u root << 'SQLEOF'
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('rp');
CREATE USER IF NOT EXISTS 'moodleuser'@'localhost' IDENTIFIED BY 'rp';
CREATE DATABASE IF NOT EXISTS moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON moodle.* TO 'moodleuser'@'localhost';
FLUSH PRIVILEGES;
SQLEOF

echo "    [OK] MariaDB siap - moodleuser/rp"

# ============================================================
# 6. MOODLE FILES
# ============================================================
echo "[6/7] Setup Moodle files..."

cd /home
unzip -q moodle-5.0.7.zip 2>/dev/null
mkdir -p moodledata
chown -R www-data:www-data moodle moodledata 2>/dev/null

systemctl restart apache2 named mariadb
systemctl enable apache2 named mariadb bind9 2>/dev/null

echo "    [OK] Moodle files siap"

# ============================================================
# 7. CRON.PHP - FIX ERROR TAMBAH SOAL
# ============================================================
echo "[7/7] Menjalankan cron.php (fix error tambah soal)..."
echo "      Ini butuh 5-15 menit, harap tunggu..."

php /home/moodle/admin/cli/cron.php > /dev/null 2>&1

echo "    [OK] Cron selesai, tambah soal sudah bisa!"

# ============================================================
# SELESAI
# ============================================================
echo ""
echo "==================================="
echo " SETUP SELESAI!"
echo "==================================="
echo ""
echo "Langkah selanjutnya:"
echo ""
echo "1. Set adapter Host-Only Windows:"
echo "   IP  : 192.168.56.1"
echo "   Sub : 255.255.255.0"
echo "   DNS : 192.168.56.10"
echo ""
echo "2. Buka browser: http://ujiankolaborasi.net"
echo ""
echo "Isi form Moodle installer:"
echo "   DB Driver : MariaDB (native/mariadb) <- BUKAN MySQL!"
echo "   DB User   : moodleuser"
echo "   DB Pass   : rp"
echo ""
echo "Kalau masih error soal, jalankan:"
echo "   php /home/moodle/admin/cli/cron.php"
echo ""
echo "Selamat ujian! - TKJ SMKN 1 TUREN 2026"
