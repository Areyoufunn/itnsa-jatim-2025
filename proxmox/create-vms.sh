#!/bin/bash
# ============================================================
# LKS 2025 – Proxmox VM Creator
# Template ID  : 100 (Debian 13 Trixie + cloud-init)
# VM IDs       : 500–506
# Bridges      : vmbr0(WAN), INT, DMZ, MGMT
# Run as root on Proxmox host
# ============================================================

# === BRIDGE CONFIG ===
BR_WAN="vmbr0"  # WAN  – 100.100.100.0/24
BR_INT="INT"    # INT  – 10.10.10.0/24
BR_DMZ="DMZ"    # DMZ  – 10.10.20.0/24
BR_MGMT="MGMT"  # MGMT – 192.168.2.0/24

TEMPLATE=100
STORAGE="local-lvm"
PASS="Skills39!"
GW_WAN="100.100.100.1"
GW_MGMT="192.168.2.1"

# === HELPER FUNCTION ===
clone_vm() {
  local id=$1 name=$2 mem=$3
  echo "[+] Cloning VM $id – $name"
  qm clone $TEMPLATE $id --name "$name" --full 1 --storage $STORAGE
  qm set $id --memory $mem --cores 2 --onboot 1
  qm set $id --ciuser root --cipassword "$PASS"
  qm set $id --searchdomain itnsa.id --nameserver 8.8.8.8
}

# ============================================================
# VM 500 – juri (Ansible controller / grading)
# Interfaces: WAN (net0), MGMT (net1)
# ============================================================
clone_vm 500 "juri" 2048
qm set 500 \
  --net0  virtio,bridge=$BR_WAN  \
  --net1  virtio,bridge=$BR_MGMT \
  --ipconfig0 ip=dhcp \
  --ipconfig1 ip=192.168.2.100/24,gw=$GW_MGMT
qm start 500

# ============================================================
# VM 501 – fw.itnsa.id
# Interfaces: WAN (net0), INT (net1), DMZ (net2), MGMT (net3)
# ============================================================
clone_vm 501 "fw" 1024
qm set 501 \
  --net0  virtio,bridge=$BR_WAN  \
  --net1  virtio,bridge=$BR_INT  \
  --net2  virtio,bridge=$BR_DMZ  \
  --net3  virtio,bridge=$BR_MGMT \
  --ipconfig0 ip=100.100.100.254/24,gw=$GW_WAN \
  --ipconfig1 ip=10.10.10.254/24  \
  --ipconfig2 ip=10.10.20.254/24  \
  --ipconfig3 ip=192.168.2.15/24,gw=$GW_MGMT
qm start 501

# ============================================================
# VM 502 – int-srv.itnsa.id
# Interfaces: INT (net0), MGMT (net1)
# ============================================================
clone_vm 502 "int-srv" 2048
qm set 502 \
  --net0  virtio,bridge=$BR_INT  \
  --net1  virtio,bridge=$BR_MGMT \
  --ipconfig0 ip=10.10.10.10/24,gw=10.10.10.254 \
  --ipconfig1 ip=192.168.2.11/24,gw=$GW_MGMT
qm start 502

# ============================================================
# VM 503 – mail.itnsa.id
# Interfaces: DMZ (net0), MGMT (net1)
# ============================================================
clone_vm 503 "mail" 1024
qm set 503 \
  --net0  virtio,bridge=$BR_DMZ  \
  --net1  virtio,bridge=$BR_MGMT \
  --ipconfig0 ip=10.10.20.10/24,gw=10.10.20.254 \
  --ipconfig1 ip=192.168.2.12/24,gw=$GW_MGMT
qm start 503

# ============================================================
# VM 504 – web-01.itnsa.id
# Interfaces: DMZ (net0), MGMT (net1)
# ============================================================
clone_vm 504 "web-01" 1024
qm set 504 \
  --net0  virtio,bridge=$BR_DMZ  \
  --net1  virtio,bridge=$BR_MGMT \
  --ipconfig0 ip=10.10.20.21/24,gw=10.10.20.254 \
  --ipconfig1 ip=192.168.2.13/24,gw=$GW_MGMT
qm start 504

# ============================================================
# VM 505 – web-02.itnsa.id
# Interfaces: DMZ (net0), MGMT (net1)
# ============================================================
clone_vm 505 "web-02" 1024
qm set 505 \
  --net0  virtio,bridge=$BR_DMZ  \
  --net1  virtio,bridge=$BR_MGMT \
  --ipconfig0 ip=10.10.20.22/24,gw=10.10.20.254 \
  --ipconfig1 ip=192.168.2.14/24,gw=$GW_MGMT
qm start 505

# ============================================================
# VM 506 – budi-clt.itnsa.id
# Interfaces: WAN (net0), MGMT (net1)
# ============================================================
clone_vm 506 "budi-clt" 1024
qm set 506 \
  --net0  virtio,bridge=$BR_WAN  \
  --net1  virtio,bridge=$BR_MGMT \
  --ipconfig0 ip=100.100.100.100/24,gw=$GW_WAN \
  --ipconfig1 ip=192.168.2.16/24,gw=$GW_MGMT
qm start 506

echo ""
echo "============================================================"
echo " Semua VM berhasil dibuat!"
echo " VM 500 – juri      : MGMT 192.168.2.100"
echo " VM 501 – fw        : MGMT 192.168.2.15"
echo " VM 502 – int-srv   : MGMT 192.168.2.11"
echo " VM 503 – mail      : MGMT 192.168.2.12"
echo " VM 504 – web-01    : MGMT 192.168.2.13"
echo " VM 505 – web-02    : MGMT 192.168.2.14"
echo " VM 506 – budi-clt  : MGMT 192.168.2.16"
echo "============================================================"
