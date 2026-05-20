#!/bin/bash
# ============================================================
# SCRIPT FINAL - MOODLE AUTO-INSTALL (TKJ SMKN 1 TUREN)
# ============================================================

# 1. Update & Install Semua Paket
echo "[*] Menginstall paket..."
apt update -y
apt install -y bind9 bind9-dnsutils apache2 mariadb-server php8.2 php8.2-cli php8.2-curl php8.2-zip php8.2-gd php8.2-xml php8.2-intl php8.2-mbstring php8.2-soap php8.2-ldap php8.2-mysql php8.2-bcmath zip unzip

# 2. Setup DNS (BIND9)
echo "[*] Konfigurasi DNS..."
cat > /etc/bind/named.conf.local << 'EOF'
zone "ujiankolaborasi.net" { type master; file "/etc/bind/db.domain"; };
zone "56.168.192.in-addr.arpa" { type master; file "/etc/bind/db.ip"; };
EOF

cat > /etc/bind/db.domain << 'EOF'
$TTL 604800
@ IN SOA ujiankolaborasi.net. root.ujiankolaborasi.net. (2 604800 86400 2419200 604800)
@ IN NS ujiankolaborasi.net.
@ IN A 192.168.56.10
www IN A 192.168.56.10
EOF

cat > /etc/bind/db.ip << 'EOF'
$TTL 604800
@ IN SOA ujiankolaborasi.net. root.ujiankolaborasi.net. (1 604800 86400 2419200 604800)
@ IN NS ujiankolaborasi.net.
10 IN PTR ujiankolaborasi.net.
EOF
systemctl restart bind9

# 3. Setup Apache
echo "[*] Konfigurasi Apache..."
a2enmod rewrite
cat > /etc/apache2/sites-available/000-default.conf << 'EOF'
<VirtualHost *:80>
    DocumentRoot /home/moodle
    <Directory /home/moodle>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
a2ensite 000-default.conf
systemctl restart apache2

# 4. Tuning PHP
echo "[*] Tuning PHP..."
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 256M/' /etc/php/8.2/apache2/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 256M/' /etc/php/8.2/apache2/php.ini
echo "max_input_vars = 5000" >> /etc/php/8.2/apache2/php.ini
systemctl restart apache2

# 5. Database Setup
echo "[*] Setup Database..."
mariadb -e "CREATE DATABASE IF NOT EXISTS moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; GRANT ALL PRIVILEGES ON moodle.* TO 'root'@'localhost' IDENTIFIED BY 'rp'; FLUSH PRIVILEGES;"

# 6. Moodle Dir Prep
echo "[*] Menyiapkan Folder Moodle..."
mkdir -p /home/moodle /home/moodledata
chown -R www-data:www-data /home/moodle /home/moodledata
chmod 755 /home/moodledata

echo "========================================="
echo " SETUP SELESAI! "
echo " Sekarang kirim moodle.zip via SCP ke /home/moodle/"
echo "========================================="
