#!/bin/bash
# ============================================================
# LKS 2025 – Proxmox Network Bridge Setup
# Jalankan SEKALI di Proxmox host sebelum create-vms.sh
# Sesuaikan interface fisik (ens18, eth0, dll) jika perlu
# ============================================================

IFACE_WAN="ens18"   # Interface fisik untuk WAN (sudah ada vmbr0)

cat >> /etc/network/interfaces << 'EOF'

# INT – Internal Network (10.10.10.0/24)
auto vmbr-int
iface vmbr-int inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0

# DMZ – Demilitarized Zone (10.10.20.0/24)
auto vmbr-dmz
iface vmbr-dmz inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0

# MGMT – Management Network (192.168.2.0/24)
auto vmbr-mgmt
iface vmbr-mgmt inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
EOF

ifreload -a

echo "[+] Bridges created: vmbr-int, vmbr-dmz, vmbr-mgmt"
echo "[+] WAN: vmbr0 (existing)"
