#!/bin/bash
# ============================================================
# MOODLE AUTO SETUP SCRIPT - TKJ SMKN 1 TUREN
# Usage: curl -s https://raw.githubusercontent.com/RevanAby123/tkj/main/moodle.sh | bash
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
info() { echo -e "${BLUE}[..] $1${NC}"; }

echo -e "${BLUE}"
echo "============================================"
echo "   MOODLE AUTO SETUP - TKJ SMKN 1 TUREN   "
echo "============================================"
echo -e "${NC}"

# ============================================================
# STEP 1: KONFIGURASI IP
# ============================================================
info "Step 1: Konfigurasi IP Address..."

HOSTONLY_IFACE=""
NAT_IFACE=""

for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v lo); do
    DHCP_IP=$(ip addr show $iface | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    if [[ $DHCP_IP == 10.* ]] || [[ $DHCP_IP == 192.168.1.* ]] || [[ $DHCP_IP == 172.* ]]; then
        NAT_IFACE=$iface
    else
        HOSTONLY_IFACE=$iface
    fi
done

[ -z "$HOSTONLY_IFACE" ] && HOSTONLY_IFACE="enp0s3"
[ -z "$NAT_IFACE" ]      && NAT_IFACE="enp0s8"

log "Host-Only : $HOSTONLY_IFACE | NAT : $NAT_IFACE"

cat > /etc/network/interfaces << EOF
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto $HOSTONLY_IFACE
iface $HOSTONLY_IFACE inet static
address 192.168.56.10/24

auto $NAT_IFACE
iface $NAT_IFACE inet dhcp
EOF

systemctl restart networking.service 2>/dev/null
log "IP 192.168.56.10 dikonfigurasi"

# ============================================================
# STEP 2: SSH
# ============================================================
info "Step 2: Konfigurasi SSH..."

apt-get install -y openssh-server -qq 2>/dev/null

sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/'  /etc/ssh/sshd_config
grep -q "PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

systemctl restart ssh 2>/dev/null
systemctl enable ssh 2>/dev/null
log "SSH siap, root login diizinkan"

# ============================================================
# STEP 3: REPOSITORY DVD
# ============================================================
info "Step 3: Konfigurasi repository DVD..."

# Tambah trusted=yes ke cdrom yang sudah ada
sed -i 's|^deb cdrom:|deb [trusted=yes] cdrom:|g' /etc/apt/sources.list

# Kalau belum ada cdrom entry, mount & add otomatis
if ! grep -q "cdrom" /etc/apt/sources.list; then
    warn "Tidak ada cdrom di sources.list, mencoba mount DVD..."
    mount /dev/sr0 /media/cdrom 2>/dev/null || mount /dev/cdrom /media/cdrom 2>/dev/null
    apt-cdrom add -m -d /media/cdrom 2>/dev/null
    sed -i 's|^deb cdrom:|deb [trusted=yes] cdrom:|g' /etc/apt/sources.list
fi

apt-get update -qq 2>/dev/null
log "Repository siap"

# ============================================================
# STEP 4: INSTALL SEMUA PAKET
# ============================================================
info "Step 4: Install semua paket (butuh beberapa menit)..."

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    bind9 bind9-dnsutils dns-root-data \
    apache2 libapache2-mod-php \
    mariadb-server \
    php8.2 php8.2-cli php8.2-curl php8.2-zip php8.2-gd \
    php8.2-xml php8.2-intl php8.2-mbstring php8.2-soap \
    php8.2-ldap php8.2-mysql php8.2-bcmath zip \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" 2>/dev/null

log "Semua paket terinstall"

# ============================================================
# STEP 5: DNS
# ============================================================
info "Step 5: Konfigurasi DNS Server..."

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
log "DNS siap"

# ============================================================
# STEP 6: EXTRACT MOODLE
# ============================================================
info "Step 6: Mencari dan extract Moodle..."

MOODLE_ZIP=""
for path in "/home/moodle-5.0.7.zip" "/home/moodle-*.zip" "/root/moodle-*.zip" "/tmp/moodle-*.zip"; do
    found=$(ls $path 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        MOODLE_ZIP=$found
        break
    fi
done

if [ -n "$MOODLE_ZIP" ]; then
    cd /home && unzip -q "$MOODLE_ZIP"
    log "Moodle diekstrak dari $MOODLE_ZIP"
else
    warn "Moodle zip belum ada! Upload dulu dari PowerShell Windows:"
    warn "scp \"D:\\Software Basic\\Ujian Kolaborasi 2026\\moodle-5.0.7.zip\" root@192.168.56.10:/home/"
    warn "Lalu jalankan: cd /home && unzip moodle-5.0.7.zip && chown -R www-data:www-data /home/moodle /home/moodledata"
fi

mkdir -p /home/moodledata
chown -R www-data:www-data /home/moodle /home/moodledata 2>/dev/null
log "Folder moodle & moodledata siap"

# ============================================================
# STEP 7: APACHE
# ============================================================
info "Step 7: Konfigurasi Apache..."

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

log "Apache dikonfigurasi"

# ============================================================
# STEP 8: PHP.INI
# ============================================================
info "Step 8: Konfigurasi PHP.ini..."

for PHP_INI in /etc/php/8.2/apache2/php.ini /etc/php/8.2/cli/php.ini; do
    if [ -f "$PHP_INI" ]; then
        sed -i 's/^;max_input_vars.*/max_input_vars = 5000/' $PHP_INI
        sed -i 's/^max_input_vars.*/max_input_vars = 5000/'  $PHP_INI
        sed -i 's/^post_max_size.*/post_max_size = 256M/'    $PHP_INI
        sed -i 's/^upload_max_filesize.*/upload_max_filesize = 256M/' $PHP_INI
        log "PHP.ini: $PHP_INI"
    fi
done

# ============================================================
# STEP 9: MARIADB
# ============================================================
info "Step 9: Konfigurasi MariaDB..."

systemctl start mariadb

mariadb -u root 2>/dev/null << 'SQLEOF'
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('Admin@123');
CREATE USER IF NOT EXISTS 'moodleuser'@'localhost' IDENTIFIED BY 'Moodle@123';
CREATE DATABASE IF NOT EXISTS moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON moodle.* TO 'moodleuser'@'localhost';
FLUSH PRIVILEGES;
SQLEOF

log "MariaDB siap - moodleuser / Moodle@123"

# ============================================================
# STEP 10: RESTART SEMUA SERVICE + AUTO-START
# ============================================================
info "Step 10: Restart & enable semua service..."

systemctl restart apache2 named mariadb ssh
systemctl enable apache2 named mariadb ssh bind9 2>/dev/null

cat > /etc/rc.local << 'EOF'
#!/bin/bash
sleep 5
systemctl restart networking
systemctl restart apache2
systemctl restart named
systemctl restart mariadb
exit 0
EOF

chmod +x /etc/rc.local
log "Semua service aktif & auto-start saat boot"

# ============================================================
# SELESAI
# ============================================================
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}   SETUP SELESAI!                               ${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${YELLOW}=== LANGKAH SELANJUTNYA ===${NC}"
echo ""
echo -e "${BLUE}1. Buka PowerShell Windows BARU, upload moodle:${NC}"
echo '   scp "D:\Software Basic\Ujian Kolaborasi 2026\moodle-5.0.7.zip" root@192.168.56.10:/home/'
echo ""
echo -e "${BLUE}2. Balik ke SSH, extract (kalau belum otomatis):${NC}"
echo "   cd /home && unzip moodle-5.0.7.zip"
echo "   chown -R www-data:www-data /home/moodle /home/moodledata"
echo ""
echo -e "${BLUE}3. Set di Windows - adapter Host-Only IPv4:${NC}"
echo "   IP  : 192.168.56.1  |  Subnet: 255.255.255.0"
echo "   DNS : 192.168.56.10"
echo ""
echo -e "${BLUE}4. Buka browser:${NC}"
echo "   http://ujiankolaborasi.net"
echo ""
echo -e "${YELLOW}=== CREDENTIAL PENTING ===${NC}"
echo "   DB Driver  : MariaDB (native/mariadb)  <- BUKAN MySQL!"
echo "   DB Host    : localhost"
echo "   DB Name    : moodle"
echo "   DB User    : moodleuser"
echo "   DB Pass    : Moodle@123"
echo ""
echo -e "${GREEN}Selamat ujian! - TKJ SMKN 1 Turen 2026${NC}"
echo ""
