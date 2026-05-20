#!/bin/bash
# Script Auto-Install Moodle (Bypass Lab Sekolah)
# Akses: curl -sL bit.ly/kode-unik-kamu | bash

echo "[*] Memulai instalasi otomatis..."

# Update & Install Paket Dasar
apt update
apt install bind9 openssh-server apache2 mariadb-server php php-cli zip unzip -y

# Setup SSH & PermitRoot
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart ssh

# Auto Tuning PHP (Tanpa Nano)
for INI in /etc/php/*/apache2/php.ini /etc/php/*/cli/php.ini; do
    sed -i 's/;max_input_vars = 1000/max_input_vars = 5000/' $INI
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 50M/' $INI
done

# Setup MariaDB
mariadb -e "CREATE DATABASE moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Setup Apache
a2enmod rewrite
systemctl restart apache2

echo "[!] Instalasi Selesai! Tinggal scp moodle.zip dari Windows/download via wget."
