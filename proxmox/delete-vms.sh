#!/bin/bash
# ============================================================
# LKS 2025 – Proxmox VM Deleter
# Hapus semua VM LKS 2025 (ID 500–506)
# Run as root on Proxmox host
# ============================================================

VM_IDS=(500 501 502 503 504 505 506)

echo "============================================================"
echo " Menghapus semua VM LKS 2025..."
echo "============================================================"

for id in "${VM_IDS[@]}"; do
  if qm status $id &>/dev/null; then
    echo "[+] Stopping VM $id..."
    qm stop $id --skiplock 2>/dev/null
    sleep 2
    echo "[+] Destroying VM $id..."
    qm destroy $id --purge --destroy-unreferenced-disks 1
  else
    echo "[-] VM $id tidak ditemukan, skip."
  fi
done

echo ""
echo "============================================================"
echo " Semua VM berhasil dihapus!"
echo " Siap untuk create ulang: bash create-vms.sh"
echo "============================================================"
