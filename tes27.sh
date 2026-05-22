#!/bin/bash
apt install -y bind9 bind9-dnsutils dns-root-data apache2 libapache2-mod-php mariadb-server php8.2 php8.2-cli php8.2-curl php8.2-zip php8.2-gd php8.2-xml php8.2-intl php8.2-mbstring php8.2-soap php8.2-ldap php8.2-mysql php8.2-bcmath zip
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
systemctl restart named.service
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
for PHP_INI in /etc/php/8.2/apache2/php.ini /etc/php/8.2/cli/php.ini; do
echo 's/^post_max_size.*/post_max_size = 256M/' $PHP_INI
echo 's/^upload_max_filesize.*/upload_max_filesize = 256M/' $PHP_INI
echo "max_input_vars = 5000" >> $PHP_INI
done
systemctl start mariadb
mariadb -u root << 'SQLEOF'
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('rp');
CREATE USER IF NOT EXISTS 'moodleuser'@'localhost' IDENTIFIED BY 'rp';
CREATE DATABASE IF NOT EXISTS moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON moodle.* TO 'moodleuser'@'localhost';
FLUSH PRIVILEGES;
SQLEOF
cd /home
unzip -q moodle-5.0.7.zip 2>/dev/null
mkdir -p moodledata
chown -R www-data:www-data moodle moodledata 2>/dev/null
systemctl restart apache2 named mariadb
systemctl enable apache2 named mariadb bind9 2>/dev/null
echo "SELESAI!"
echo "Browser: http://ujiankolaborasi.net"
echo "DB Driver: MariaDB (native/mariadb)"
echo "DB User: moodleuser | DB Pass: rp"
echo "Setelah wizard selesai jalankan cron.sh!"
