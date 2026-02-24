#!/bin/bash
# ============================================================
# LKS 2025 – Proxmox Network Bridge Setup
# Jalankan SEKALI di Proxmox host sebelum create-vms.sh
# Bridge: vmbr0(WAN), INT, DMZ, MGMT
# ============================================================

cat >> /etc/network/interfaces << 'EOF'

# INT – Internal Network (10.10.10.0/24)
auto INT
iface INT inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0

# DMZ – Demilitarized Zone (10.10.20.0/24)
auto DMZ
iface DMZ inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0

# MGMT – Management Network (192.168.2.0/24)
auto MGMT
iface MGMT inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
EOF

ifreload -a

echo "[+] Bridges created: INT, DMZ, MGMT"
echo "[+] WAN: vmbr0 (existing)"
