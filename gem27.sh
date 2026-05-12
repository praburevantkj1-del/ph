#!/bin/bash

# =================================================================
# SCRIPT SETUP SERVER UJIAN KOLABORASI (MOODLE + BIND9 + LAMP)
# OS: Debian 12 (Bookworm)
# =================================================================

# 1. FIX REPOSITORY (Mematikan CD-ROM dan pakai Mirror Lokal)
echo "--- Mengatur Repository... ---"
sed -i 's/^deb cdrom/#&/' /etc/apt/sources.list
cat > /etc/apt/sources.list << 'EOF'
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

apt update

# 2. INSTALL PACKAGES
echo "--- Menginstall Paket (Apache, MariaDB, PHP 8.2, Bind9)... ---"
apt install -y bind9 bind9-dnsutils dns-root-data apache2 libapache2-mod-php \
mariadb-server php8.2 php8.2-cli php8.2-curl php8.2-zip php8.2-gd php8.2-xml \
php8.2-intl php8.2-mbstring php8.2-soap php8.2-ldap php8.2-mysql php8.2-bcmath zip unzip

# 3. KONFIGURASI DNS (BIND9)
echo "--- Mengonfigurasi DNS... ---"
mkdir -p /etc/bind

cat > /etc/bind/named.conf.local << 'EOF'
zone "ujiankolaborasi.net" {
    type master;
    file "/etc/bind/db.domain";
};

zone "27.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.ip";
};
EOF

cat > /etc/bind/db.domain << 'EOF'
$TTL 604800
@ IN SOA ujiankolaborasi.net. root.ujiankolaborasi.net. (2 604800 86400 2419200 604800)
@ IN NS ujiankolaborasi.net.
@ IN A 192.168.27.10
www IN A 192.168.27.10
EOF

cat > /etc/bind/db.ip << 'EOF'
$TTL 604800
@ IN SOA ujiankolaborasi.net. root.ujiankolaborasi.net. (1 604800 86400 2419200 604800)
@ IN NS ujiankolaborasi.net.
10 IN PTR ujiankolaborasi.net.
10 IN PTR www.ujiankolaborasi.net.
EOF

cat > /etc/bind/named.conf.options << 'EOF'
options {
    directory "/var/cache/bind";
    listen-on { any; };
    allow-query { any; };
    recursion yes;
    dnssec-validation auto;
    listen-on-v6 { any; };
};
EOF

systemctl restart bind9

# 4. KONFIGURASI WEB SERVER (APACHE)
echo "--- Mengonfigurasi Apache... ---"
a2enmod rewrite setenvif -q

cat > /etc/apache2/sites-available/000-default.conf << 'EOF'
<VirtualHost *:80>
    ServerName ujiankolaborasi.net
    ServerAlias www.ujiankolaborasi.net
    DocumentRoot /var/www/html/moodle
    
    <Directory /var/www/html/moodle>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# 5. OPTIMALISASI PHP
echo "--- Mengoptimalkan PHP... ---"
for PHP_INI in /etc/php/8.2/apache2/php.ini /etc/php/8.2/cli/php.ini; do
    if [ -f "$PHP_INI" ]; then
        sed -i 's/^post_max_size.*/post_max_size = 256M/' $PHP_INI
        sed -i 's/^upload_max_filesize.*/upload_max_filesize = 256M/' $PHP_INI
        sed -i 's/^max_execution_time.*/max_execution_time = 300/' $PHP_INI
        echo "max_input_vars = 5000" >> $PHP_INI
    fi
done

# 6. KONFIGURASI DATABASE (MARIADB)
echo "--- Mengonfigurasi Database... ---"
systemctl start mariadb

# Menggunakan cara yang lebih aman untuk Debian 12
mariadb -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('rp');"
mariadb -u root -prp -e "CREATE USER IF NOT EXISTS 'moodleuser'@'localhost' IDENTIFIED BY 'rp';"
mariadb -u root -prp -e "CREATE DATABASE IF NOT EXISTS moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mariadb -u root -prp -e "GRANT ALL PRIVILEGES ON moodle.* TO 'moodleuser'@'localhost';"
mariadb -u root -prp -e "FLUSH PRIVILEGES;"

# 7. SETUP FILE MOODLE
echo "--- Menyiapkan Folder Moodle... ---"
mkdir -p /var/www/html/moodle
mkdir -p /var/www/moodledata
chown -R www-data:www-data /var/www/moodledata

# Jika file zip ada di home, ekstrak ke /var/www/html/
if [ -f "/home/moodle-5.0.7.zip" ]; then
    unzip -qo /home/moodle-5.0.7.zip -d /var/www/html/
    chown -R www-data:www-data /var/www/html/moodle
else
    echo "Peringatan: File moodle-5.0.7.zip tidak ditemukan di /home/"
fi

# 8. RESTART SERVICES
echo "--- Restarting Services... ---"
systemctl restart apache2 bind9 mariadb
systemctl enable apache2 bind9 mariadb

echo "------------------------------------------------"
echo "PROSES SELESAI!"
echo "Domain: http://ujiankolaborasi.net"
echo "DB Name: moodle | DB User: moodleuser | Pass: rp"
echo "Data Directory: /var/www/moodledata"
echo "------------------------------------------------"
