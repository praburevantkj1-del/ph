#!/bin/bash
# ============================================================
# CRON FIX - Jalankan SETELAH wizard Moodle di browser selesai!
# curl -s https://raw.githubusercontent.com/praburevantkj1-del/ph/main/cron.sh | bash
# ============================================================

echo "================================="
echo " CRON FIX - BISA TAMBAH SOAL    "
echo "================================="
echo ""
echo "Tunggu 5-15 menit, jangan ditutup!"
echo ""

php /home/moodle/admin/cli/cron.php

echo ""
echo "================================="
echo " SELESAI! Refresh browser Moodle."
echo " Sekarang bisa tambah soal!      "
echo "================================="
